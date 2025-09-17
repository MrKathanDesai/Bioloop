import Foundation
import CoreData
import Combine
import HealthKit

// MARK: - Apple HealthKit Best Practices Data Manager

@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()

    private let healthKitManager = HealthKitManager.shared
    private let calculator = HealthCalculator.shared

    @Published var healthScores: [Date: HealthScore] = [:]
    @Published var journalEntries: [JournalEntry] = []
    @Published var isLoading = false
    @Published var hasHealthKitPermission: Bool = false

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Privacy-Compliant Caching
    // Only cache non-sensitive calculated scores, not raw health data
    private var scoreCache: [Date: HealthScore] = [:]
    private let maxCacheSize = 30 // Keep only 30 days of cached scores
    private let cacheExpirationTime: TimeInterval = 3600 // 1 hour

    init() {
        print("🚀 DataManager initialized with Apple HealthKit best practices")
        setupHealthKitObservation()
        updatePermissionStatus()
        startHealthDataObservation()
    }

    private func setupHealthKitObservation() {
        print("🔧 Setting up HealthKit observation")
        healthKitManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📡 Received HealthKit change notification")
                self?.updatePermissionStatus()
            }
            .store(in: &cancellables)
    }
    
    private func startHealthDataObservation() {
        // Start observing health data changes for real-time updates
        healthKitManager.startObservingHealthData()
    }

    func updatePermissionStatus() {
        // Force a fresh permission check
        healthKitManager.refreshPermissions()
        
        let hkStatus = healthKitManager.authorizationStatus
        let newPermissionStatus = hkStatus == .sharingAuthorized

        print("🔍 updatePermissionStatus called:")
        print("   HealthKit status: \(hkStatus.rawValue)")
        print("   Current permission status: \(hasHealthKitPermission)")
        print("   New permission status: \(newPermissionStatus)")

        // Always update, even if same value, to ensure consistency
        hasHealthKitPermission = newPermissionStatus
        print("🔄 DataManager permission status updated to: \(hasHealthKitPermission)")
    }

    // MARK: - Data Fetching (Privacy-Compliant)

    func fetchHealthData(for date: Date) async throws -> HealthScore {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        // Check cache first (only for calculated scores, not raw data)
        if let cachedScore = getCachedScore(for: startOfDay) {
            print("📋 Using cached score for \(date)")
            return cachedScore
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Always fetch fresh data from HealthKit (source of truth)
            let rawData = try await healthKitManager.fetchHealthData(for: date)

            // Calculate scores from fresh data
            let score = calculator.calculateHealthScores(from: rawData)

            // Cache only the calculated score (not raw health data)
            cacheScore(score, for: startOfDay)

            return score
        } catch {
            print("❌ Error fetching health data: \(error)")
            throw error
        }
    }
    
    // MARK: - Privacy-Compliant Caching
    
    private func getCachedScore(for date: Date) -> HealthScore? {
        guard let cachedScore = scoreCache[date] else { return nil }
        
        // Check if cache is still valid (not expired)
        let cacheAge = Date().timeIntervalSince(cachedScore.date)
        if cacheAge > cacheExpirationTime {
            scoreCache.removeValue(forKey: date)
            return nil
        }
        
        return cachedScore
    }
    
    private func cacheScore(_ score: HealthScore, for date: Date) {
        // Clean up old cache entries to maintain privacy
        cleanupCache()
        
        // Store only the calculated score
        scoreCache[date] = score
        healthScores[date] = score
    }
    
    private func cleanupCache() {
        // Remove old cache entries to maintain privacy and performance
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(maxCacheSize * 24 * 3600)) // 30 days ago
        
        scoreCache = scoreCache.filter { $0.key >= cutoffDate }
        
        if scoreCache.count > maxCacheSize {
            // Remove oldest entries if we exceed max cache size
            let sortedEntries = scoreCache.sorted { $0.key < $1.key }
            let entriesToRemove = sortedEntries.prefix(scoreCache.count - maxCacheSize)
            
            for (date, _) in entriesToRemove {
                scoreCache.removeValue(forKey: date)
            }
        }
    }

    func fetchHealthScores(for dateRange: ClosedRange<Date>) async throws -> [HealthScore] {
        var scores: [HealthScore] = []
        let calendar = Calendar.current

        // Generate all dates in range
        var currentDate = dateRange.lowerBound
        while currentDate <= dateRange.upperBound {
            let startOfDay = calendar.startOfDay(for: currentDate)

            do {
                let score = try await fetchHealthData(for: startOfDay)
                scores.append(score)
            } catch {
                print("⚠️ Failed to fetch data for \(startOfDay): \(error)")
                // Create unavailable score for missing data
                let unavailableScore = HealthScore(
                    recovery: HealthScore.ScoreComponent(value: 0, status: .unavailable, trend: nil, subMetrics: nil),
                    sleep: HealthScore.ScoreComponent(value: 0, status: .unavailable, trend: nil, subMetrics: nil),
                    strain: HealthScore.ScoreComponent(value: 0, status: .unavailable, trend: nil, subMetrics: nil),
                    stress: HealthScore.ScoreComponent(value: 0, status: .unavailable, trend: nil, subMetrics: nil),
                    date: startOfDay,
                    dataAvailability: DataAvailability(hasHealthKitPermission: false, hasAppleWatchData: false, lastSyncDate: nil, missingDataTypes: [])
                )
                scores.append(unavailableScore)
            }

            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return scores
    }

    // MARK: - Trend Data

    func getTrendData(for scoreType: String, days: Int = 7) -> [Double] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        guard let dateRange = startDate...endDate as? ClosedRange<Date> else {
            return []
        }

        // Get scores from cache or calculate trends
        let scores = healthScores.values.filter { dateRange.contains($0.date) }
        return calculator.calculateTrend(for: Array(scores), scoreType: scoreType, days: days)
    }

    // MARK: - Cache Management (Privacy-Compliant)

    func clearCache() {
        scoreCache.removeAll()
        healthScores.removeAll()
        print("🧹 Privacy-compliant cache cleared")
    }

    func preloadHistoricalData(days: Int = 30) async {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate

        guard let dateRange = startDate...endDate as? ClosedRange<Date> else {
            return
        }

        print("📊 Preloading \(days) days of historical data...")

        do {
            let scores = try await fetchHealthScores(for: dateRange)
            print("✅ Preloaded \(scores.count) days of data")
        } catch {
            print("❌ Failed to preload historical data: \(error)")
        }
    }

    // MARK: - Journal Management (Placeholder)

    func saveJournalEntry(_ entry: JournalEntry) {
        journalEntries.append(entry)
        // TODO: Implement CoreData persistence
        print("✅ Journal entry saved: \(entry.title)")
    }

    func getJournalEntries(for date: Date) -> [JournalEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        return journalEntries.filter { entry in
            startOfDay <= entry.date && entry.date < endOfDay
        }
    }

    // MARK: - HealthKit Integration

    func requestHealthKitPermissions() async throws {
        print("🚀 Starting HealthKit permission request")
        let statusBefore = healthKitManager.authorizationStatus
        print("📊 Status before request: \(statusBefore.rawValue)")

        try await healthKitManager.requestPermissions()

        print("✅ Permission request completed")
        // Small delay to ensure HealthKit has processed the authorization
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let statusAfter = healthKitManager.authorizationStatus
        print("📊 Status after request: \(statusAfter.rawValue)")

        // Force update permission status
        await MainActor.run {
            updatePermissionStatus()
            print("🎯 Final permission status: \(hasHealthKitPermission)")
        }
    }

    func checkDataAvailability() -> DataAvailability {
        return healthKitManager.checkDataAvailability()
    }

    func getHealthKitAuthorizationStatus() -> HKAuthorizationStatus {
        return healthKitManager.authorizationStatus
    }
}


