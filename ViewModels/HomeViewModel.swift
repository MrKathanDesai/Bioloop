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
    
    // Authorization state
    @Published var hasHealthKitPermission: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Coaching message
    @Published var coachingMessage: String = "Welcome to Bioloop! Connect your health data to get started."

    init() {
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        print("🔗 Setting up HomeViewModel subscriptions...")
        
        // Subscribe to DataManager's series data (which are @Published)
        dataManager.$rhrSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 RHR series updated: \(series.count) points")
                self?.latestRHR = series.last?.value
                self?.recomputeScores()
            }
            .store(in: &cancellables)
        
        dataManager.$hrvSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 HRV series updated: \(series.count) points")
                self?.latestHRV = series.last?.value
                self?.recomputeScores()
            }
            .store(in: &cancellables)
        
        dataManager.$vo2MaxSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 VO2 Max series updated: \(series.count) points")
                self?.latestVO2Max = series.last?.value
                self?.recomputeScores()
            }
            .store(in: &cancellables)
        
        dataManager.$weightSeries
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 Weight series updated: \(series.count) points")
                self?.latestWeight = series.last?.value
                self?.recomputeScores()
            }
            .store(in: &cancellables)

        // Subscribe to today's metrics
        dataManager.$todaySteps
            .receive(on: RunLoop.main)
            .assign(to: \.todaySteps, on: self)
            .store(in: &cancellables)
            
        dataManager.$todayHeartRate
            .receive(on: RunLoop.main)
            .assign(to: \.todayHeartRate, on: self)
            .store(in: &cancellables)
            
        dataManager.$todayActiveEnergy
            .receive(on: RunLoop.main)
            .assign(to: \.todayActiveEnergy, on: self)
            .store(in: &cancellables)
            
        dataManager.$todaySleepHours
            .receive(on: RunLoop.main)
            .assign(to: \.todaySleepHours, on: self)
            .store(in: &cancellables)
        
        // Subscribe to authorization state
        dataManager.$hasHealthKitPermission
            .receive(on: RunLoop.main)
            .sink { [weak self] hasPermission in
                print("🔗 Permission status updated: \(hasPermission)")
                self?.hasHealthKitPermission = hasPermission
                self?.updateCoachingMessage()
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
    
    private func recomputeScores() {
        print("🧮 Recomputing scores...")
        
        // Recovery Score (based on HRV and RHR)
        recoveryScore = computeRecoveryScore()
        
        // Sleep Score (based on sleep hours)
        sleepScore = computeSleepScore()
        
        // Strain Score (based on activity)
        strainScore = computeStrainScore()
        
                updateCoachingMessage()
        
        print("🧮 Scores updated - Recovery: \(recoveryScore), Sleep: \(sleepScore), Strain: \(strainScore)")
    }
    
    private func computeRecoveryScore() -> Int {
        guard let hrv = latestHRV, let rhr = latestRHR else {
            return 0
        }
        
        // Simple scoring algorithm
        // HRV: Higher is better (typical range 20-60ms)
        // RHR: Lower is better (typical range 50-100 bpm)
        
        let hrvScore = min(100, max(0, (hrv - 20) / 40 * 100)) // 20-60ms -> 0-100
        let rhrScore = min(100, max(0, (100 - rhr) / 50 * 100)) // 50-100 bpm -> 100-0
        
        let combinedScore = (hrvScore + rhrScore) / 2
        return Int(combinedScore)
    }
    
    private func computeSleepScore() -> Int {
        guard todaySleepHours > 0 else { return 0 }
        
        // Optimal sleep is 7-9 hours
        if todaySleepHours >= 7 && todaySleepHours <= 9 {
            return 100
        } else if todaySleepHours >= 6 && todaySleepHours < 7 {
            return 80
        } else if todaySleepHours > 9 && todaySleepHours <= 10 {
            return 80
        } else if todaySleepHours >= 5 && todaySleepHours < 6 {
            return 60
        } else if todaySleepHours > 10 {
            return 60
        } else {
            return 40
        }
    }
    
    private func computeStrainScore() -> Int {
        // Based on steps and active energy
        let stepScore = min(100, max(0, todaySteps / 10000 * 100)) // 10k steps = 100%
        let energyScore = min(100, max(0, todayActiveEnergy / 500 * 100)) // 500 cal = 100%
        
        return Int((stepScore + energyScore) / 2)
    }
    
    private func updateCoachingMessage() {
        if !hasHealthKitPermission {
            coachingMessage = "Connect your health data to see personalized insights!"
        } else if !dataManager.hasBiologyData {
            coachingMessage = "Great! Your basic metrics are connected. Keep wearing your Apple Watch to see advanced insights."
        } else {
            // Generate personalized coaching based on scores
            if recoveryScore >= 80 {
                coachingMessage = "Excellent recovery! Your body is well-rested and ready for activity."
            } else if recoveryScore >= 60 {
                coachingMessage = "Good recovery. Consider light activity or rest based on how you feel."
            } else if recoveryScore >= 40 {
                coachingMessage = "Moderate recovery. Focus on rest and light movement today."
            } else {
                coachingMessage = "Low recovery detected. Prioritize rest and gentle activities."
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
