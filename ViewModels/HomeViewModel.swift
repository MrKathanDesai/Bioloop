import Foundation
import Combine
import SwiftUI
import HealthKit

// MARK: - Enhanced Home ViewModel

@MainActor
class HomeViewModel: ObservableObject {
    static let shared = HomeViewModel()

    private let dataManager = DataManager.shared
    private let calculator = HealthCalculator.shared

    @Published var selectedDate = Date()
    @Published var currentHealthScore: HealthScore?
    @Published var dataAvailability: Bioloop.DataAvailability?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // New UI-specific data properties
    @Published var coachingMessage: CoachingMessage?
    @Published var stressMetrics: StressMetrics?
    @Published var energyLevel: EnergyLevel?
    @Published var nutritionData: NutritionData?
    @Published var userProfile: UserProfile?
    
    var hasHealthKitPermission: Bool {
        return dataManager.hasHealthKitPermission
    }
    
    // Historical data for charts
    @Published var historicalScores: [HealthScore] = []
    @Published var recoveryTrend: [Double] = []
    @Published var sleepTrend: [Double] = []
    @Published var strainTrend: [Double] = []
    @Published var stressTrend: [Double] = []

    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupSubscriptions()
        setupDefaultData()
    }

    private func setupSubscriptions() {
        // Subscribe to data manager changes
        dataManager.$healthScores
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scores in
                self?.updateTrends()
            }
            .store(in: &cancellables)

        dataManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
    }
    
    private func setupDefaultData() {
        // Initialize with default values for UI testing
        userProfile = UserProfile(initials: "KD", name: "Katharine Desai")
        coachingMessage = CoachingMessage(
            message: "Excellent recovery! Target a Strain level of 24% - 62% for optimal training today.",
            type: .recovery,
            priority: .high
        )
        stressMetrics = StressMetrics(
            highest: 75,
            lowest: 0,
            average: 12,
            current: 48,
            level: .moderate,
            lastUpdated: Date()
        )
        energyLevel = EnergyLevel(
            percentage: 90,
            level: .high,
            lastUpdated: Date()
        )
        nutritionData = NutritionData(
            carbohydrates: 88,
            fat: 4,
            protein: 0.8,
            lastUpdated: Date()
        )
    }

    // MARK: - Data Loading

    func loadHealthData(for date: Date? = nil) async {
        let targetDate = date ?? selectedDate
        selectedDate = targetDate

        print("📱 Loading health data for: \(targetDate)")
        
        isLoading = true
        errorMessage = nil

        // Always create a fallback score first so UI can show
        let fallbackScore = HealthScore(
            recovery: HealthScore.ScoreComponent(value: 95, status: .optimal, trend: nil, subMetrics: nil),
            sleep: HealthScore.ScoreComponent(value: 73, status: .optimal, trend: nil, subMetrics: nil),
            strain: HealthScore.ScoreComponent(value: 25, status: .optimal, trend: nil, subMetrics: nil),
            stress: HealthScore.ScoreComponent(value: 48, status: .optimal, trend: nil, subMetrics: nil),
            date: targetDate,
            dataAvailability: DataAvailability(hasHealthKitPermission: false, hasAppleWatchData: false, lastSyncDate: nil, missingDataTypes: [])
        )
        
        // Set the fallback score immediately so UI can render
        currentHealthScore = fallbackScore
        updateCoachingMessage()
        updateStressMetrics()
        updateEnergyLevel()
        updateNutritionData()
        
        // Now try to load real data if permissions are available
        do {
            // Check data availability first
            dataAvailability = dataManager.checkDataAvailability()

            if dataAvailability?.isFullyAvailable == true {
                print("✅ HealthKit available, loading real data")
                
                // Fetch health data
                let score = try await dataManager.fetchHealthData(for: targetDate)
                currentHealthScore = score

                // Update trends
                updateTrends()
                
                // Update UI-specific data with real data
                updateCoachingMessage()
                updateStressMetrics()
                updateEnergyLevel()
                updateNutritionData()

                print("✅ Health data loaded successfully")
            } else {
                print("⚠️ HealthKit not available, using sample data")
                errorMessage = "HealthKit permissions not available. Showing sample data."
            }

        } catch {
            errorMessage = "Failed to load health data: \(error.localizedDescription)"
            print("❌ Error loading health data: \(error)")
            // Keep the fallback score, so UI still works
        }
        
        isLoading = false
    }
    
    func loadHistoricalData(days: Int = 30) async {
        print("📊 Loading historical data for \(days) days...")

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        guard let dateRange = startDate...endDate as? ClosedRange<Date> else {
            return
        }

        do {
            let scores = try await dataManager.fetchHealthScores(for: dateRange)
            historicalScores = scores
            updateTrends()
            print("✅ Loaded \(scores.count) historical data points")
        } catch {
            print("❌ Failed to load historical data: \(error)")
        }
    }

    // MARK: - Trend Updates

    private func updateTrends() {
        recoveryTrend = dataManager.getTrendData(for: "recovery", days: 7)
        sleepTrend = dataManager.getTrendData(for: "sleep", days: 7)
        strainTrend = dataManager.getTrendData(for: "strain", days: 7)
        stressTrend = dataManager.getTrendData(for: "stress", days: 7)

        print("📈 Trends updated - Recovery: \(recoveryTrend.count), Sleep: \(sleepTrend.count)")
    }

    // MARK: - UI Data Updates
    
    private func updateCoachingMessage() {
        guard let score = currentHealthScore else { return }
        
        let recovery = score.recovery.value
        
        if recovery >= 80 {
            coachingMessage = CoachingMessage(
                message: "Excellent recovery! Target a Strain level of 24% - 62% for optimal training today.",
                type: .recovery,
                priority: .high
            )
        } else if recovery >= 60 {
            coachingMessage = CoachingMessage(
                message: "Good recovery. Consider moderate activity with Strain target of 15% - 40%.",
                type: .recovery,
                priority: .medium
            )
        } else {
            coachingMessage = CoachingMessage(
                message: "Recovery needs attention. Focus on rest and recovery activities.",
                type: .recovery,
                priority: .low
            )
        }
    }
    
    private func updateStressMetrics() {
        guard let score = currentHealthScore else { return }
        
        let stressValue = score.stress.value
        let level: StressMetrics.StressLevel = stressValue < 30 ? .low : stressValue < 70 ? .moderate : .high
        
        stressMetrics = StressMetrics(
            highest: Int(stressValue * 1.2),
            lowest: Int(stressValue * 0.3),
            average: Int(stressValue * 0.8),
            current: Int(stressValue),
            level: level,
            lastUpdated: Date()
        )
    }
    
    private func updateEnergyLevel() {
        guard let score = currentHealthScore else { return }
        
        let recovery = score.recovery.value
        let sleep = score.sleep.value
        let energyPercentage = Int((recovery + sleep) / 2)
        let level: EnergyLevel.Level = energyPercentage >= 80 ? .high : energyPercentage >= 60 ? .medium : .low
        
        energyLevel = EnergyLevel(
            percentage: energyPercentage,
            level: level,
            lastUpdated: Date()
        )
    }
    
    private func updateNutritionData() {
        // This would typically come from HealthKit nutrition data
        // For now, using sample data
        nutritionData = NutritionData(
            carbohydrates: 88,
            fat: 4,
            protein: 0.8,
            lastUpdated: Date()
        )
    }

    // MARK: - Permissions

    func requestHealthKitPermissions() async {
        do {
            print("🔐 Requesting HealthKit permissions from HomeViewModel...")
            try await dataManager.requestHealthKitPermissions()
            
            // Force a refresh of the permission status
            await MainActor.run {
                dataManager.updatePermissionStatus()
                dataAvailability = dataManager.checkDataAvailability()
            }

            if dataAvailability?.isFullyAvailable == true {
                // Reload data now that we have permissions
                await loadHealthData()
            } else {
                print("⚠️ Permissions requested but still not fully available")
                // Force another refresh after a short delay
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await MainActor.run {
                    dataManager.updatePermissionStatus()
                    dataAvailability = dataManager.checkDataAvailability()
                }
            }
        } catch {
            errorMessage = "Failed to get HealthKit permissions: \(error.localizedDescription)"
            print("❌ Permission request failed: \(error)")
        }
    }
    
    /// Force refresh permissions status
    func refreshPermissions() {
        print("🔄 Force refreshing permissions from HomeViewModel...")
        dataManager.updatePermissionStatus()
        dataAvailability = dataManager.checkDataAvailability()
    }

    // MARK: - Score Access

    func getScoreValue(_ scoreType: HealthScoreType) -> Double {
        guard let score = currentHealthScore else { return 0 }

        switch scoreType {
        case .recovery:
            return score.recovery.value
        case .sleep:
            return score.sleep.value
        case .strain:
            return score.strain.value
        case .stress:
            return score.stress.value
        }
    }

    func getScoreStatus(_ scoreType: HealthScoreType) -> HealthScore.ScoreStatus {
        guard let score = currentHealthScore else { return .unavailable }

        switch scoreType {
        case .recovery:
            return score.recovery.status
        case .sleep:
            return score.sleep.status
        case .strain:
            return score.strain.status
        case .stress:
            return score.stress.status
        }
    }

    func isDataAvailableForScore(_ scoreType: HealthScoreType) -> Bool {
        guard let score = currentHealthScore else { return false }

        switch scoreType {
        case .recovery:
            return score.recovery.status != .unavailable
        case .sleep:
            return score.sleep.status != .unavailable
        case .strain:
            return score.strain.status != .unavailable
        case .stress:
            return score.stress.status != .unavailable
        }
    }

    func getSubMetrics(for scoreType: HealthScoreType) -> [String: Double]? {
        guard let score = currentHealthScore else { return nil }

        switch scoreType {
        case .recovery:
            return score.recovery.subMetrics
        case .sleep:
            return score.sleep.subMetrics
        case .strain:
            return score.strain.subMetrics
        case .stress:
            return score.stress.subMetrics
        }
    }

    // MARK: - Journal

    func saveJournalEntry(title: String, content: String, mood: Int? = nil, factors: [String] = []) {
        let entry = JournalEntry(
            date: selectedDate,
            title: title,
            content: content,
            mood: mood,
            factors: factors
        )
        dataManager.saveJournalEntry(entry)
    }

    func getJournalEntries(for date: Date) -> [JournalEntry] {
        return dataManager.getJournalEntries(for: date)
    }

    // MARK: - Debug

    func debugDataStatus() {
        print("🔍 Debug Data Status:")
        print("   Selected Date: \(selectedDate)")
        print("   Current Score Available: \(currentHealthScore != nil)")
        print("   HealthKit Permission: \(dataManager.hasHealthKitPermission)")
        print("   Data Availability: \(dataAvailability?.isFullyAvailable ?? false)")
        print("   Recovery Trend Points: \(recoveryTrend.count)")
        print("   Historical Scores: \(historicalScores.count)")
    }

    // MARK: - Integration Test

    func runIntegrationTest() async {
        print("🧪 Running Integration Test...")

        // Test 1: HealthKit Manager
        print("📊 Testing HealthKit Manager...")
        let dataAvailability = dataManager.checkDataAvailability()
        let isAvailable = dataAvailability.hasHealthKitPermission
        print("   ✅ HealthKit Manager: \(isAvailable ? "Available" : "Not Available")")

        // Test 2: Data Fetching
        print("📊 Testing Data Fetching...")
        do {
            let testDate = Date()
            let score = try await dataManager.fetchHealthData(for: testDate)
            print("   ✅ Data Fetching: Success")
            print("   ✅ Recovery Score: \(score.recovery.value)")
        } catch {
            print("   ⚠️ Data Fetching: Failed (\(error.localizedDescription))")
        }

        // Test 3: Calculator
        print("📊 Testing Calculator...")
        let sampleData = HealthData(
            date: Date(),
            hrv: 45.0,
            restingHeartRate: 55.0,
            heartRate: 70.0,
            energyBurned: 400.0,
            sleepDuration: 8.0,
            sleepEfficiency: 0.85
        )
        let calculatedScore = calculator.calculateHealthScores(from: sampleData)
        print("   ✅ Calculator: Recovery \(calculatedScore.recovery.value), Sleep \(calculatedScore.sleep.value)")

        print("🎉 Integration Test Complete!")
    }

    // MARK: - Score Access Methods

    func getScoreForType(_ type: HealthScoreType) -> HealthScore.ScoreComponent? {
        guard let currentScore = currentHealthScore else { return nil }

        switch type {
        case .recovery:
            return currentScore.recovery
        case .sleep:
            return currentScore.sleep
        case .strain:
            return currentScore.strain
        case .stress:
            return currentScore.stress
        }
    }

    func getHealthKitAuthorizationStatus() -> HKAuthorizationStatus {
        return dataManager.getHealthKitAuthorizationStatus()
    }


}

// MARK: - Supporting Types

enum HealthScoreType: String {
    case recovery = "Recovery"
    case sleep = "Sleep"
    case strain = "Strain"
    case stress = "Stress"

    var title: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .recovery: return "heart.fill"
        case .sleep: return "moon.fill"
        case .strain: return "flame.fill"
        case .stress: return "waveform.path.ecg"
        }
    }
    
    var color: Color {
        switch self {
        case .recovery: return .green
        case .sleep: return .blue
        case .strain: return .orange
        case .stress: return .red
        }
    }
    
    var detailExplanation: String {
        switch self {
        case .recovery:
            return "Recovery measures how well your body is recovering from daily stress and exercise. Higher scores indicate better recovery and readiness for activity."
        case .sleep:
            return "Sleep quality assesses your nightly rest patterns including duration, efficiency, and sleep stages. Quality sleep is essential for optimal recovery."
        case .strain:
            return "Strain represents the physical demands placed on your body through exercise and daily activities. It helps you understand your activity intensity."
        case .stress:
            return "Stress tracks your body's response to various stressors including mental, physical, and environmental factors."
        }
    }
}

