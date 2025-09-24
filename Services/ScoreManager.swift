import Foundation
import Combine
import os

@MainActor
final class ScoreManager: ObservableObject {
    static let shared = ScoreManager()

    // Inputs
    private let dataManager = DataManager.shared
    private var cancellables: Set<AnyCancellable> = []

    // Outputs (tri-state)
    @Published private(set) var recoveryScoreState: HomeViewModel.ScoreState = .pending
    @Published private(set) var sleepScoreState: HomeViewModel.ScoreState = .pending
    @Published private(set) var strainScoreState: HomeViewModel.ScoreState = .pending

    private let logger = Logger(subsystem: "app.bioloop", category: "ScoreManager")

    private init() {
        setupPipelines()
    }

    private func setupPipelines() {
        // Recovery depends on HRV/RHR values and recency
        Publishers.CombineLatest4(
            dataManager.$latestHRV,
            dataManager.$latestRHR,
            dataManager.$latestHRVDate,
            dataManager.$latestRHRDate
        )
        .receive(on: RunLoop.main)
        .debounce(for: .seconds(HealthMetricsConfiguration.snapshotDebounceInterval), scheduler: RunLoop.main)
        .sink { [weak self] latestHRV, latestRHR, hrvDate, rhrDate in
            guard let self = self else { return }
            let hasRecentHRV = hrvDate.flatMap { Date().timeIntervalSince($0) <= HealthMetricsConfiguration.recencyWindowWatch } ?? false
            let hasRecentRHR = rhrDate.flatMap { Date().timeIntervalSince($0) <= HealthMetricsConfiguration.recencyWindowWatch } ?? false
            let canCompute = hasRecentHRV && hasRecentRHR
            self.logger.debug("Recovery pipeline: HRV=\(latestHRV ?? 0), RHR=\(latestRHR ?? 0), recentHRV=\(hasRecentHRV), recentRHR=\(hasRecentRHR)")
            guard canCompute, let hrv = latestHRV, let rhr = latestRHR, hrv > 0, rhr > 0 else {
                self.recoveryScoreState = .unavailable
                return
            }
            let score = self.calculateRecoveryFrom(hrv: hrv, rhr: rhr, sleepHours: self.dataManager.todaySleepHours)
            self.recoveryScoreState = .computed(score)
        }
        .store(in: &cancellables)

        // Sleep independent: compute when sleep > 0
        dataManager.$todaySleepHours
            .receive(on: RunLoop.main)
            .sink { [weak self] hours in
                guard let self = self else { return }
                if hours > 0 {
                    let score = self.calculateSleep(hours: hours)
                    if case .pending = self.sleepScoreState {
                        self.sleepScoreState = .computed(score)
                    }
                } else {
                    self.sleepScoreState = .pending
                }
            }
            .store(in: &cancellables)

        // Strain: recompute on steps/energy updates
        Publishers.CombineLatest(dataManager.$todaySteps, dataManager.$todayActiveEnergy)
            .receive(on: RunLoop.main)
            .sink { [weak self] steps, energy in
                guard let self = self else { return }
                let score = self.calculateStrain(steps: steps, energy: energy)
                self.strainScoreState = .computed(score)
            }
            .store(in: &cancellables)
    }

    // MARK: - Calculations (duplicate of VM logic, centralized)
    private func calculateRecoveryFrom(hrv: Double, rhr: Double, sleepHours: Double) -> Int {
        // HRV component
        let hrvScore: Double
        if hrv >= 40 {
            hrvScore = 85 + min(15, (hrv - 40) * 0.5)
        } else if hrv >= 30 {
            hrvScore = 70 + ((hrv - 30) / 10) * 15
        } else if hrv >= 20 {
            hrvScore = 50 + ((hrv - 20) / 10) * 20
        } else {
            hrvScore = max(10, hrv * 2.5)
        }

        // RHR component
        let rhrScore: Double
        if rhr <= 55 {
            rhrScore = 90 + min(10, (55 - rhr) * 0.5)
        } else if rhr <= 65 {
            rhrScore = 75 + ((65 - rhr) / 10) * 15
        } else if rhr <= 80 {
            rhrScore = 50 + ((80 - rhr) / 15) * 25
        } else {
            rhrScore = max(10, (120 - rhr) * 0.8)
        }

        var score = (hrvScore + rhrScore) / 2

        // Sleep multiplier
        if sleepHours > 0 {
            let multiplier: Double
            if sleepHours >= 7 && sleepHours <= 9 { multiplier = 1.1 }
            else if sleepHours >= 6 && sleepHours <= 10 { multiplier = 1.0 }
            else { multiplier = 0.85 }
            score *= multiplier
        }

        return Int(max(0, min(100, score)))
    }

    private func calculateSleep(hours: Double) -> Int {
        let score: Double
        if hours >= 7.5 && hours <= 8.5 {
            score = 95 + min(5, (8.5 - abs(hours - 8)) * 2)
        } else if hours >= 7 && hours <= 9 {
            score = 85 + ((9 - abs(hours - 8)) / 1) * 10
        } else if hours >= 6.5 && hours <= 9.5 {
            score = 70 + ((9.5 - abs(hours - 8)) / 1.5) * 15
        } else if hours >= 6 && hours <= 10 {
            score = 50 + ((10 - abs(hours - 8)) / 2) * 20
        } else if hours >= 5 && hours <= 11 {
            score = 30 + ((11 - abs(hours - 8)) / 3) * 20
        } else {
            score = max(10, 30 - abs(hours - 8) * 2)
        }
        return Int(max(0, min(100, score)))
    }

    private func calculateStrain(steps: Double, energy: Double) -> Int {
        // Step component
        let stepScore: Double
        if steps >= 12000 { stepScore = 90 + min(10, (steps - 12000) / 3000 * 10) }
        else if steps >= 8000 { stepScore = 70 + ((steps - 8000) / 4000) * 20 }
        else if steps >= 5000 { stepScore = 40 + ((steps - 5000) / 3000) * 30 }
        else if steps >= 2000 { stepScore = 20 + ((steps - 2000) / 3000) * 20 }
        else { stepScore = max(5, steps / 2000 * 20) }

        // Energy component
        let energyScore: Double
        if energy >= 600 { energyScore = 85 + min(15, (energy - 600) / 200 * 15) }
        else if energy >= 400 { energyScore = 65 + ((energy - 400) / 200) * 20 }
        else if energy >= 200 { energyScore = 35 + ((energy - 200) / 200) * 30 }
        else if energy >= 100 { energyScore = 15 + ((energy - 100) / 100) * 20 }
        else { energyScore = max(5, energy / 100 * 15) }

        let score = (stepScore * 0.4) + (energyScore * 0.6)
        return Int(max(0, min(100, score)))
    }
}


