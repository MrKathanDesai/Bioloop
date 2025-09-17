import Foundation
import HealthKit
import Combine

// MARK: - Apple HealthKit Best Practices Implementation

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current
    
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isDataAvailable = false
    @Published var lastSyncDate: Date?
    @Published var backgroundDeliveryEnabled = false
    
    // MARK: - HealthKit Data Types (Following Apple Guidelines)
    
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        
        // Heart & Cardiovascular
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let vo2Max = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2Max)
        }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let walkingHR = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            types.insert(walkingHR)
        }
        
        // Activity & Energy
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let basalEnergy = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(basalEnergy)
        }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        if let standTime = HKQuantityType.quantityType(forIdentifier: .appleStandTime) {
            types.insert(standTime)
        }
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let walkingDistance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(walkingDistance)
        }
        
        // Body Measurements
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let bodyFat = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        if let leanBodyMass = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanBodyMass)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        
        // Sleep
        if let sleepAnalysis = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepAnalysis)
        }
        
        // Workouts
        types.insert(HKWorkoutType.workoutType())
        
        return types
    }()
    
    private let writeTypes: Set<HKSampleType> = {
        // Only request write access for data we actually need to write
        var types: Set<HKSampleType> = []
        
        // We might want to write workout data or custom metrics
        types.insert(HKWorkoutType.workoutType())
        
        return types
    }()
    
    // MARK: - Sample Types for Observer Queries
    
    private let observerSampleTypes: [HKSampleType] = {
        var types: [HKSampleType] = []
        
        // Heart & Cardiovascular
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.append(heartRate)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.append(hrv)
        }
        
        // Sleep
        if let sleepAnalysis = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.append(sleepAnalysis)
        }
        
        return types
    }()
    
    // MARK: - Initialization
    
    private init() {
        checkHealthKitAvailability()
        setupBackgroundDelivery()
    }
    
    // MARK: - HealthKit Availability Check
    
    func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this device")
            authorizationStatus = .notDetermined
            isDataAvailable = false
            return
        }
        
        // Check authorization status for primary data type (heart rate)
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("❌ Heart rate type not available")
            return
        }
        
        let newStatus = healthStore.authorizationStatus(for: heartRateType)
        
        if authorizationStatus != newStatus {
            authorizationStatus = newStatus
            isDataAvailable = authorizationStatus == .sharingAuthorized
            
            print("🔄 Authorization status updated: \(newStatus.rawValue)")
            print("📊 Data available: \(isDataAvailable)")
            
            // Update last sync date if we have permission
            if isDataAvailable {
                lastSyncDate = Date()
            }
        }
    }
    
    // MARK: - Authorization Request (Following Apple Guidelines)
    
    func requestPermissions() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataNotAvailable
        }
        
        print("🔐 Requesting HealthKit permissions...")
        
        do {
            // Request authorization with proper error handling
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            
            // Wait a moment for HealthKit to process the authorization
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check the updated status
            await MainActor.run {
                self.checkHealthKitAvailability()
            }
            
            print("✅ HealthKit permissions requested successfully")
            
        } catch {
            print("❌ HealthKit permission error: \(error)")
            throw HealthKitError.permissionDenied
        }
    }
    
    // MARK: - Background Delivery Setup (Apple Best Practice)
    
    private func setupBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Enable background delivery for key data types
        let keyTypes: [HKObjectType] = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        for type in keyTypes {
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Background delivery enabled for \(type.identifier)")
                        self?.backgroundDeliveryEnabled = true
                    } else {
                        print("❌ Background delivery failed for \(type.identifier): \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    // MARK: - Data Fetching (Optimized for Performance)
    
    func fetchHealthData(for date: Date) async throws -> HealthData {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        print("📊 Fetching health data for: \(date)")
        
        // Fetch all data concurrently for better performance
        async let hrvData = fetchHRVData(from: startOfDay, to: endOfDay)
        async let rhrData = fetchRestingHeartRate(from: startOfDay, to: endOfDay)
        async let hrData = fetchHeartRateData(from: startOfDay, to: endOfDay)
        async let energyData = fetchEnergyBurned(from: startOfDay, to: endOfDay)
        async let sleepData = fetchSleepData(for: date)
        async let vo2MaxData = fetchVO2MaxData(from: startOfDay, to: endOfDay)
        async let weightData = fetchWeightData(from: startOfDay, to: endOfDay)
        async let leanBodyMassData = fetchLeanBodyMassData(from: startOfDay, to: endOfDay)
        async let bodyFatData = fetchBodyFatData(from: startOfDay, to: endOfDay)
        
        // Wait for all data
        let hrv = try await hrvData
        let rhr = try await rhrData
        let hr = try await hrData
        let energy = try await energyData
        let sleep = try await sleepData
        let vo2Max = try await vo2MaxData
        let weight = try await weightData
        let leanBodyMass = try await leanBodyMassData
        let bodyFat = try await bodyFatData
        
        return HealthData(
            date: date,
            hrv: hrv,
            restingHeartRate: rhr,
            heartRate: hr,
            energyBurned: energy,
            sleepStart: sleep.start,
            sleepEnd: sleep.end,
            sleepDuration: sleep.duration,
            sleepEfficiency: sleep.efficiency,
            deepSleep: sleep.deepSleep,
            remSleep: sleep.remSleep,
            wakeEvents: sleep.wakeEvents,
            workoutMinutes: nil, // TODO: Implement workout data
            vo2Max: vo2Max,
            weight: weight,
            leanBodyMass: leanBodyMass,
            bodyFat: bodyFat
        )
    }
    
    // MARK: - Individual Data Fetchers (Using Correct Units)
    
    private func fetchHRVData(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    // HRV is stored in milliseconds (ms) in HealthKit
                    let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    print("✅ HRV: \(value)ms")
                    continuation.resume(returning: value)
                } else {
                    print("⚠️ HRV: No data")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    // Heart rate is stored in beats per minute (bpm)
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    print("✅ RHR: \(value)BPM")
                    continuation.resume(returning: value)
                } else {
                    print("⚠️ RHR: No data")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchHeartRateData(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let avgHR = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                    print("✅ Avg HR: \(avgHR)BPM")
                    continuation.resume(returning: avgHR)
                } else {
                    print("⚠️ Avg HR: No data")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchVO2MaxData(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    // VO2 Max is stored in ml/kg/min
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg/min"))
                    print("✅ VO2 Max: \(value) ml/kg/min")
                    continuation.resume(returning: value)
                } else {
                    print("⚠️ VO2 Max: No data")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchWeightData(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    // Weight is stored in kilograms (kg)
                    let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    print("✅ Weight: \(value) kg")
                    continuation.resume(returning: value)
                } else {
                    print("⚠️ Weight: No data")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchLeanBodyMassData(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let leanBodyMassType = HKQuantityType.quantityType(forIdentifier: .leanBodyMass) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: leanBodyMassType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    // Lean body mass is stored in kilograms (kg)
                    let value = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    print("✅ Lean Body Mass: \(value) kg")
                    continuation.resume(returning: value)
                } else {
                    print("⚠️ Lean Body Mass: No data")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchBodyFatData(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(
                sampleType: bodyFatType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let sample = samples?.first as? HKQuantitySample {
                    // Body fat percentage is stored as a percentage (0-100)
                    let value = sample.quantity.doubleValue(for: HKUnit.percent())
                    print("✅ Body Fat: \(value)%")
                    continuation.resume(returning: value)
                } else {
                    print("⚠️ Body Fat: No data")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchEnergyBurned(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let totalEnergy = statistics?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) {
                    print("✅ Energy Burned: \(totalEnergy)kcal")
                    continuation.resume(returning: totalEnergy)
                } else {
                    print("⚠️ Energy Burned: No data")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepData(for date: Date) async throws -> (start: Date?, end: Date?, duration: Double?, efficiency: Double?, deepSleep: Double?, remSleep: Double?, wakeEvents: Int?) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (nil, nil, nil, nil, nil, nil, nil)
        }
        
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    print("⚠️ Sleep: No data")
                    continuation.resume(returning: (nil, nil, nil, nil, nil, nil, nil))
                    return
                }
                
                print("✅ Sleep: \(sleepSamples.count) samples")
                
                // Process sleep samples according to Apple's sleep analysis categories
                var sleepStart: Date?
                var sleepEnd: Date?
                var totalSleepTime: TimeInterval = 0
                var inBedTime: TimeInterval = 0
                var wakeEvents = 0
                var deepSleepTime: TimeInterval = 0
                var remSleepTime: TimeInterval = 0
                
                for sample in sleepSamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    inBedTime += duration
                    
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        // In bed time
                        if sleepStart == nil || sample.startDate < sleepStart! {
                            sleepStart = sample.startDate
                        }
                        if sleepEnd == nil || sample.endDate > sleepEnd! {
                            sleepEnd = sample.endDate
                        }
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        // Actual sleep time
                        totalSleepTime += duration
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        // Wake time during sleep
                        wakeEvents += 1
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        // Core sleep
                        totalSleepTime += duration
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        // Deep sleep
                        totalSleepTime += duration
                        deepSleepTime += duration
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        // REM sleep
                        totalSleepTime += duration
                        remSleepTime += duration
                    default:
                        break
                    }
                }
                
                let sleepDuration = totalSleepTime / 3600.0 // Convert to hours
                let efficiency = inBedTime > 0 ? totalSleepTime / inBedTime : 0
                let deepSleepHours = deepSleepTime / 3600.0
                let remSleepHours = remSleepTime / 3600.0
                
                print("✅ Sleep Duration: \(sleepDuration)h, Efficiency: \(efficiency * 100)%")
                print("✅ Deep Sleep: \(deepSleepHours)h, REM Sleep: \(remSleepHours)h")
                
                continuation.resume(returning: (sleepStart, sleepEnd, sleepDuration, efficiency, deepSleepHours, remSleepHours, wakeEvents))
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Observer Queries for Real-time Updates (Apple Best Practice)
    
    func startObservingHealthData() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // Set up observer queries for key metrics using the correct sample types
        for sampleType in observerSampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                if let error = error {
                    print("❌ Observer query error for \(sampleType.identifier): \(error)")
                    completionHandler()
                    return
                }
                
                print("📡 Health data updated for \(sampleType.identifier)")
                
                // Update last sync date
                DispatchQueue.main.async {
                    self?.lastSyncDate = Date()
                }
                
                completionHandler()
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Data Availability Check
    
    func checkDataAvailability() -> DataAvailability {
        checkHealthKitAvailability()
        
        let hasPermission = authorizationStatus == .sharingAuthorized
        
        // Test with a simple heart rate query to verify data access
        var hasData = false
        let semaphore = DispatchSemaphore(value: 0)
        
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: [])
            let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
                hasData = (samples?.count ?? 0) > 0
                semaphore.signal()
            }
            healthStore.execute(query)
            semaphore.wait()
        }
        
        print("🔍 Data availability - Permission: \(hasPermission), Has Data: \(hasData)")
        
        return DataAvailability(
            hasHealthKitPermission: hasPermission,
            hasAppleWatchData: hasData,
            lastSyncDate: lastSyncDate,
            missingDataTypes: hasPermission ? [] : ["Heart Rate", "HRV", "Sleep", "Activity"]
        )
    }
    
    // MARK: - Permission Refresh
    
    func refreshPermissions() {
        print("🔄 Refreshing HealthKit permissions...")
        checkHealthKitAvailability()
    }
}

// MARK: - Error Types (Following Apple Guidelines)

enum HealthKitError: Error, LocalizedError {
    case healthDataNotAvailable
    case permissionDenied
    case dataUnavailable
    case invalidData
    case queryFailed
    
    var errorDescription: String? {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit is not available on this device"
        case .permissionDenied:
            return "HealthKit permissions are required to access health data"
        case .dataUnavailable:
            return "Health data is not available for the selected date"
        case .invalidData:
            return "Invalid health data received"
        case .queryFailed:
            return "Failed to query health data"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthDataNotAvailable:
            return "HealthKit is only available on iOS devices"
        case .permissionDenied:
            return "Please grant HealthKit permissions in Settings > Privacy & Security > Health > Bioloop"
        case .dataUnavailable:
            return "Try selecting a different date or ensure your Apple Watch is synced"
        case .invalidData:
            return "Please try again or contact support if the issue persists"
        case .queryFailed:
            return "Please check your internet connection and try again"
        }
    }
}