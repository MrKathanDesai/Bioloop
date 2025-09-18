import Foundation
import HealthKit
import Combine

// Simple DTO for UI
public struct HealthMetricPoint: Codable, Identifiable {
    public let date: Date
    public let value: Double
    
    public var id: Date { date }
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
    
    // Basic metrics for HomeView
    @Published var todaySteps: Double = 0
    @Published var todayHeartRate: Double = 0
    @Published var todayActiveEnergy: Double = 0
    @Published var todaySleepHours: Double = 0

    // Authorization state
    @Published var hasPermission = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    // keep references
    private var observerQueries: [HKSampleType: HKObserverQuery] = [:]
    private var anchoredQueries: [HKSampleType: HKAnchoredObjectQuery] = [:]
    
    private init() {
        checkInitialPermission()
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
            HKQuantityType.quantityType(forIdentifier: .leanBodyMass)
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
            return true
        }
        
        print("🏥 Requesting HealthKit authorization for all app data types...")
        do {
            let success = try await requestAuthorization()
            await updatePermissionStatus()
            
            if success && hasPermission {
                print("🏥 Authorization successful - loading data and starting observers")
                await loadTodayData()
                await loadBiology30Days()
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

    // MARK: Latest sample (LKV)
    func fetchLatestSample(_ sampleType: HKSampleType) async throws -> HKSample? {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let e = error { cont.resume(throwing: e); return }
                cont.resume(returning: samples?.first)
            }
            healthStore.execute(query)
        }
    }

    // MARK: Daily series via HKStatisticsCollectionQuery
    /// options example: .cumulativeSum for steps/energy, .discreteAverage for RHR
    func fetchDailySeries(quantityType: HKQuantityType, unit: HKUnit, startDate: Date, endDate: Date, options: HKStatisticsOptions) async throws -> [Date: Double] {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { cont in
            let anchor = calendar.startOfDay(for: startDate)
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
            self.healthStore.execute(query)
        }
    }

