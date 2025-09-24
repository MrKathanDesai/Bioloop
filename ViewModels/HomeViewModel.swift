import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    static let shared = HomeViewModel()

    private let dataManager = DataManager.shared
    private let scoreManager = ScoreManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Score tri-state
    enum ScoreState: Equatable {
        case pending
        case computed(Int)
        case unavailable
    }
    
    // Published UI state
    @Published var recoveryScoreState: ScoreState = .pending
    @Published var sleepScoreState: ScoreState = .pending
    @Published var strainScoreState: ScoreState = .pending
    
    // Raw metrics for display
    @Published var latestRHR: Double? = nil
    @Published var latestHRV: Double? = nil
    @Published var latestVO2Max: Double? = nil
    @Published var latestWeight: Double? = nil
    
    // Today's metrics
    @Published var todaySteps: Double = 0
    @Published var todayHeartRate: Double = 0
    @Published var todayActiveEnergy: Double = 0
    @Published var todaySleepHours: Double = 0
    @Published var todayDietaryEnergy: Double = 0
    @Published var todayProteinGrams: Double = 0
    @Published var todayCarbsGrams: Double = 0
    @Published var todayFatGrams: Double = 0
    
    // Authorization state
    @Published var hasHealthKitPermission: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Coaching message
    @Published var coachingMessage: String = "Welcome to Bioloop! Connect your health data to get started."

    // Temporary compatibility for existing UI (to be removed after UI migration)
    var recoveryScore: Int {
        if case .computed(let v) = recoveryScoreState { return v }
        return 0
    }
    var sleepScore: Int {
        if case .computed(let v) = sleepScoreState { return v }
        return 0
    }
    var strainScore: Int {
        if case .computed(let v) = strainScoreState { return v }
        return 0
    }

    // Snapshot logic now delegated to ScoreManager (pipelines). Keep minimal compatibility.
    private let snapshotRequest = PassthroughSubject<Void, Never>()
    private var snapshotCancellable: AnyCancellable?

    init() {
        setupSubscriptions()
        // Morning snapshot will be computed once when first data arrives
        snapshotCancellable = snapshotRequest
            .debounce(for: .seconds(HealthMetricsConfiguration.snapshotDebounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] in
                print("⏱️ Debounced snapshotRequest fired (handled by ScoreManager pipelines)")
            }
    }

    private func setupSubscriptions() {
        print("🔗 Setting up HomeViewModel subscriptions...")
        
        // Bridge ScoreManager outputs into HomeViewModel UI states
        scoreManager.$recoveryScoreState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.recoveryScoreState = state
                self?.updateCoachingMessage()
            }
            .store(in: &cancellables)

        scoreManager.$sleepScoreState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.sleepScoreState = state
                self?.updateCoachingMessage()
            }
            .store(in: &cancellables)

        scoreManager.$strainScoreState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.strainScoreState = state
                self?.updateCoachingMessage()
            }
            .store(in: &cancellables)

        // Subscribe to DataManager series
        dataManager.$rhrSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 RHR series updated: \(series.count) points")
                self?.latestRHR = series.last?.value
                let haveRecent = self?.dataManager.hasRecentHRV == true && self?.dataManager.hasRecentRHR == true
                print("📝 RHR arrived -> requesting snapshot attempt (hasRecentHRV=\(self?.dataManager.hasRecentHRV == true), hasRecentRHR=\(self?.dataManager.hasRecentRHR == true), canCompute=\(haveRecent))")
                self?.snapshotRequest.send()
                // ScoreManager handles recovery; VM only updates UI state below
            }
            .store(in: &cancellables)
        
        dataManager.$hrvSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 HRV series updated: \(series.count) points")
                self?.latestHRV = series.last?.value
                let haveRecent = self?.dataManager.hasRecentHRV == true && self?.dataManager.hasRecentRHR == true
                print("📝 HRV arrived -> requesting snapshot attempt (hasRecentHRV=\(self?.dataManager.hasRecentHRV == true), hasRecentRHR=\(self?.dataManager.hasRecentRHR == true), canCompute=\(haveRecent))")
                self?.snapshotRequest.send()
                // ScoreManager handles recovery; VM only updates UI state below
            }
            .store(in: &cancellables)

        // Recompute recovery when recency dates update (avoids race with series updates)
        // No longer manually recompute on HRV/RHR date updates; ScoreManager pipelines handle it
        
        dataManager.$vo2MaxSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 VO2 Max series updated: \(series.count) points")
                self?.latestVO2Max = series.last?.value
                // Do not change scores mid-day here
            }
            .store(in: &cancellables)
        
        dataManager.$weightSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 Weight series updated: \(series.count) points")
                self?.latestWeight = series.last?.value
                // Weight changes shouldn't mutate fixed daily scores
            }
            .store(in: &cancellables)

        // Subscribe to today's metrics (strain handled by ScoreManager; keep UI mirrors)
        dataManager.$todaySteps
            .receive(on: RunLoop.main)
            .sink { [weak self] v in
                self?.todaySteps = v
                // ScoreManager computes; VM mirrors below
            }
            .store(in: &cancellables)
            
        dataManager.$todayHeartRate
            .receive(on: RunLoop.main)
            .assign(to: \.todayHeartRate, on: self)
            .store(in: &cancellables)
            
        dataManager.$todayActiveEnergy
            .receive(on: RunLoop.main)
            .sink { [weak self] v in
                self?.todayActiveEnergy = v
                // ScoreManager computes; VM mirrors below
            }
            .store(in: &cancellables)
            
        dataManager.$todaySleepHours
            .receive(on: RunLoop.main)
            .sink { [weak self] v in
                self?.todaySleepHours = v
                print("🛌 Sleep updated: \(v)h — not triggering snapshot")
                // ScoreManager computes; VM mirrors below
            }
            .store(in: &cancellables)

        // Nutrition metrics
        dataManager.$todayDietaryEnergy
            .receive(on: RunLoop.main)
            .assign(to: \.todayDietaryEnergy, on: self)
            .store(in: &cancellables)

        dataManager.$todayProteinGrams
            .receive(on: RunLoop.main)
            .assign(to: \.todayProteinGrams, on: self)
            .store(in: &cancellables)

        dataManager.$todayCarbsGrams
            .receive(on: RunLoop.main)
            .assign(to: \.todayCarbsGrams, on: self)
            .store(in: &cancellables)

        dataManager.$todayFatGrams
            .receive(on: RunLoop.main)
            .assign(to: \.todayFatGrams, on: self)
            .store(in: &cancellables)
        
        // Subscribe to authorization state
        dataManager.$hasHealthKitPermission
            .receive(on: RunLoop.main)
            .sink { [weak self] hasPermission in
                print("🔗 Permission status updated: \(hasPermission)")
                self?.hasHealthKitPermission = hasPermission
                self?.updateCoachingMessage()
                // If permission just granted, snapshot will occur once data arrives
            }
            .store(in: &cancellables)
            
        dataManager.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
            
        dataManager.$errorMessage
            .receive(on: RunLoop.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        print("🔗 HomeViewModel subscriptions setup completed")
    }
    
    // MARK: - Score Computation
    
    private func recomputeScoresMorningSnapshot() {
        print("🧮 Morning snapshot score computation (delegated to ScoreManager pipelines)")
    }

    // Compute once when data is available
    private var didTakeMorningSnapshot: Bool = false
    private func attemptMorningSnapshotIfNeeded() {
        print("🕗 attemptMorningSnapshotIfNeeded called (legacy path)")
        performSnapshotIfNeeded()
    }

    private func performSnapshotIfNeeded() { /* handled by ScoreManager */ }
    
    // Recovery computation delegated to ScoreManager
    
    private func computeSleepScore() -> Int {
        guard todaySleepHours > 0 else { 
            print("🧮 Sleep: No sleep data available")
            return 0 
        }
        
        // More nuanced sleep scoring based on sleep research
        let score: Double
        
        if todaySleepHours >= 7.5 && todaySleepHours <= 8.5 {
            score = 95 + min(5, (8.5 - abs(todaySleepHours - 8)) * 2) // Optimal: 95-100
        } else if todaySleepHours >= 7 && todaySleepHours <= 9 {
            score = 85 + ((9 - abs(todaySleepHours - 8)) / 1) * 10 // Very Good: 85-95
        } else if todaySleepHours >= 6.5 && todaySleepHours <= 9.5 {
            score = 70 + ((9.5 - abs(todaySleepHours - 8)) / 1.5) * 15 // Good: 70-85
        } else if todaySleepHours >= 6 && todaySleepHours <= 10 {
            score = 50 + ((10 - abs(todaySleepHours - 8)) / 2) * 20 // Fair: 50-70
        } else if todaySleepHours >= 5 && todaySleepHours <= 11 {
            score = 30 + ((11 - abs(todaySleepHours - 8)) / 3) * 20 // Poor: 30-50
        } else {
            score = max(10, 30 - abs(todaySleepHours - 8) * 2) // Very Poor: 10-30
        }
        
        let finalScore = max(0, min(100, score))
        print("🧮 Sleep calculation: \(todaySleepHours)h -> \(Int(finalScore))")
        
        return Int(finalScore)
    }
    
    private func computeStrainScore() -> Int {
        // Strain should reflect actual physical activity, not just steps
        guard todaySteps > 0 || todayActiveEnergy > 0 else {
            print("🧮 Strain: No activity data available")
            return 0
        }
        
        // More sophisticated strain calculation
        var strainScore = 0.0
        
        // Steps component (40% weight) - with diminishing returns
        let stepScore: Double
        if todaySteps >= 12000 {
            stepScore = 90 + min(10, (todaySteps - 12000) / 3000 * 10) // High activity: 90-100
        } else if todaySteps >= 8000 {
            stepScore = 70 + ((todaySteps - 8000) / 4000) * 20 // Moderate: 70-90
        } else if todaySteps >= 5000 {
            stepScore = 40 + ((todaySteps - 5000) / 3000) * 30 // Low-Moderate: 40-70
        } else if todaySteps >= 2000 {
            stepScore = 20 + ((todaySteps - 2000) / 3000) * 20 // Low: 20-40
        } else {
            stepScore = max(5, todaySteps / 2000 * 20) // Very Low: 5-20
        }
        
        // Active energy component (60% weight) - more important for strain
        let energyScore: Double
        if todayActiveEnergy >= 600 {
            energyScore = 85 + min(15, (todayActiveEnergy - 600) / 200 * 15) // High: 85-100
        } else if todayActiveEnergy >= 400 {
            energyScore = 65 + ((todayActiveEnergy - 400) / 200) * 20 // Moderate: 65-85
        } else if todayActiveEnergy >= 200 {
            energyScore = 35 + ((todayActiveEnergy - 200) / 200) * 30 // Low-Moderate: 35-65
        } else if todayActiveEnergy >= 100 {
            energyScore = 15 + ((todayActiveEnergy - 100) / 100) * 20 // Low: 15-35
        } else {
            energyScore = max(5, todayActiveEnergy / 100 * 15) // Very Low: 5-15
        }
        
        // Weighted combination
        strainScore = (stepScore * 0.4) + (energyScore * 0.6)
        
        let finalScore = max(0, min(100, strainScore))
        print("🧮 Strain calculation: Steps=\(Int(todaySteps)) (score: \(Int(stepScore))), Energy=\(Int(todayActiveEnergy))cal (score: \(Int(energyScore))), Final=\(Int(finalScore))")
        
        return Int(finalScore)
    }
    
    private func updateCoachingMessage() {
        if !hasHealthKitPermission {
            coachingMessage = "Connect your health data to see personalized insights!"
            return
        }
        let recoveryVal: Int? = { if case .computed(let v) = recoveryScoreState { return v } else { return nil } }()
        let sleepVal: Int? = { if case .computed(let v) = sleepScoreState { return v } else { return nil } }()
        let strainVal: Int? = { if case .computed(let v) = strainScoreState { return v } else { return nil } }()
        if recoveryVal == nil && sleepVal == nil && strainVal == nil {
            coachingMessage = "Keep wearing your Apple Watch to collect health metrics for personalized insights."
            return
        }
        var messages: [String] = []
        if let r = recoveryVal {
            if r >= 85 {
                messages.append("Excellent recovery! Your body is primed for high-intensity activities.")
            } else if r >= 70 {
                messages.append("Good recovery. You're ready for moderate to high activity.")
            } else if r >= 50 {
                messages.append("Fair recovery. Consider light to moderate activity today.")
            } else {
                messages.append("Low recovery detected. Focus on rest and stress management.")
            }
        }
        if let s = sleepVal {
            if s >= 85 {
                messages.append("Great sleep quality!")
            } else if s < 50 {
                messages.append("Consider improving your sleep routine for better recovery.")
            }
        }
        if let st = strainVal {
            if st < 30 {
                messages.append("Low activity detected. Try to increase your daily movement.")
            } else if st >= 80 {
                messages.append("High activity level - great job staying active!")
            }
        }
        coachingMessage = messages.isEmpty ? "Gathering your health data... Wear your Apple Watch for better insights." : messages.joined(separator: " ")
    }
    
    // MARK: - Public API
    
    func requestHealthKitPermissions() async {
        print("🔴 HomeViewModel.requestHealthKitPermissions() called")
        await dataManager.requestHealthKitPermissions()
    }
    
    func refreshPermissions() async {
        print("🔄 HomeViewModel.refreshPermissions() called")
        await dataManager.refreshPermissions()
    }
    
    func refreshAll() {
        print("🔄 HomeViewModel.refreshAll() called")
        dataManager.refreshAll()
    }
    
    func loadScores(for date: Date) async {
        print("🔄 Loading scores for selected date: \(date)")
        let score = await dataManager.scores(on: date)
        let r = Int(score.recovery.value)
        let s = Int(score.sleep.value)
        let st = Int(score.strain.value)
        self.recoveryScoreState = r > 0 ? .computed(r) : .unavailable
        self.sleepScoreState = s > 0 ? .computed(s) : .unavailable
        self.strainScoreState = st > 0 ? .computed(st) : .unavailable
        self.updateCoachingMessage()
    }
    
    // MARK: - Computed Properties for UI
    
    var hasAnyData: Bool {
        return dataManager.hasBiologyData || dataManager.hasTodayData
    }
    
    var canShowScores: Bool {
        return hasHealthKitPermission && hasAnyData
    }
    
    var formattedRHR: String {
        guard let rhr = latestRHR, rhr > 0 else { return "—" }
        return String(format: "%.0f", rhr)
    }
    
    var formattedHRV: String {
        guard let hrv = latestHRV, hrv > 0 else { return "—" }
        return String(format: "%.1f", hrv)
    }
    
    var formattedVO2Max: String {
        guard let vo2Max = latestVO2Max, vo2Max > 0 else { return "—" }
        return String(format: "%.1f", vo2Max)
    }
    
    var formattedWeight: String {
        guard let weight = latestWeight, weight > 0 else { return "—" }
        return String(format: "%.1f", weight)
    }
    
    var formattedSteps: String {
        return String(format: "%.0f", todaySteps)
    }
    
    var formattedHeartRate: String {
        guard todayHeartRate > 0 else { return "—" }
        return String(format: "%.0f", todayHeartRate)
    }
    
    var formattedActiveEnergy: String {
        return String(format: "%.0f", todayActiveEnergy)
    }
    
    var formattedSleepHours: String {
        guard todaySleepHours > 0 else { return "—" }
        return String(format: "%.1f", todaySleepHours)
    }
}
