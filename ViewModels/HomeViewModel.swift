import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    static let shared = HomeViewModel()

    private let dataManager = DataManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Published UI state
    @Published var recoveryScore: Int = 0
    @Published var sleepScore: Int = 0
    @Published var strainScore: Int = 0
    
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

    init() {
        setupSubscriptions()
        // Morning snapshot will be computed once when first data arrives
    }

    private func setupSubscriptions() {
        print("🔗 Setting up HomeViewModel subscriptions...")
        
        // Subscribe to DataManager's series data (which are @Published)
        dataManager.$rhrSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 RHR series updated: \(series.count) points")
                self?.latestRHR = series.last?.value
                self?.attemptMorningSnapshotIfNeeded()
                // If snapshot already taken but recovery not computed yet, try now when RHR arrives
                if let self = self, self.didTakeMorningSnapshot, self.recoveryScore == 0, self.dataManager.canComputeRecoveryScore {
                    self.recoveryScore = self.computeRecoveryScore()
                    self.updateCoachingMessage()
                }
            }
            .store(in: &cancellables)
        
        dataManager.$hrvSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 HRV series updated: \(series.count) points")
                self?.latestHRV = series.last?.value
                self?.attemptMorningSnapshotIfNeeded()
                // If snapshot already taken but recovery not computed yet, try now when HRV arrives
                if let self = self, self.didTakeMorningSnapshot, self.recoveryScore == 0, self.dataManager.canComputeRecoveryScore {
                    self.recoveryScore = self.computeRecoveryScore()
                    self.updateCoachingMessage()
                }
            }
            .store(in: &cancellables)

        // Recompute recovery when recency dates update (avoids race with series updates)
        dataManager.$latestHRVDate
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.didTakeMorningSnapshot, self.recoveryScore == 0, self.dataManager.canComputeRecoveryScore {
                    self.recoveryScore = self.computeRecoveryScore()
                    self.updateCoachingMessage()
                }
            }
            .store(in: &cancellables)

        dataManager.$latestRHRDate
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.didTakeMorningSnapshot, self.recoveryScore == 0, self.dataManager.canComputeRecoveryScore {
                    self.recoveryScore = self.computeRecoveryScore()
                    self.updateCoachingMessage()
                }
            }
            .store(in: &cancellables)
        
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

        // Subscribe to today's metrics
        dataManager.$todaySteps
            .receive(on: RunLoop.main)
            .sink { [weak self] v in
                self?.todaySteps = v
                // Strain is the only score that should live-update during the day
                self?.strainScore = self?.computeStrainScore() ?? 0
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
                // Update strain only
                self?.strainScore = self?.computeStrainScore() ?? 0
            }
            .store(in: &cancellables)
            
        dataManager.$todaySleepHours
            .receive(on: RunLoop.main)
            .sink { [weak self] v in
                self?.todaySleepHours = v
                // Compute sleep score as soon as valid sleep is available, independent of snapshot
                if let self = self, self.sleepScore == 0, v > 0 {
                    self.sleepScore = self.computeSleepScore()
                    self.updateCoachingMessage()
                }
                // Do not trigger recovery snapshot here
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
        print("🧮 Morning snapshot score computation...")
        recoveryScore = computeRecoveryScore()
        // Sleep: compute only if not already set
        if todaySleepHours > 0 && sleepScore == 0 {
            sleepScore = computeSleepScore()
        }
        // Strain will live-update throughout the day from publishers
        strainScore = computeStrainScore()
        updateCoachingMessage()
        print("🧮 Morning snapshot set - Recovery: \(recoveryScore), Sleep: \(sleepScore), Strain: \(strainScore)")
    }

    // Compute once when data is available
    private var didTakeMorningSnapshot: Bool = false
    private func attemptMorningSnapshotIfNeeded() {
        guard !didTakeMorningSnapshot else { return }
        // Only take snapshot when both HRV and RHR are available (sleep alone should not trigger recovery snapshot)
        let haveRecoveryInputs = (latestHRV ?? 0) > 0 && (latestRHR ?? 0) > 0
        if haveRecoveryInputs {
            recomputeScoresMorningSnapshot()
            didTakeMorningSnapshot = true
        }
    }
    
    private func computeRecoveryScore() -> Int {
        // Recovery score should only be calculated if we have recent, valid data
        guard let hrv = latestHRV, 
              let rhr = latestRHR,
              dataManager.hasRecentHRV,
              dataManager.hasRecentRHR,
              hrv > 0,
              rhr > 0 else {
            print("🧮 Recovery: No recent HRV/RHR data available")
            return 0
        }
        
        // Enhanced recovery algorithm with more realistic scoring
        var recoveryScore = 50.0 // Base score
        
        // HRV Component (50% weight)
        // Typical healthy ranges: 20-50ms (varies by age/fitness)
        let hrvScore: Double
        if hrv >= 40 {
            hrvScore = 85 + min(15, (hrv - 40) * 0.5) // Excellent: 85-100
        } else if hrv >= 30 {
            hrvScore = 70 + ((hrv - 30) / 10) * 15 // Good: 70-85
        } else if hrv >= 20 {
            hrvScore = 50 + ((hrv - 20) / 10) * 20 // Fair: 50-70
        } else {
            hrvScore = max(10, hrv * 2.5) // Poor: 10-50
        }
        
        // RHR Component (50% weight)
        // Typical ranges: 50-100 bpm (lower is generally better)
        let rhrScore: Double
        if rhr <= 55 {
            rhrScore = 90 + min(10, (55 - rhr) * 0.5) // Excellent: 90-100
        } else if rhr <= 65 {
            rhrScore = 75 + ((65 - rhr) / 10) * 15 // Good: 75-90
        } else if rhr <= 80 {
            rhrScore = 50 + ((80 - rhr) / 15) * 25 // Fair: 50-75
        } else {
            rhrScore = max(10, (120 - rhr) * 0.8) // Poor: 10-50
        }
        
        // Combine scores
        recoveryScore = (hrvScore + rhrScore) / 2
        
        // Factor in sleep quality if available
        if todaySleepHours > 0 {
            let sleepMultiplier: Double
            if todaySleepHours >= 7 && todaySleepHours <= 9 {
                sleepMultiplier = 1.1 // Boost for optimal sleep
            } else if todaySleepHours >= 6 && todaySleepHours <= 10 {
                sleepMultiplier = 1.0 // Neutral for decent sleep
            } else {
                sleepMultiplier = 0.85 // Penalty for poor sleep
            }
            recoveryScore *= sleepMultiplier
        }
        
        // Clamp between 0-100
        let finalScore = max(0, min(100, recoveryScore))
        
        print("🧮 Recovery calculation: HRV=\(hrv)ms (score: \(Int(hrvScore))), RHR=\(rhr)bpm (score: \(Int(rhrScore))), Sleep=\(todaySleepHours)h, Final=\(Int(finalScore))")
        
        return Int(finalScore)
    }
    
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
        } else if recoveryScore == 0 && sleepScore == 0 && strainScore == 0 {
            coachingMessage = "Keep wearing your Apple Watch to collect health metrics for personalized insights."
        } else {
            // Generate coaching based on available scores
            var messages: [String] = []
            
            // Recovery-based coaching
            if recoveryScore > 0 {
                if recoveryScore >= 85 {
                    messages.append("Excellent recovery! Your body is primed for high-intensity activities.")
                } else if recoveryScore >= 70 {
                    messages.append("Good recovery. You're ready for moderate to high activity.")
                } else if recoveryScore >= 50 {
                    messages.append("Fair recovery. Consider light to moderate activity today.")
                } else {
                    messages.append("Low recovery detected. Focus on rest and stress management.")
                }
            }
            
            // Sleep-based coaching
            if sleepScore > 0 {
                if sleepScore >= 85 {
                    messages.append("Great sleep quality!")
                } else if sleepScore < 50 {
                    messages.append("Consider improving your sleep routine for better recovery.")
                }
            }
            
            // Strain-based coaching
            if strainScore > 0 {
                if strainScore < 30 {
                    messages.append("Low activity detected. Try to increase your daily movement.")
                } else if strainScore >= 80 {
                    messages.append("High activity level - great job staying active!")
                }
            }
            
            // Combine messages or use default
            if messages.isEmpty {
                coachingMessage = "Gathering your health data... Wear your Apple Watch for better insights."
            } else {
                coachingMessage = messages.joined(separator: " ")
            }
        }
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
        self.recoveryScore = Int(score.recovery.value)
        self.sleepScore = Int(score.sleep.value)
        self.strainScore = Int(score.strain.value)
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