    // MARK: Sleep (HKCategorySample) aggregation per day — returns seconds per day
    func fetchSleepDaily(startDate: Date, endDate: Date) async throws -> [Date: TimeInterval] {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { cont in
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let e = error { cont.resume(throwing: e); return }
                var daily: [Date: TimeInterval] = [:]
                let samples = samples as? [HKCategorySample] ?? []
                for s in samples {
                    // consider only "asleep"
                    if s.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                       s.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       s.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       s.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        // split across midnight
                        var curStart = s.startDate
                        while curStart < s.endDate {
                            let dayStart = self.calendar.startOfDay(for: curStart)
                            guard let dayEnd = self.calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                            let chunkEnd = min(dayEnd, s.endDate)
                            let delta = chunkEnd.timeIntervalSince(curStart)
                            daily[dayStart, default: 0] += delta
                            curStart = chunkEnd
                        }
                    }
                }
                cont.resume(returning: daily)
            }
            self.healthStore.execute(query)
        }
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
            
            // Load sleep
            let sleepMap = try await fetchSleepDaily(startDate: startOfDay, endDate: endOfDay)
            todaySleepHours = (sleepMap[startOfDay] ?? 0) / 3600
            print("🏥 Today's sleep: \(todaySleepHours) hours")
            
        } catch {
            print("🏥 Error loading today's data: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: Historical Sample Fetchers (Apple Health-like behavior)
    
    /// Fetch historical samples with Apple Health-like behavior (extends beyond 30 days for sparse metrics)
    func fetchHistoricalSamples(for type: HKQuantityTypeIdentifier, unit: HKUnit, preferredDays: Int = 30) async throws -> [HealthMetricPoint] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid quantity type"])
        }
        
        let now = Date()
        
        // For sparse metrics (VO2 Max, HRV, RHR), extend search to 1 year to find samples
        // For frequent metrics (Weight), use shorter period
        let searchPeriod: Int = {
            switch type {
            case .vo2Max, .heartRateVariabilitySDNN, .restingHeartRate:
                return 365 // 1 year for sparse Apple Watch metrics
            case .bodyMass:
                return 90   // 3 months for manually enterable metrics
            default:
                return preferredDays
            }
        }()
        
        guard let startDate = calendar.date(byAdding: .day, value: -searchPeriod, to: now) else {
            return []
        }
        
        print("🏥 Fetching historical samples for \(type.rawValue) from \(startDate) to \(now) (searching \(searchPeriod) days)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false) // Latest first
            
            // For sparse metrics, limit to 50 latest samples; for frequent ones, no limit in date range
            let sampleLimit: Int = {
                switch type {
                case .vo2Max, .heartRateVariabilitySDNN, .restingHeartRate:
                    return 50 // Latest 50 samples for sparse metrics
                default:
                    return HKObjectQueryNoLimit
                }
            }()
            
            let query = HKSampleQuery(sampleType: quantityType,
                                    predicate: predicate,
                                    limit: sampleLimit,
                                    sortDescriptors: [sortDescriptor]) { _, results, error in
                if let error = error {
                    print("🏥 Error fetching samples for \(type.rawValue): \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = results as? [HKQuantitySample] else {
                    print("🏥 No samples found for \(type.rawValue) in \(searchPeriod) days")
                    continuation.resume(returning: [])
                    return
                }
                
                // Convert to HealthMetricPoint and sort chronologically for charts
                let points = samples.map { sample in
                    HealthMetricPoint(
                        date: sample.endDate,
                        value: sample.quantity.doubleValue(for: unit)
                    )
                }.sorted { $0.date < $1.date } // Chronological order for charts
                
                print("🏥 Found \(points.count) actual samples for \(type.rawValue)")
                if let latest = points.last {
                    let daysSinceLatest = Calendar.current.dateComponents([.day], from: latest.date, to: now).day ?? 0
                    print("🏥 Latest sample for \(type.rawValue): \(latest.value) from \(daysSinceLatest) days ago")
                }
                
                continuation.resume(returning: points)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: Latest Sample Fetchers (immediate data)
    func loadLatestSamples() async {
        print("🏥 Fetching latest samples for immediate display...")
        
        // VO₂ Max - latest sample
        if let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            if let latest = try? await fetchLatestSample(vo2Type) as? HKQuantitySample {
                let vo2Value = latest.quantity.doubleValue(for: HKUnit(from: "ml/kg·min"))
                let point = HealthMetricPoint(date: latest.endDate, value: vo2Value)
                await MainActor.run {
                    self.vo2Max30 = [point] // Start with latest, will be filled with historical
                }
                print("🏥 Latest VO₂ Max: \(vo2Value) ml/kg·min")
        } else {
                print("🏥 No VO₂ Max data available")
            }
        }
        
        // HRV - latest sample
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            if let latest = try? await fetchLatestSample(hrvType) as? HKQuantitySample {
                let hrvValue = latest.quantity.doubleValue(for: .secondUnit(with: .milli))
                let point = HealthMetricPoint(date: latest.endDate, value: hrvValue)
                await MainActor.run {
                    self.hrv30 = [point]
                }
                print("🏥 Latest HRV: \(hrvValue) ms")
        } else {
                print("🏥 No HRV data available")
            }
        }
        
        // Resting Heart Rate - latest sample
        if let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            if let latest = try? await fetchLatestSample(rhrType) as? HKQuantitySample {
                let rhrValue = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let point = HealthMetricPoint(date: latest.endDate, value: rhrValue)
                await MainActor.run {
                    self.rhr30 = [point]
                }
                print("🏥 Latest RHR: \(rhrValue) BPM")
        } else {
                print("🏥 No RHR data available")
            }
        }
        
        // Weight - latest sample
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            if let latest = try? await fetchLatestSample(weightType) as? HKQuantitySample {
                let weightValue = latest.quantity.doubleValue(for: .gramUnit(with: .kilo))
                let point = HealthMetricPoint(date: latest.endDate, value: weightValue)
                await MainActor.run {
                    self.weight30 = [point]
                }
                print("🏥 Latest Weight: \(weightValue) kg")
                    } else {
                print("🏥 No Weight data available")
            }
        }
    }
    
    // MARK: Apple Health-like biology data loader
    func loadBiology30Days() async {
        print("🏥 Loading biology data with Apple Health-like behavior...")
        
        // Fetch actual historical samples (no LKV padding)
        do {
            // VO2 Max samples
            let vo2Samples = try await fetchHistoricalSamples(for: .vo2Max, unit: HKUnit(from: "ml/kg·min"))
            await MainActor.run {
                self.vo2Max30 = vo2Samples
            }
            print("🏥 VO2 Max: \(vo2Samples.count) actual samples")
            
            // HRV samples
            let hrvSamples = try await fetchHistoricalSamples(for: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
            await MainActor.run {
                self.hrv30 = hrvSamples
            }
            print("🏥 HRV: \(hrvSamples.count) actual samples")
            
            // RHR samples
            let rhrSamples = try await fetchHistoricalSamples(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: HKUnit.minute()))
            await MainActor.run {
                self.rhr30 = rhrSamples
            }
            print("🏥 RHR: \(rhrSamples.count) actual samples")
            
            // Weight samples
            let weightSamples = try await fetchHistoricalSamples(for: .bodyMass, unit: HKUnit.gramUnit(with: .kilo))
            await MainActor.run {
                self.weight30 = weightSamples
            }
            print("🏥 Weight: \(weightSamples.count) actual samples")
            
        } catch {
            print("🏥 Error loading historical samples: \(error)")
            // Initialize with empty arrays if error occurs
            await MainActor.run {
                self.vo2Max30 = []
                self.hrv30 = []
                self.rhr30 = []
                self.weight30 = []
            }
        }
        
        print("🏥 Biology data loading completed - showing actual samples only")
    }


    // MARK: Observers & Anchored queries (incremental updates)
    func startObservers() {
        let sampleTypes: [HKSampleType] = [
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .vo2Max)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        for type in sampleTypes {
            if observerQueries[type] != nil { continue }
            let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
                print("🔍 Observer fired for \(type.identifier)")
                Task {
                    await self?.handleObserverFired(for: type)
                    completionHandler()
                }
            }
            observerQueries[type] = observer
            healthStore.execute(observer)
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, err in
                print("📱 Background delivery \(success ? "enabled" : "failed") for \(type.identifier)")
            }
        }
        print("🔍 Started observers for \(sampleTypes.count) sample types")
    }

    private func handleObserverFired(for sampleType: HKSampleType) async {
        print("🔍 Handling observer fired for \(sampleType.identifier)")
        // anchored fetch
        let anchor = loadAnchor(for: sampleType)
        let anchoredQuery = HKAnchoredObjectQuery(type: sampleType, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) { [weak self] _, samplesOrNil, deletedObjects, newAnchor, error in
                if let error = error {
                print("🔍 Anchored query error for \(sampleType.identifier): \(error)")
                    return
                }
                
            if let samples = samplesOrNil, !samples.isEmpty {
                print("🔍 Received \(samples.count) new samples for \(sampleType.identifier)")
            }
            
            // process newly arrived samples if any
            if let newAnchor = newAnchor {
                Task { @MainActor in
                    self?.saveAnchor(newAnchor, for: sampleType)
                }
            }
            Task {
                // re-run historical load for relevant metric
                await self?.loadBiology30Days()
                await self?.loadTodayData()
            }
        }
        anchoredQuery.updateHandler = { [weak self] _, samples, deleted, newAnchor, _ in
            if let newAnchor = newAnchor { 
                Task { @MainActor in
                    self?.saveAnchor(newAnchor, for: sampleType)
                }
            }
            Task {
                await self?.loadBiology30Days()
                await self?.loadTodayData()
            }
        }
        anchoredQueries[sampleType] = anchoredQuery
        healthStore.execute(anchoredQuery)
    }

    // Anchor persistence
    private func anchorFileURL(for type: HKSampleType) -> URL {
        let filename = "anchor_\(type.identifier).bin"
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(filename)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor, for type: HKSampleType) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            try data.write(to: anchorFileURL(for: type), options: .atomic)
            print("📌 Saved anchor for \(type.identifier)")
        } catch {
            print("❌ Failed to save anchor for \(type.identifier): \(error)")
        }
    }

    private func loadAnchor(for type: HKSampleType) -> HKQueryAnchor? {
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
    
    // MARK: - Refresh authorization status
    func refreshAuthorizationStatus() async {
        print("🔄 Refreshing authorization status")
        await updatePermissionStatus()
    }
}
