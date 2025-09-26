import Foundation
import Combine
import os

@MainActor
final class ScoreManager: ObservableObject {
    static let shared = ScoreManager()

    // Inputs
    private let dataManager = DataManager.shared
    private let calculator = HealthCalculator.shared
    private var cancellables: Set<AnyCancellable> = []

    // Outputs (tri-state)
    @Published private(set) var recoveryScoreState: ScoreState = .pending
    @Published private(set) var sleepScoreState: ScoreState = .pending
    @Published private(set) var strainScoreState: ScoreState = .pending

    private let logger = Logger(subsystem: "app.bioloop", category: "ScoreManager")
    
    // Snapshot management - debounced and idempotent
    private let snapshotRequest = PassthroughSubject<Void, Never>()
    private var snapshotCancellable: AnyCancellable?
    private var didTakeMorningSnapshot = false
    private var lastSnapshotDate: Date?

    private init() {
        setupPipelines()
        setupSnapshotDebouncing()
    }
    
    private func setupSnapshotDebouncing() {
        snapshotCancellable = snapshotRequest
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.performSnapshotIfNeeded()
            }
    }
    
    private func performSnapshotIfNeeded() {
        // Only take snapshot if we haven't taken one today and have recent HRV/RHR data
        let today = Calendar.current.startOfDay(for: Date())
        let lastSnapshotDay = lastSnapshotDate.map { Calendar.current.startOfDay(for: $0) }
        
        guard lastSnapshotDay != today,
              dataManager.hasRecentHRV,
              dataManager.hasRecentRHR,
              let _ = dataManager.latestHRVActual,
              let _ = dataManager.latestRHRActual else {
            logger.debug("Skipping snapshot: already taken today or no recent data")
            return
        }
        
        logger.info("Taking morning snapshot")
        didTakeMorningSnapshot = true
        lastSnapshotDate = Date()
        
        // Trigger any snapshot-specific logic here
        // For now, just log the event
        logger.info("SCORING_EVENT snapshot_taken: recovery=\(self.recoveryScoreState)")
    }
    
    private func requestSnapshot() {
        snapshotRequest.send()
    }

    private func setupPipelines() {
        // Recovery depends on validated HRV/RHR states
        Publishers.CombineLatest3(
            dataManager.$hrvState,
            dataManager.$rhrState,
            dataManager.$sleepState
        )
        .receive(on: RunLoop.main)
        .debounce(for: .seconds(HealthMetricsConfiguration.snapshotDebounceInterval), scheduler: RunLoop.main)
        .sink { [weak self] hrvState, rhrState, sleepState in
            guard let self = self else { return }
            
            // Ready set check: all required metrics must be valid
            guard case .valid(let hrv, _) = hrvState,
                  case .valid(let rhr, _) = rhrState,
                  hrv > 0, rhr > 0 else {
                let reason = self.getRecoveryUnavailableReason(hrvState: hrvState, rhrState: rhrState)
                self.recoveryScoreState = .unavailable(reason: reason)
                self.logger.debug("Recovery pipeline: \(reason)")
                return
            }
            
            // Optional sleep enhancement
            let sleepHours = sleepState.value
            
            let score = self.calculator.recoveryScore(hrv: hrv, rhr: rhr, sleepHours: sleepHours)
            self.recoveryScoreState = .computed(Int(score))
            
            // Log scoring event
            self.logger.info("SCORING_EVENT recovery_computed: hrv=\(hrv), rhr=\(rhr), sleep=\(sleepHours ?? 0), score=\(Int(score))")
            
            // Request snapshot only from HRV/RHR changes (not sleep)
            self.requestSnapshot()
        }
        .store(in: &cancellables)

        // Sleep independent: compute when sleep data is valid (NO snapshot trigger)
        dataManager.$todaySleepSession
            .receive(on: RunLoop.main)
            .sink { [weak self] sleepSession in
                guard let self = self else { return }
                
                print("🛌 ScoreManager: Sleep session updated, current state: \(self.sleepScoreState)")
                
                if let session = sleepSession, session.isComplete {
                    // Use comprehensive sleep scoring
                    let score = self.calculator.comprehensiveSleepScore(from: session)
                    print("🛌 ScoreManager: Computed sleep score: \(Int(score))")
                    
                    // Always update the score, not just when pending
                    self.sleepScoreState = .computed(Int(score))
                    self.logger.info("SCORING_EVENT sleep_computed: duration=\(session.durationHours)h, efficiency=\(session.efficiency * 100)%, score=\(Int(score))")
                } else {
                    // Fallback to basic sleep hours if available
                    if case .valid(let hours, _) = self.dataManager.sleepState, hours > 0 {
                        let score = self.calculator.sleepScore(sleepHours: hours, efficiency: nil)
                        print("🛌 ScoreManager: Computed fallback sleep score: \(Int(score))")
                        
                        // Always update the score, not just when pending
                        self.sleepScoreState = .computed(Int(score))
                        self.logger.info("SCORING_EVENT sleep_computed_fallback: hours=\(hours), score=\(Int(score))")
                    } else {
                        let reason = self.getSleepUnavailableReason(sleepState: self.dataManager.sleepState)
                        print("🛌 ScoreManager: Sleep unavailable: \(reason ?? "unknown")")
                        self.sleepScoreState = .unavailable(reason: reason)
                    }
                }
                // Note: Sleep changes do NOT trigger snapshots
            }
            .store(in: &cancellables)

        // Strain: recompute on validated steps/energy states with personalized baselines
        Publishers.CombineLatest(
            dataManager.$stepsState,
            dataManager.$energyState
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] (stepsState: MetricState<Double>, energyState: MetricState<Double>) in
            guard let self = self else { return }
            
            // Ready set check: at least one activity metric must be valid
            let steps = stepsState.value
            let energy = energyState.value
            
            guard (steps != nil && steps! > 0) || (energy != nil && energy! > 0) else {
                let reason = self.getStrainUnavailableReason(stepsState: stepsState, energyState: energyState)
                self.strainScoreState = .unavailable(reason: reason)
                return
            }
            
            // Low-activity early-day guard to avoid inflated strain
            let stepsVal = steps ?? 0
            let energyVal = energy ?? 0
            let minimalStepsThreshold = 1000.0
            let minimalEnergyThreshold = 200.0
            if stepsVal < minimalStepsThreshold && energyVal < minimalEnergyThreshold {
                self.strainScoreState = .computed(0)
                self.logger.info("SCORING_EVENT strain_guarded_low_activity: steps=\(stepsVal), energy=\(energyVal), score=0")
                return
            }

            let stepsBaseline = self.dataManager.baselineSteps
            let energyBaseline = self.dataManager.baselineActiveEnergy
            let score = self.calculator.personalizedStrainScore(
                steps: stepsVal, 
                energy: energyVal, 
                stepsBaseline: stepsBaseline, 
                energyBaseline: energyBaseline
            )
            self.strainScoreState = .computed(Int(score))
            self.logger.info("SCORING_EVENT strain_computed: steps=\(stepsVal), energy=\(energyVal), score=\(Int(score))")
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods for Unavailable Reasons
    
    private func getRecoveryUnavailableReason(hrvState: MetricState<Double>, rhrState: MetricState<Double>) -> String {
        switch (hrvState, rhrState) {
        case (.missing, .missing):
            return "No HRV or RHR data"
        case (.missing, _):
            return "No HRV data"
        case (_, .missing):
            return "No RHR data"
        case (.stale(let hrvDate), .stale(let rhrDate)):
            return "HRV and RHR data are stale (HRV: \(formatDate(hrvDate)), RHR: \(formatDate(rhrDate)))"
        case (.stale(let date), _):
            return "HRV data is stale (\(formatDate(date)))"
        case (_, .stale(let date)):
            return "RHR data is stale (\(formatDate(date)))"
        case (.valid(let hrv, _), .valid(let rhr, _)):
            if hrv <= 0 || rhr <= 0 {
                return "Invalid HRV or RHR values"
            }
            return "Unknown error"
        }
    }
    
    private func getSleepUnavailableReason(sleepState: MetricState<Double>) -> String {
        switch sleepState {
        case .missing:
            return "No sleep data"
        case .stale(let date):
            return "Sleep data is stale (\(formatDate(date)))"
        case .valid(let hours, _):
            if hours <= 0 {
                return "Invalid sleep duration"
            }
            return "Unknown error"
        }
    }
    
    private func getStrainUnavailableReason(stepsState: MetricState<Double>, energyState: MetricState<Double>) -> String {
        switch (stepsState, energyState) {
        case (.missing, .missing):
            return "No activity data"
        case (.missing, .stale), (.stale, .missing), (.stale, .stale):
            return "Activity data is stale"
        case (.valid(let steps, _), .valid(let energy, _)):
            if steps <= 0 && energy <= 0 {
                return "No activity recorded"
            }
            return "Unknown error"
        default:
            return "Insufficient activity data"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}


