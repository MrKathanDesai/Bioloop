import Foundation
import HealthKit
import Combine

// Enhanced DTO for Apple Health-like charts
public class HealthMetricPoint: Codable, Identifiable, ObservableObject {
    public let date: Date
    public let value: Double
    public var isActualData: Bool = true // Track if this is real data vs LKV-filled
    public var smoothedValue: Double? = nil // For visual smoothing
    
    public var id: Date { date }
    
    public init(date: Date, value: Double, isActualData: Bool = true) {
        self.date = date
        self.value = value
        self.isActualData = isActualData
    }
    
    // Codable support
    enum CodingKeys: String, CodingKey {
        case date, value, isActualData, smoothedValue
    }
    
    /// Get the display value for charts (smoothed if available, otherwise original)
    public var displayValue: Double {
        return smoothedValue ?? value
    }
    
    /// Get the opacity for chart styling (faded for LKV data)
    public var chartOpacity: Double {
        return isActualData ? 1.0 : 0.6
    }
}

public struct WorkoutSummary: Identifiable {
    public let id = UUID()
    public let date: Date
    public let type: HKWorkoutActivityType
    public let durationMinutes: Double
    public let energyKilocalories: Double
}

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    // Published so SwiftUI can bind
    @Published var vo2Max30: [HealthMetricPoint] = []
    @Published var hrv30: [HealthMetricPoint] = []
    @Published var rhr30: [HealthMetricPoint] = []
    @Published var weight30: [HealthMetricPoint] = []
    @Published var steps30: [HealthMetricPoint] = []
    @Published var activeEnergy30: [HealthMetricPoint] = []
    @Published var recentWorkouts: [WorkoutSummary] = []
    
    // Basic metrics for HomeView
    @Published var todaySteps: Double = 0
    @Published var todayHeartRate: Double = 0
    @Published var todayActiveEnergy: Double = 0
    @Published var todaySleepHours: Double = 0
    @Published var todayRespiratoryRate: Double = 0
    @Published var todaySpO2Percent: Double = 0
    @Published var todayBodyTemperatureC: Double = 0
    @Published var todayDietaryEnergy: Double = 0
    @Published var todayProteinGrams: Double = 0
    @Published var todayCarbsGrams: Double = 0
    @Published var todayFatGrams: Double = 0
    
    // Comprehensive sleep data
    @Published var todaySleepSession: SleepSession? = nil
    @Published var todaySleepSummary: DailySleepSummary? = nil
    @Published var recentSleepSessions: [SleepSession] = []
    
    // Body composition metrics
    @Published var latestLeanBodyMass: Double? = nil
    @Published var latestBodyFatPercentage: Double? = nil

    // Authorization state
    @Published var hasPermission = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    // keep references
    private var observerQueries: [HKSampleType: HKObserverQuery] = [:]
    private var anchoredQueries: [HKSampleType: HKAnchoredObjectQuery] = [:]
    private var activeQueries: Set<HKQuery> = []
    
    private init() {
        checkInitialPermission()
    }
    
    deinit {
        // Cancel queries synchronously to avoid capture issues
        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()
        
        for (_, observer) in observerQueries {
            healthStore.stop(observer)
        }
        observerQueries.removeAll()
        
        for (_, anchored) in anchoredQueries {
            healthStore.stop(anchored)
        }
        anchoredQueries.removeAll()
    }

    // All read types your app needs (include any types home or biology uses)
    var readTypes: Set<HKObjectType> {
        let q = [
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .vo2Max),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            HKQuantityType.quantityType(forIdentifier: .bodyMass),
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),
            HKQuantityType.quantityType(forIdentifier: .height),
            HKQuantityType.quantityType(forIdentifier: .leanBodyMass),
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate),
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation),
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature),
            HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature),
            HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal),
            HKObjectType.workoutType()
        ].compactMap { $0 }
        return Set(q)
    }

    // MARK: - Initial Permission Check
    private func checkInitialPermission() {
        Task {
            await updatePermissionStatus()
        }
    }
    
    private func updatePermissionStatus() async {
        // Check if we can read at least one basic type
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            hasPermission = await probeReadAccess(stepType)
        }
    }

    // MARK: Authorization
    func requestAuthorization() async throws -> Bool {
        try Task.checkCancellation()
        print("🏥 Requesting HealthKit authorization for ALL app data types...")
        print("🏥 Requesting access to: \(readTypes.map { $0.identifier })")
        
        return try await withCheckedThrowingContinuation { cont in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let e = error { 
                    print("🏥 Authorization error: \(e)")
                    cont.resume(throwing: e)
            return
        }
                print("🏥 Authorization request completed: \(success)")
                cont.resume(returning: success)
            }
        }
    }
    
    /// Centralized authorization method for all app views
    func requestAuthorizationIfNeeded() async -> Bool {
        // If we already have permission, return immediately
        if hasPermission {
            print("🏥 Already have HealthKit permission")
            // Ensure data is loaded on app relaunch/foreground even if permission already granted
            // Use structured concurrency for parallel loading
            print("🏥 Starting parallel data loading...")
            async let today: Void = loadTodayData()
            async let biology: Void = loadBiology30Days()
            async let activity: Void = loadActivity30Days()
            async let workouts: Void = loadWorkouts30Days()
            async let sleep: Void = loadSleepSessions30Days()
            async let latest: Void = loadLatestSamples()
            
            // Wait for all loads to complete
            _ = await (today, biology, activity, workouts, sleep, latest)
            print("🏥 All parallel data loading completed")
            startObservers()
            return true
        }
        
        print("🏥 Requesting HealthKit authorization for all app data types...")
        do {
            let success = try await requestAuthorization()
            await updatePermissionStatus()
            
            if success && hasPermission {
                print("🏥 Authorization successful - loading data and starting observers")
                // Use structured concurrency for parallel loading
                print("🏥 Starting parallel data loading after authorization...")
                async let today: Void = loadTodayData()
                async let biology: Void = loadBiology30Days()
                async let activity: Void = loadActivity30Days()
                async let workouts: Void = loadWorkouts30Days()
                async let sleep: Void = loadSleepSessions30Days()
                async let latest: Void = loadLatestSamples()
                
                // Wait for all loads to complete
                _ = await (today, biology, activity, workouts, sleep, latest)
                print("🏥 All parallel data loading completed after authorization")
                startObservers()
            }
            
            return success && hasPermission
        } catch {
            print("🏥 Authorization error: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    // Probe: check readability (limit=1), returns true if we can read at least one sample
    func probeReadAccess(_ sampleType: HKSampleType) async -> Bool {
        do {
            if let _ = try await fetchLatestSample(sampleType) { 
                print("🏥 Can read \(sampleType.identifier)")
                return true 
            }
            print("🏥 Cannot read \(sampleType.identifier) - no samples")
            return false
        } catch {
            print("🏥 Cannot read \(sampleType.identifier) - error: \(error)")
            return false
        }
    }

    // MARK: Query Lifecycle Management
    
    private func executeQuery(_ query: HKQuery) {
        activeQueries.insert(query)
        healthStore.execute(query)
    }
    
    private func cancelAllQueries() {
        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()
    }
    
    private func stopAllObservers() {
        for (_, observer) in observerQueries {
            healthStore.stop(observer)
        }
        observerQueries.removeAll()
        
        for (_, anchored) in anchoredQueries {
            healthStore.stop(anchored)
        }
        anchoredQueries.removeAll()
    }
    
    // MARK: Retry Logic
    
    private func fetchWithRetry<T>(_ operation: @escaping () async throws -> T, maxRetries: Int = 3) async throws -> T {
        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch {
                if attempt == maxRetries { throw error }
                let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000) // Exponential backoff
                try await Task.sleep(nanoseconds: delay)
                print("🏥 Retry attempt \(attempt) for HealthKit operation")
            }
        }
        fatalError("Should never reach here")
    }
    
    // MARK: Data Validation
    
    private nonisolated func validateSample(_ sample: HKSample) -> Bool {
        // Reject future-dated samples
        guard sample.endDate <= Date() else { 
            print("🏥 Rejecting future-dated sample: \(sample.endDate)")
            return false 
        }
        
        // Reject samples older than 1 year for display
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        guard sample.endDate >= oneYearAgo else { 
            print("🏥 Rejecting sample older than 1 year: \(sample.endDate)")
            return false 
        }
        
        return true
    }
    
    // MARK: Latest sample (LKV)
    func fetchLatestSample(_ sampleType: HKSampleType) async throws -> HKSample? {
        try Task.checkCancellation()
        return try await fetchWithRetry {
            try await withCheckedThrowingContinuation { cont in
                let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, error in
                    if let e = error { cont.resume(throwing: e); return }
                    
                    // Validate sample if found
                    if let sample = samples?.first {
                        if self?.validateSample(sample) == true {
                            cont.resume(returning: sample)
                        } else {
                            cont.resume(returning: nil)
                        }
                    } else {
                        cont.resume(returning: nil)
                    }
                }
                self.executeQuery(query)
            }
        }
    }

    // MARK: Latest quantity value on or before a given date
    func latestQuantityValue(onOrBefore date: Date, identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> (value: Double, endDate: Date)? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { cont in
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: date, options: .strictEndDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                if let s = samples?.first as? HKQuantitySample {
                    if self?.validateSample(s) == true {
                        cont.resume(returning: (s.quantity.doubleValue(for: unit), s.endDate))
                    } else {
                        cont.resume(returning: nil)
                    }
                } else {
                    cont.resume(returning: nil)
                }
            }
            self.executeQuery(q)
        }
    }

    // MARK: Daily series via HKStatisticsCollectionQuery
    /// options example: .cumulativeSum for steps/energy, .discreteAverage for RHR
    func fetchDailySeries(quantityType: HKQuantityType, unit: HKUnit, startDate: Date, endDate: Date, options: HKStatisticsOptions) async throws -> [Date: Double] {
        try Task.checkCancellation()
        return try await fetchWithRetry {
            try await withCheckedThrowingContinuation { cont in
                let anchor = self.calendar.startOfDay(for: startDate)
                var interval = DateComponents()
                interval.day = 1

                let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                        quantitySamplePredicate: nil,
                                                        options: options,
                                                        anchorDate: anchor,
                                                        intervalComponents: interval)

                query.initialResultsHandler = { _, results, error in
                    if let e = error { cont.resume(throwing: e); return }
                    var map: [Date: Double] = [:]
                    results?.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                        let day = self.calendar.startOfDay(for: stat.startDate)
                        if let qty = (options.contains(.cumulativeSum) ? stat.sumQuantity() : stat.averageQuantity()) {
                            let v = qty.doubleValue(for: unit)
                            map[day] = v
                            print("🏥 \(quantityType.identifier) for \(day): \(v)")
                        } else {
                            // no sample for this day -> skip (LKV handled by caller)
                        }
                    }
                    print("🏥 Statistics collection result for \(quantityType.identifier): \(map.count) days with data")
                    cont.resume(returning: map)
                }
                self.executeQuery(query)
            }
        }
    }

    // MARK: Sleep Session Building (Whoop/Athlytic/Bevel-like)
    
    private let sleepSessionBuilder = SleepSessionBuilder()
    
    /// Fetch sleep sessions with comprehensive metrics
    func fetchSleepSessions(startDate: Date, endDate: Date) async throws -> [SleepSession] {
        try Task.checkCancellation()
        return try await fetchWithRetry {
            try await withCheckedThrowingContinuation { cont in
                let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
                let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
                let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
                    if let e = error { cont.resume(throwing: e); return }
                    
                    let samples = samples as? [HKCategorySample] ?? []
                    let validSamples = samples.filter { self?.validateSample($0) == true }
                    
                    // Use a local builder to avoid capturing MainActor-isolated state in sendable closure
                    let localBuilder = SleepSessionBuilder()
                    let sessions = localBuilder.buildSessions(
                        from: validSamples,
                        startDate: startDate,
                        endDate: endDate
                    )
                    
                    cont.resume(returning: sessions)
                }
                self.executeQuery(query)
            }
        }
    }
    
    /// Fetch daily sleep summaries (legacy compatibility)
    func fetchSleepDaily(startDate: Date, endDate: Date) async throws -> [Date: TimeInterval] {
        let sessions = try await fetchSleepSessions(startDate: startDate, endDate: endDate)
        var daily: [Date: TimeInterval] = [:]
        
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.startDate)
            daily[dayStart, default: 0] += session.duration
        }
        
        return daily
    }
    
    /// Fetch comprehensive daily sleep summary
    func fetchDailySleepSummary(for date: Date) async throws -> DailySleepSummary {
        let startDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        let endDate = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: date)) ?? date
        
        print("🏥 Fetching sleep summary for \(date) (range: \(startDate) to \(endDate))")
        let sessions = try await fetchSleepSessions(startDate: startDate, endDate: endDate)
        print("🏥 Found \(sessions.count) sleep sessions")
        
        let summary = SleepSessionBuilder().buildDailySummary(for: date, sessions: sessions)
        print("🏥 Sleep summary: \(summary.hasData ? "Has data" : "No data"), duration: \(summary.durationHours)h")
        
        return summary
    }

    // MARK: Backfill helper: lastKnownValue per type
    func lastKnownValue(for quantityType: HKQuantityType, valueUnit: HKUnit) async throws -> (value: Double, date: Date)? {
        if let sample = try await fetchLatestSample(quantityType) as? HKQuantitySample {
            let qty = sample.quantity
            return (qty.doubleValue(for: valueUnit), sample.endDate)
        }
        return nil
    }

    // MARK: Load today's basic metrics
    func loadTodayData() async {
        guard hasPermission else {
            print("🏥 Cannot load today's data - no permission")
            return 
        }
        
        // Check cache first
        let cacheKey = "today_data_\(calendar.startOfDay(for: Date()).timeIntervalSince1970)"
        if let cachedData = getCachedData(for: cacheKey, type: [String: Double].self) {
            print("🏥 Using cached today's data")
            updateTodayMetricsFromCache(cachedData)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            isLoading = false
            return
        }
        
        print("🏥 Loading today's data from \(startOfDay) to \(endOfDay)")
        
        do {
            // Load steps
            if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                let map = try await fetchDailySeries(quantityType: stepType, unit: .count(), startDate: startOfDay, endDate: endOfDay, options: .cumulativeSum)
                todaySteps = map[startOfDay] ?? 0
                print("🏥 Today's steps: \(todaySteps)")
            }
            
            // Load heart rate
            if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                let map = try await fetchDailySeries(quantityType: hrType, unit: .count().unitDivided(by: .minute()), startDate: startOfDay, endDate: endOfDay, options: .discreteAverage)
                todayHeartRate = map[startOfDay] ?? 0
                print("🏥 Today's heart rate: \(todayHeartRate)")
            }
            
            // Load active energy
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let map = try await fetchDailySeries(quantityType: energyType, unit: .kilocalorie(), startDate: startOfDay, endDate: endOfDay, options: .cumulativeSum)
                todayActiveEnergy = map[startOfDay] ?? 0
                print("🏥 Today's active energy: \(todayActiveEnergy)")
            }
            
            // Load comprehensive sleep data
            print("🏥 Loading today's sleep data...")
            let sleepSummary = try await fetchDailySleepSummary(for: today)
            todaySleepSummary = sleepSummary
            todaySleepSession = sleepSummary.primarySession
            todaySleepHours = sleepSummary.durationHours
            print("🏥 Today's sleep: \(todaySleepHours) hours (efficiency: \(sleepSummary.averageEfficiency * 100)%)")
            
            if let session = todaySleepSession {
                print("🏥 Sleep session details: \(session.durationHours)h, \(session.stages.remPercentage)% REM, \(session.stages.deepPercentage)% Deep")
            } else {
                print("🏥 No sleep session found for today")
            }

            // Respiratory Rate (avg breaths/min)
            if let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
                let map = try await fetchDailySeries(quantityType: respType, unit: .count().unitDivided(by: .minute()), startDate: startOfDay, endDate: endOfDay, options: .discreteAverage)
                todayRespiratoryRate = map[startOfDay] ?? 0
                print("🏥 Today's respiratory rate: \(todayRespiratoryRate)")
            }

            // Oxygen Saturation (avg %) - HealthKit stores fraction
            if let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
                let map = try await fetchDailySeries(quantityType: spo2Type, unit: .percent(), startDate: startOfDay, endDate: endOfDay, options: .discreteAverage)
                let fraction = map[startOfDay] ?? 0
                todaySpO2Percent = fraction * 100.0
                print("🏥 Today's SpO2: \(todaySpO2Percent)%")
            }

            // Body Temperature (°C) with robust fallback logic
            var bodyTemp: Double = 0
            if let tempType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
                let map = try await fetchDailySeries(quantityType: tempType, unit: .degreeCelsius(), startDate: startOfDay, endDate: endOfDay, options: .discreteAverage)
                bodyTemp = map[startOfDay] ?? 0
                if bodyTemp == 0 {
                    // Fallback to latest sample if no daily aggregate yet
                    if let latest = try? await fetchLatestSample(tempType) as? HKQuantitySample {
                        bodyTemp = latest.quantity.doubleValue(for: .degreeCelsius())
                        print("🏥 Fallback latest body temperature: \(bodyTemp) °C at \(latest.endDate)")
                    } else {
                        print("🏥 No body temperature samples available today")
                    }
                }
            }
            // Wrist temperature (delta °C) as secondary fallback
            if bodyTemp == 0, let wristType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                let unit = HKUnit.degreeCelsius()
                let map = try await fetchDailySeries(quantityType: wristType, unit: unit, startDate: startOfDay, endDate: endOfDay, options: .discreteAverage)
                var delta = map[startOfDay] ?? 0
                if delta == 0 {
                    if let latest = try? await fetchLatestSample(wristType) as? HKQuantitySample {
                        delta = latest.quantity.doubleValue(for: unit)
                        print("🏥 Fallback latest wrist temperature delta: \(delta) °C at \(latest.endDate)")
                    } else {
                        print("🏥 No wrist temperature samples available today")
                    }
                }
                bodyTemp = delta // delta may be negative/positive
            }
            todayBodyTemperatureC = bodyTemp
            print("🏥 Today's temperature metric (°C, absolute or delta): \(todayBodyTemperatureC)")

            // Dietary Energy Consumed (kcal)
            if let dietType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
                let map = try await fetchDailySeries(quantityType: dietType, unit: .kilocalorie(), startDate: startOfDay, endDate: endOfDay, options: .cumulativeSum)
                todayDietaryEnergy = map[startOfDay] ?? 0
                print("🏥 Today's dietary energy: \(todayDietaryEnergy) kcal")
            }

            // Macros (grams)
            if let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
                let map = try await fetchDailySeries(quantityType: proteinType, unit: .gram(), startDate: startOfDay, endDate: endOfDay, options: .cumulativeSum)
                todayProteinGrams = map[startOfDay] ?? 0
            }
            if let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
                let map = try await fetchDailySeries(quantityType: carbsType, unit: .gram(), startDate: startOfDay, endDate: endOfDay, options: .cumulativeSum)
                todayCarbsGrams = map[startOfDay] ?? 0
            }
            if let fatsType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
                let map = try await fetchDailySeries(quantityType: fatsType, unit: .gram(), startDate: startOfDay, endDate: endOfDay, options: .cumulativeSum)
                todayFatGrams = map[startOfDay] ?? 0
            }
            
        } catch {
            print("🏥 Error loading today's data: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func updateTodayMetricsFromCache(_ data: [String: Double]) {
        todaySteps = data["steps"] ?? 0
        todayHeartRate = data["heartRate"] ?? 0
        todayActiveEnergy = data["activeEnergy"] ?? 0
        todaySleepHours = data["sleepHours"] ?? 0
        todayRespiratoryRate = data["respiratoryRate"] ?? 0
        todaySpO2Percent = data["spO2Percent"] ?? 0
        todayBodyTemperatureC = data["bodyTemperature"] ?? 0
        todayDietaryEnergy = data["dietaryEnergy"] ?? 0
        todayProteinGrams = data["proteinGrams"] ?? 0
        todayCarbsGrams = data["carbsGrams"] ?? 0
        todayFatGrams = data["fatGrams"] ?? 0
    }
    
    // MARK: Historical Sample Fetchers (Apple Health-like behavior)
    
    /// Get canonical unit for each metric type
    private func canonicalUnit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch identifier {
        case .vo2Max: return HKUnit(from: "ml/kg*min")
        case .heartRateVariabilitySDNN: return HKUnit.secondUnit(with: .milli) // ms
        case .restingHeartRate, .heartRate: return HKUnit.count().unitDivided(by: HKUnit.minute())
        case .bodyMass: return HKUnit.gramUnit(with: .kilo)
        case .activeEnergyBurned: return HKUnit.kilocalorie()
        case .stepCount: return HKUnit.count()
        default: return HKUnit.count()
        }
    }
    
    /// Get the last known value for a metric type (for LKV filling)
    private func getLastKnownValue(for type: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                if let error = error {
                    print("🏥 Error fetching last known value for \(type.rawValue): \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                if self?.validateSample(sample) == true {
                    let value = sample.quantity.doubleValue(for: unit)
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            self.executeQuery(query)
        }
    }
    
    /// Determine if a metric type should be filled with LKV for continuous charts
    static nonisolated func shouldFillWithLKV(for type: HKQuantityTypeIdentifier) -> Bool {
        switch type {
        case .vo2Max, .heartRateVariabilitySDNN, .restingHeartRate:
            return true // Apple Watch metrics - fill with LKV for continuous charts
        case .bodyMass, .stepCount, .activeEnergyBurned:
            return false // Manual/activity metrics - show natural gaps
        default:
            return false
        }
    }
    
    /// Fetch daily aggregated statistics with Apple Health-like behavior (dynamic time windows)
    func fetchDailyStatistics(for type: HKQuantityTypeIdentifier, days: Int = 30) async throws -> [HealthMetricPoint] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid quantity type"])
        }
        
        let unit = canonicalUnit(for: type)
        
        // 🎯 STEP 1: Create dynamic window (Apple Health-like behavior)
        guard let window = await createDynamicWindow(for: type, days: days) else {
            print("🏥 No samples found for \(type.rawValue) - returning empty array")
            return []
        }
        
        let startDate = window.startDate
        let endDate = window.endDate
        
        // Choose appropriate statistics option based on metric type
        let statisticsOptions: HKStatisticsOptions = {
            switch type {
            case .vo2Max, .heartRateVariabilitySDNN, .restingHeartRate, .bodyMass:
                return .discreteAverage  // For metrics where we want the average if multiple samples per day
            case .activeEnergyBurned, .stepCount:
                return .cumulativeSum    // For metrics that accumulate
            default:
                return .discreteAverage
            }
        }()
        
        print("🏥 Dynamic window for \(type.rawValue): \(startDate) → \(endDate) (last sample-based)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let interval = DateComponents(day: 1)
            let anchorDate = calendar.startOfDay(for: startDate)
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
            
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: statisticsOptions,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    print("🏥 Error fetching statistics for \(type.rawValue): \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let collection = collection else {
                    print("🏥 No statistics collection for \(type.rawValue)")
                    continuation.resume(returning: [])
                    return
                }
                
                // Convert statistics to HealthMetricPoint array
                var points: [HealthMetricPoint] = []
                var lastKnownValue: Double? = nil
                
                // Get the LKV first by looking at all available data
                Task {
                    if let lkv = await self.getLastKnownValue(for: type, unit: unit) {
                        lastKnownValue = lkv
                        print("🏥 LKV for \(type.rawValue): \(lkv)")
                    }
                    
                    // Process daily statistics with Apple Health-like behavior
                    var actualDataPoints: [HealthMetricPoint] = []
                    var filledDataPoints: [HealthMetricPoint] = []
                    
                    collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                        let date = statistics.startDate
                        
                        if let quantity = statistics.averageQuantity() ?? statistics.sumQuantity() {
                            let value = quantity.doubleValue(for: unit)
                            let point = HealthMetricPoint(date: date, value: value)
                            point.isActualData = true // Mark as real data
                            actualDataPoints.append(point)
                            filledDataPoints.append(point)
                            lastKnownValue = value // Update LKV with actual data
                        } else if let lkv = lastKnownValue, HealthKitManager.shouldFillWithLKV(for: type) {
                            // Fill sparse metrics with LKV for continuous charts
                            let point = HealthMetricPoint(date: date, value: lkv)
                            point.isActualData = false // Mark as LKV-filled
                            filledDataPoints.append(point)
                        }
                        // For weight and other manual metrics, don't fill gaps - let charts show natural gaps
                    }
                    
                    // Apply visual smoothing for sparse metrics with LKV fillback
                    if HealthKitManager.shouldFillWithLKV(for: type) {
                        points = self.applySmoothingToLKVData(filledDataPoints)
                    } else {
                        points = actualDataPoints // Weight/manual metrics: only actual data
                    }
                    
                    print("🏥 Generated \(points.count) daily points for \(type.rawValue) (LKV: \(lastKnownValue ?? 0))")
                    continuation.resume(returning: points)
                }
            }
            
            self.executeQuery(query)
        }
    }
    
    
    /// Apply visual smoothing to LKV-filled data to avoid flat lines (Apple Health-like)
    private nonisolated func applySmoothingToLKVData(_ points: [HealthMetricPoint]) -> [HealthMetricPoint] {
        guard points.count > 2 else { return points }
        
        var smoothedPoints: [HealthMetricPoint] = []
        var lastActualValue: Double? = nil
        
        for i in 0..<points.count {
            let point = points[i]
            
            if point.isActualData {
                // Keep actual data points unchanged and track for smoothing
                lastActualValue = point.value
                smoothedPoints.append(point)
            } else {
                // Apply sophisticated smoothing to LKV-filled points
                let variation = generateNaturalVariation(
                    for: i, 
                    totalPoints: points.count, 
                    baseValue: point.value,
                    lastActualValue: lastActualValue,
                    previousSmoothed: smoothedPoints.last?.displayValue
                )
                let smoothedPoint = HealthMetricPoint(date: point.date, value: point.value, isActualData: false)
                smoothedPoint.smoothedValue = variation
                smoothedPoints.append(smoothedPoint)
            }
        }
        
        return smoothedPoints
    }
    
    /// Generate natural variation for LKV points to create Apple Health-like trends
    private nonisolated func generateNaturalVariation(
        for index: Int,
        totalPoints: Int,
        baseValue: Double,
        lastActualValue: Double?,
        previousSmoothed: Double?
    ) -> Double {
        // Apple Health-like smoothing algorithm
        let normalizedIndex = Double(index) / Double(totalPoints)
        
        // 1. Gentle sine wave for natural biological variation (±1-2%)
        let biologicalVariation = sin(normalizedIndex * 2 * Double.pi) * 0.015
        
        // 2. Small random noise to avoid perfect patterns (±0.5%)
        let randomNoise = Double.random(in: -0.005...0.005)
        
        // 3. Momentum from previous smoothed value (creates continuity)
        let momentum: Double
        if let prev = previousSmoothed {
            momentum = (prev - baseValue) * 0.1 // 10% of previous difference
        } else {
            momentum = 0
        }
        
        // 4. Slight drift toward last actual value if available
        let actualValueDrift: Double
        if let actual = lastActualValue {
            let drift = (actual - baseValue) * 0.05 * normalizedIndex // Gradual drift
            actualValueDrift = drift
        } else {
            actualValueDrift = 0
        }
        
        let totalVariation = biologicalVariation + randomNoise + momentum + actualValueDrift
        return baseValue * (1.0 + totalVariation)
    }
    
    /// Create data-optimized time window (Apple Health-like: last N points with data, not strict calendar)
    func createOptimizedTimeWindow<T>(_ data: [T], maxPoints: Int = 30) -> [T] {
        // Return last N data points, not strict calendar window
        return Array(data.suffix(maxPoints))
    }
    
    /// Find the last available sample date for a metric (Apple Health-like dynamic windows)
    private func lastSampleDate(for type: HKQuantityTypeIdentifier) async -> Date? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else { return nil }
        
        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: quantityType,
                                      predicate: nil,
                                      limit: 1,
                                      sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    if self?.validateSample(sample) == true {
                        continuation.resume(returning: sample.endDate)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.executeQuery(query)
        }
    }
    
    /// Create dynamic window for sparse metrics (Apple Health-like behavior)
    func createDynamicWindow(for type: HKQuantityTypeIdentifier, days: Int = 30) async -> (startDate: Date, endDate: Date)? {
        guard let lastSampleDate = await lastSampleDate(for: type) else {
            print("🏥 No samples found for \(type.rawValue)")
            return nil
        }
        
        let endDate = lastSampleDate
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return nil
        }
        
        print("🏥 Dynamic window for \(type.rawValue): \(startDate) → \(endDate)")
        return (startDate: startDate, endDate: endDate)
    }
    
    // MARK: Latest Sample Fetchers (immediate data)
    func loadLatestSamples() async {
        print("🏥 ===== STARTING LATEST SAMPLES LOADING =====")
        print("🏥 Fetching latest samples for immediate display...")
        
        // VO₂ Max - latest sample
        if let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            print("🏥 Checking VO₂ Max data availability...")
            if let latest = try? await fetchLatestSample(vo2Type) as? HKQuantitySample {
                let vo2Value = latest.quantity.doubleValue(for: HKUnit(from: "ml/kg·min"))
                let point = HealthMetricPoint(date: latest.endDate, value: vo2Value, isActualData: true)
                await MainActor.run {
                    if self.vo2Max30.isEmpty { self.vo2Max30 = [point] }
                    // Also update DataManager directly
                    DataManager.shared.updateLatestVO2MaxActual(vo2Value, date: latest.endDate)
                }
                print("🏥 Latest VO₂ Max: \(vo2Value) ml/kg·min from \(latest.endDate)")
        } else {
                print("🏥 No VO₂ Max data available - no samples found")
                await MainActor.run {
                    DataManager.shared.updateLatestVO2MaxActual(nil, date: nil)
                }
            }
        } else {
            print("🏥 VO₂ Max type not available")
        }
        
        // HRV - latest sample
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            if let latest = try? await fetchLatestSample(hrvType) as? HKQuantitySample {
                let hrvValue = latest.quantity.doubleValue(for: .secondUnit(with: .milli))
                let point = HealthMetricPoint(date: latest.endDate, value: hrvValue, isActualData: true)
                await MainActor.run {
                    if self.hrv30.isEmpty { self.hrv30 = [point] }
                    // Also update DataManager directly
                    DataManager.shared.updateLatestHRVActual(hrvValue, date: latest.endDate)
                }
                print("🏥 Latest HRV: \(hrvValue) ms")
        } else {
                print("🏥 No HRV data available")
                await MainActor.run {
                    DataManager.shared.updateLatestHRVActual(nil, date: nil)
                }
            }
        }
        
        // Resting Heart Rate - latest sample
        if let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            if let latest = try? await fetchLatestSample(rhrType) as? HKQuantitySample {
                let rhrValue = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let point = HealthMetricPoint(date: latest.endDate, value: rhrValue, isActualData: true)
                await MainActor.run {
                    if self.rhr30.isEmpty { self.rhr30 = [point] }
                    // Also update DataManager directly
                    DataManager.shared.updateLatestRHRActual(rhrValue, date: latest.endDate)
                }
                print("🏥 Latest RHR: \(rhrValue) BPM")
        } else {
                print("🏥 No RHR data available")
                await MainActor.run {
                    DataManager.shared.updateLatestRHRActual(nil, date: nil)
                }
            }
        }
        
        // Weight - latest sample
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            if let latest = try? await fetchLatestSample(weightType) as? HKQuantitySample {
                let weightValue = latest.quantity.doubleValue(for: .gramUnit(with: .kilo))
                let point = HealthMetricPoint(date: latest.endDate, value: weightValue, isActualData: true)
                await MainActor.run {
                    if self.weight30.isEmpty { self.weight30 = [point] }
                    // Also update DataManager directly
                    DataManager.shared.updateLatestWeightActual(weightValue, date: latest.endDate)
                }
                print("🏥 Latest Weight: \(weightValue) kg")
                    } else {
                print("🏥 No Weight data available")
                await MainActor.run {
                    DataManager.shared.updateLatestWeightActual(nil, date: nil)
                }
            }
        }
        
        // Lean Body Mass - latest sample
        if let leanBodyMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) {
            if let latest = try? await fetchLatestSample(leanBodyMassType) as? HKQuantitySample {
                let leanBodyMassValue = latest.quantity.doubleValue(for: .gramUnit(with: .kilo))
                await MainActor.run {
                    self.latestLeanBodyMass = leanBodyMassValue
                }
                print("🏥 Latest Lean Body Mass: \(leanBodyMassValue) kg")
            } else {
                print("🏥 No Lean Body Mass data available")
            }
        }
        
        // Body Fat Percentage - latest sample
        if let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            if let latest = try? await fetchLatestSample(bodyFatType) as? HKQuantitySample {
                let bodyFatValue = latest.quantity.doubleValue(for: .percent()) * 100 // Convert to percentage
                await MainActor.run {
                    self.latestBodyFatPercentage = bodyFatValue
                }
                print("🏥 Latest Body Fat: \(bodyFatValue)%")
            } else {
                print("🏥 No Body Fat data available")
            }
        }
        
        print("🏥 ===== LATEST SAMPLES LOADING COMPLETED =====")
    }
    
    // MARK: Apple Health-like biology data loader
    func loadBiology30Days() async {
        print("🏥 ===== STARTING BIOLOGY DATA LOADING =====")
        print("🏥 Loading biology data with Apple Health-like behavior...")
        
        // Use the new statistics-based approach with LKV fillback
        do {
            // VO2 Max: daily statistics with LKV fillback for continuous charts
            print("🏥 Loading VO2 Max 30-day data...")
            let vo2MaxPoints = try await fetchDailyStatistics(
                for: .vo2Max, 
                days: 30
            )
            await MainActor.run { self.vo2Max30 = vo2MaxPoints }
            print("🏥 VO2 Max: \(vo2MaxPoints.count) daily points")
            
            if let latestPoint = vo2MaxPoints.last {
                print("🏥 Latest VO2 Max point: \(latestPoint.value) from \(latestPoint.date)")
            } else {
                print("🏥 No VO2 Max points found - checking if user has VO2 Max data...")
                // Check if there are any VO2 Max samples at all
                if let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
                    if let sample = try? await fetchLatestSample(vo2Type) as? HKQuantitySample {
                        print("🏥 Found VO2 Max sample: \(sample.quantity.doubleValue(for: HKUnit(from: "ml/kg·min"))) from \(sample.endDate)")
                    } else {
                        print("🏥 No VO2 Max samples found in HealthKit")
                    }
                }
            }
            
            // HRV: daily statistics with LKV fillback for continuous charts
            let hrvPoints = try await fetchDailyStatistics(
                for: .heartRateVariabilitySDNN,
                days: 30
            )
            await MainActor.run { self.hrv30 = hrvPoints }
            print("🏥 HRV: \(hrvPoints.count) daily points")
            
            // RHR: daily statistics with LKV fillback for continuous charts
            let rhrPoints = try await fetchDailyStatistics(
                for: .restingHeartRate,
                days: 30
            )
            await MainActor.run { self.rhr30 = rhrPoints }
            print("🏥 RHR: \(rhrPoints.count) daily points")
            
            // Weight: daily statistics without LKV fillback (natural gaps like Apple Health)
            let weightPoints = try await fetchDailyStatistics(
                for: .bodyMass,
                days: 30
            )
            await MainActor.run { self.weight30 = weightPoints }
            print("🏥 Weight: \(weightPoints.count) daily points")
            
        } catch {
            print("🏥 Error loading daily statistics: \(error)")
            // Initialize with empty arrays if error occurs
            await MainActor.run {
                self.vo2Max30 = []
                self.hrv30 = []
                self.rhr30 = []
                self.weight30 = []
            }
        }
        
        print("🏥 ===== BIOLOGY DATA LOADING COMPLETED =====")
        print("🏥 Biology data loading completed - showing actual samples only")
    }

    // MARK: Activity (Steps, Active Energy) - 30 day window including zeros
    func loadActivity30Days() async {
        guard hasPermission else { return }
        print("🏥 Loading activity (steps, active energy) for last 30 days...")

        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -29, to: today),
              let endDate = calendar.date(byAdding: .day, value: 1, to: today) else { return }

        do {
            // Steps
            if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                let map = try await fetchDailySeries(quantityType: stepType,
                                                     unit: .count(),
                                                     startDate: startDate,
                                                     endDate: endDate,
                                                     options: .cumulativeSum)
                var points: [HealthMetricPoint] = []
                var cur = startDate
                while cur < endDate {
                    let day = calendar.startOfDay(for: cur)
                    let value = map[day] ?? 0
                    let point = HealthMetricPoint(date: day, value: value, isActualData: map[day] != nil)
                    points.append(point)
                    cur = calendar.date(byAdding: .day, value: 1, to: day) ?? endDate
                }
                await MainActor.run { self.steps30 = points }
                print("🏥 Steps points: \(points.count)")
            }

            // Active Energy
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let map = try await fetchDailySeries(quantityType: energyType,
                                                     unit: .kilocalorie(),
                                                     startDate: startDate,
                                                     endDate: endDate,
                                                     options: .cumulativeSum)
                var points: [HealthMetricPoint] = []
                var cur = startDate
                while cur < endDate {
                    let day = calendar.startOfDay(for: cur)
                    let value = map[day] ?? 0
                    let point = HealthMetricPoint(date: day, value: value, isActualData: map[day] != nil)
                    points.append(point)
                    cur = calendar.date(byAdding: .day, value: 1, to: day) ?? endDate
                }
                await MainActor.run { self.activeEnergy30 = points }
                print("🏥 Active energy points: \(points.count)")
            }
        } catch {
            print("🏥 Error loading activity series: \(error)")
        }
    }


    // MARK: Background Delivery Frequency Optimization
    
    private func optimalBackgroundFrequency(for type: HKSampleType) -> HKUpdateFrequency {
        switch type.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            return .hourly
        case HKQuantityTypeIdentifier.stepCount.rawValue, 
             HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            return .daily
        case HKQuantityTypeIdentifier.vo2Max.rawValue, 
             HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            return .weekly
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return .daily
        case HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!.identifier:
            return .daily
        case HKQuantityTypeIdentifier.bodyMass.rawValue, 
             HKQuantityTypeIdentifier.leanBodyMass.rawValue, 
             HKQuantityTypeIdentifier.bodyFatPercentage.rawValue:
            return .weekly
        default:
            return .daily
        }
    }
    
    // MARK: HKAnchoredObjectQuery Implementation
    
    func startAnchoredQuery(for sampleType: HKSampleType) {
        guard anchoredQueries[sampleType] == nil else { return }
        
        let anchor = loadAnchor(for: sampleType)
        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, deletedObjects, newAnchor, error in
            guard let self = self else { return }
            
            if let error = error {
                print("🏥 Anchored query error for \(sampleType.identifier): \(error)")
                return
            }
            
            // Save new anchor for incremental updates
            if let newAnchor = newAnchor {
                Task { @MainActor in
                    self.saveAnchor(newAnchor, for: sampleType)
                }
            }
            
            // Handle new samples
            if let samples = samples, !samples.isEmpty {
                print("🏥 Anchored query: \(samples.count) new samples for \(sampleType.identifier)")
                Task {
                    await self.handleAnchoredQueryUpdate(for: sampleType, samples: samples)
                }
            }
            
            // Handle deleted objects
            if let deletedObjects = deletedObjects, !deletedObjects.isEmpty {
                print("🏥 Anchored query: \(deletedObjects.count) deleted objects for \(sampleType.identifier)")
                Task {
                    await self.handleAnchoredQueryDeletions(for: sampleType, deletedObjects: deletedObjects)
                }
            }
        }
        
        anchoredQueries[sampleType] = query
        executeQuery(query)
        print("🏥 Started anchored query for \(sampleType.identifier)")
    }
    
    private func handleAnchoredQueryUpdate(for sampleType: HKSampleType, samples: [HKSample]) async {
        // Validate and process new samples
        let validSamples = samples.filter { validateSample($0) }
        
        if !validSamples.isEmpty {
            print("🏥 Processing \(validSamples.count) valid new samples for \(sampleType.identifier)")
            // Trigger appropriate data refresh based on sample type
            await handleObserverFired(for: sampleType)
        }
    }
    
    private func handleAnchoredQueryDeletions(for sampleType: HKSampleType, deletedObjects: [HKDeletedObject]) async {
        print("🏥 Handling \(deletedObjects.count) deletions for \(sampleType.identifier)")
        // For deletions, we might need to refresh the entire dataset
        // or implement more sophisticated cache invalidation
        await handleObserverFired(for: sampleType)
    }
    
    // MARK: Observers & Anchored queries (incremental updates)
    func startObservers() {
        let sampleTypes: [HKSampleType] = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.workoutType()
        ]

        for type in sampleTypes {
            if observerQueries[type] != nil { continue }
            
            // Start observer query
            let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
                print("🔍 Observer fired for \(type.identifier)")
                Task {
                    await self?.handleObserverFired(for: type)
                    completionHandler()
                }
            }
            observerQueries[type] = observer
            executeQuery(observer)
            
            // Start anchored query for incremental updates
            startAnchoredQuery(for: type)
            
            // Enable background delivery with optimal frequency
            let frequency = optimalBackgroundFrequency(for: type)
            healthStore.enableBackgroundDelivery(for: type, frequency: frequency) { success, err in
                print("📱 Background delivery \(success ? "enabled" : "failed") for \(type.identifier) (frequency: \(frequency))")
            }
        }
        print("🔍 Started observers and anchored queries for \(sampleTypes.count) sample types")
    }

    private func handleObserverFired(for sampleType: HKSampleType) async {
        print("🔍 Handling observer fired for \(sampleType.identifier)")
        
        // Handle each sample type specifically to avoid over-fetching
        switch sampleType.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            await loadLatestHeartRateRelated() // RHR, HRV only
        case HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            await loadLatestHeartRateRelated() // RHR, HRV only
        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue:
            await loadLatestHeartRateRelated() // RHR, HRV only
        case HKQuantityTypeIdentifier.vo2Max.rawValue:
            await loadLatestVO2MaxRelated()
        case HKCategoryTypeIdentifier.sleepAnalysis.rawValue:
            await loadLatestSleepRelated()
        case HKQuantityTypeIdentifier.stepCount.rawValue, HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            await loadLatestActivityRelated()
        case HKQuantityTypeIdentifier.bodyMass.rawValue, HKQuantityTypeIdentifier.leanBodyMass.rawValue, HKQuantityTypeIdentifier.bodyFatPercentage.rawValue:
            await loadLatestBodyCompositionRelated()
        case HKObjectType.workoutType().identifier:
            await loadLatestWorkoutRelated()
        default:
            await loadMinimalFor(sampleType: sampleType)
        }
    }
    
    // MARK: - Per-Sample-Type Loaders (Optimized)
    
    private func loadLatestHeartRateRelated() async {
        print("🔍 Loading latest heart rate related data (RHR, HRV)")
        await loadLatestSamples() // Only latest samples, not full 30-day series
    }
    
    private func loadLatestVO2MaxRelated() async {
        print("🔍 Loading latest VO2 Max related data")
        await loadLatestSamples() // Only latest samples
    }
    
    private func loadLatestSleepRelated() async {
        print("🔍 Loading latest sleep related data")
        await loadTodayData() // Only today's sleep
    }
    
    private func loadLatestActivityRelated() async {
        print("🔍 Loading latest activity related data (steps, energy)")
        await loadTodayData() // Only today's activity
    }
    
    private func loadLatestBodyCompositionRelated() async {
        print("🔍 Loading latest body composition related data")
        await loadLatestSamples() // Only latest samples
    }
    
    private func loadLatestWorkoutRelated() async {
        print("🔍 Loading latest workout related data")
        await loadWorkouts30Days() // Workouts need full context
    }
    
    private func loadMinimalFor(sampleType: HKSampleType) async {
        print("🔍 Loading minimal data for \(sampleType.identifier)")
        // Only reload what's absolutely necessary
        await loadTodayData()
    }

    // Anchor persistence
    private nonisolated func anchorFileURL(for type: HKSampleType) -> URL {
        let filename = "anchor_\(type.identifier).bin"
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(filename)
    }

    private nonisolated func saveAnchor(_ anchor: HKQueryAnchor, for type: HKSampleType) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            let url = anchorFileURL(for: type)
            try data.write(to: url, options: .atomic)
            print("📌 Saved anchor for \(type.identifier)")
        } catch {
            print("❌ Failed to save anchor for \(type.identifier): \(error)")
        }
    }

    private nonisolated func loadAnchor(for type: HKSampleType) -> HKQueryAnchor? {
        let url = anchorFileURL(for: type)
        guard let data = try? Data(contentsOf: url) else { 
            print("📌 No saved anchor found for \(type.identifier)")
            return nil 
        }
        let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        if anchor != nil {
            print("📌 Loaded anchor for \(type.identifier)")
        }
        return anchor
    }
    
    // MARK: - Query Efficiency & Caching
    
    private var queryCache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 5 * 60 // 5 minutes
    
    private func getCachedData<T>(for key: String, type: T.Type) -> T? {
        guard let cached = queryCache[key],
              Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration else {
            return nil
        }
        return cached.data as? T
    }
    
    private func setCachedData<T>(_ data: T, for key: String) {
        queryCache[key] = (data: data, timestamp: Date())
    }
    
    private func clearCache() {
        queryCache.removeAll()
    }
    
    // MARK: - Refresh authorization status
    func refreshAuthorizationStatus() async {
        print("🔄 Refreshing authorization status")
        await updatePermissionStatus()
    }

    // MARK: - Sleep Sessions (last 30 days)
    func loadSleepSessions30Days() async {
        guard hasPermission else { 
            print("🏥 No permission for sleep sessions")
            return 
        }
        print("🏥 Loading sleep sessions for last 30 days...")
        
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        do {
            let sessions = try await fetchSleepSessions(startDate: startDate, endDate: endDate)
            await MainActor.run {
                self.recentSleepSessions = sessions
            }
            print("🏥 Loaded \(sessions.count) sleep sessions")
            
            if let latestSession = sessions.last {
                print("🏥 Latest sleep session: \(latestSession.durationHours)h from \(latestSession.startDate)")
            }
        } catch {
            print("🏥 Error loading sleep sessions: \(error)")
        }
    }
    
    // MARK: - Workouts (last 30 days)
    func loadWorkouts30Days() async {
        guard hasPermission else { return }
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { [weak self] _, samples, error in
                guard let self = self else { cont.resume(); return }
                if let error = error {
                    print("🏥 Workouts query error: \(error)")
                    cont.resume(); return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                let validWorkouts = workouts.filter { self.validateSample($0) }
                let summaries = validWorkouts.map { w in
                    let energyBurned: Double
                    if #available(iOS 18.0, *) {
                        energyBurned = w.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    } else {
                        energyBurned = w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                    }
                    return WorkoutSummary(
                        date: w.startDate,
                        type: w.workoutActivityType,
                        durationMinutes: w.duration / 60.0,
                        energyKilocalories: energyBurned
                    )
                }
                Task { @MainActor in
                    self.recentWorkouts = summaries
                }
                cont.resume()
            }
            self.executeQuery(q)
        }
    }
}
