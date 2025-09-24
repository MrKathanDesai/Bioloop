import Combine
import Foundation

@MainActor
final class DataManager: ObservableObject {
    static let shared = DataManager()
    private let hk = HealthKitManager.shared
    private var cancellables: Set<AnyCancellable> = []

    // Biology metrics (30-day series)
    @Published var vo2MaxSeries: [HealthMetricPoint] = []
    @Published var hrvSeries: [HealthMetricPoint] = []
    @Published var rhrSeries: [HealthMetricPoint] = []
    @Published var weightSeries: [HealthMetricPoint] = []
    @Published var stepsSeries: [HealthMetricPoint] = []
    @Published var activeEnergySeries: [HealthMetricPoint] = []
    @Published var recentWorkouts: [WorkoutSummary] = []

    // Today's basic metrics
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
    
    // Body composition metrics
    @Published var latestLeanBodyMass: Double? = nil
    @Published var latestBodyFatPercentage: Double? = nil
    
    // Authorization state
    @Published var hasHealthKitPermission: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private init() {
        setupBindings()
    }
    
    private func setupBindings() {
        print("🔗 Setting up DataManager bindings...")
        
        // Bind HealthKitManager -> DataManager for biology metrics
        hk.$vo2Max30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 VO2 Max series updated: \(series.count) points")
                self?.vo2MaxSeries = series
                // Update latest value and date for Biology tab (Apple Health-like)
                if let latest = series.last {
                    self?.latestVO2Max = latest.value
                    self?.latestVO2MaxDate = latest.date
                    print("🔗 Latest VO2 Max: \(latest.value) from \(latest.date)")
                } else {
                    self?.latestVO2Max = nil
                    self?.latestVO2MaxDate = nil
                }
            }
            .store(in: &cancellables)

        hk.$hrv30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 HRV series updated: \(series.count) points")
                self?.hrvSeries = series
                // Update latest value and date for Biology tab (Apple Health-like)
                if let latest = series.last {
                    self?.latestHRV = latest.value
                    self?.latestHRVDate = latest.date
                    print("🔗 Latest HRV: \(latest.value) from \(latest.date)")
                } else {
                    self?.latestHRV = nil
                    self?.latestHRVDate = nil
                }
            }
            .store(in: &cancellables)

        hk.$rhr30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 RHR series updated: \(series.count) points")
                self?.rhrSeries = series
                // Update latest value and date for Biology tab (Apple Health-like)
                if let latest = series.last {
                    self?.latestRHR = latest.value
                    self?.latestRHRDate = latest.date
                    print("🔗 Latest RHR: \(latest.value) from \(latest.date)")
                } else {
                    self?.latestRHR = nil
                    self?.latestRHRDate = nil
                }
            }
            .store(in: &cancellables)

        hk.$weight30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 Weight series updated: \(series.count) points")
                self?.weightSeries = series
                // Update latest value and date for Biology tab (Apple Health-like)
                if let latest = series.last {
                    self?.latestWeight = latest.value
                    self?.latestWeightDate = latest.date
                    print("🔗 Latest Weight: \(latest.value) from \(latest.date)")
                } else {
                    self?.latestWeight = nil
                    self?.latestWeightDate = nil
                }
            }
            .store(in: &cancellables)

        // Bind activity series for Fitness
        hk.$steps30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 Steps series updated: \(series.count) points")
                self?.stepsSeries = series
            }
            .store(in: &cancellables)

        hk.$activeEnergy30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 Active energy series updated: \(series.count) points")
                self?.activeEnergySeries = series
            }
            .store(in: &cancellables)

        // Bind workouts
        hk.$recentWorkouts
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                print("🔗 Recent workouts updated: \(items.count)")
                self?.recentWorkouts = items
            }
            .store(in: &cancellables)
        
        // Bind today's metrics
        hk.$todaySteps
            .receive(on: RunLoop.main)
            .assign(to: \.todaySteps, on: self)
            .store(in: &cancellables)
            
        hk.$todayHeartRate
            .receive(on: RunLoop.main)
            .assign(to: \.todayHeartRate, on: self)
            .store(in: &cancellables)
            
        hk.$todayActiveEnergy
            .receive(on: RunLoop.main)
            .assign(to: \.todayActiveEnergy, on: self)
            .store(in: &cancellables)
            
        hk.$todaySleepHours
            .receive(on: RunLoop.main)
            .assign(to: \.todaySleepHours, on: self)
            .store(in: &cancellables)

        hk.$todayRespiratoryRate
            .receive(on: RunLoop.main)
            .assign(to: \.todayRespiratoryRate, on: self)
            .store(in: &cancellables)

        hk.$todaySpO2Percent
            .receive(on: RunLoop.main)
            .assign(to: \.todaySpO2Percent, on: self)
            .store(in: &cancellables)

        hk.$todayBodyTemperatureC
            .receive(on: RunLoop.main)
            .assign(to: \.todayBodyTemperatureC, on: self)
            .store(in: &cancellables)

        hk.$todayDietaryEnergy
            .receive(on: RunLoop.main)
            .assign(to: \.todayDietaryEnergy, on: self)
            .store(in: &cancellables)

        hk.$todayProteinGrams
            .receive(on: RunLoop.main)
            .assign(to: \.todayProteinGrams, on: self)
            .store(in: &cancellables)

        hk.$todayCarbsGrams
            .receive(on: RunLoop.main)
            .assign(to: \.todayCarbsGrams, on: self)
            .store(in: &cancellables)

        hk.$todayFatGrams
            .receive(on: RunLoop.main)
            .assign(to: \.todayFatGrams, on: self)
            .store(in: &cancellables)
        
        // Bind body composition metrics
        hk.$latestLeanBodyMass
            .receive(on: RunLoop.main)
            .assign(to: \.latestLeanBodyMass, on: self)
            .store(in: &cancellables)
            
        hk.$latestBodyFatPercentage
            .receive(on: RunLoop.main)
            .assign(to: \.latestBodyFatPercentage, on: self)
            .store(in: &cancellables)
        
        // Bind authorization state
        hk.$hasPermission
            .receive(on: RunLoop.main)
            .assign(to: \.hasHealthKitPermission, on: self)
            .store(in: &cancellables)
            
        hk.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
            
        hk.$errorMessage
            .receive(on: RunLoop.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        print("🔗 DataManager bindings setup completed")
    }

    // MARK: - Public API
    
    /// Call this from App launch or HomeView .onAppear
    func refreshAll() {
        print("🔄 DataManager.refreshAll() called")
        Task {
            do {
                let success = try await hk.requestAuthorization()
                if success {
                    print("🔄 Authorization successful - loading data")
                    // load initial 30-day biology data
                    await hk.loadBiology30Days()
                    // start observation for incremental updates
                    hk.startObservers()
                } else {
                    print("🔄 Authorization failed")
                }
            } catch {
                print("🔄 Authorization failed: \(error)")
            }
        }
    }
    
    /// Compute scores for a specific date D using historical series and LKV rules
    func scores(on date: Date) async -> HealthScore {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date

        // Apple Watch metrics: allow last-known up to D (7-day recency for scoring)
        let vo2 = latestValue(onOrBefore: dayEnd, from: vo2MaxSeries)
        let hrv = latestValue(onOrBefore: dayEnd, from: hrvSeries)
        let rhr = latestValue(onOrBefore: dayEnd, from: rhrSeries)

        // Manual metrics: last known value up to D (display only)
        let weight = latestValue(onOrBefore: dayEnd, from: weightSeries)

        let sleepHours = await sleepHoursForDay(dayStart)
        let healthData = HealthData(
            date: dayStart,
            hrv: hrv?.value,
            restingHeartRate: rhr?.value,
            heartRate: nil,
            energyBurned: energyForDay(dayStart),
            sleepStart: nil,
            sleepEnd: nil,
            sleepDuration: sleepHours,
            sleepEfficiency: nil,
            deepSleep: nil,
            remSleep: nil,
            wakeEvents: nil,
            workoutMinutes: nil,
            vo2Max: vo2?.value,
            weight: weight?.value,
            leanBodyMass: latestLeanBodyMass,
            bodyFat: latestBodyFatPercentage
        )

        let calculator = HealthCalculator.shared
        return calculator.calculateHealthScores(from: healthData)
    }

    private func latestValue(onOrBefore date: Date, from series: [HealthMetricPoint]) -> (value: Double, date: Date)? {
        return series.filter { $0.date <= date }.last.map { ($0.value, $0.date) }
    }

    private func energyForDay(_ dayStart: Date) -> Double? {
        if let point = activeEnergySeries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: dayStart) }) {
            return point.value
        }
        return nil
    }

    private func sleepHoursForDay(_ dayStart: Date) async -> Double? {
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dayStart)) else { return nil }
        if let secondsMap = try? await HealthKitManager.shared.fetchSleepDaily(startDate: calendar.startOfDay(for: dayStart), endDate: nextDay) {
            let sec = secondsMap[calendar.startOfDay(for: dayStart)] ?? 0
            return sec > 0 ? sec / 3600.0 : nil
        }
        return nil
    }
    /// Request authorization (centralized)
    func requestHealthKitPermissions() async {
        print("🔴 DataManager.requestHealthKitPermissions() called")
        let success = await hk.requestAuthorizationIfNeeded()
        if success {
            print("🔴 DataManager: HealthKit authorization successful")
        } else {
            print("🔴 DataManager: HealthKit authorization failed")
        }
    }
    
    /// Refresh authorization status
    func refreshPermissions() async {
        print("🔄 DataManager.refreshPermissions() called")
        await hk.refreshAuthorizationStatus()
    }
    
    // Latest values for Biology tab (Last Known Values with recency)
    @Published var latestVO2Max: Double? = nil
    @Published var latestVO2MaxDate: Date? = nil
    @Published var latestHRV: Double? = nil
    @Published var latestHRVDate: Date? = nil
    @Published var latestRHR: Double? = nil
    @Published var latestRHRDate: Date? = nil
    @Published var latestWeight: Double? = nil
    @Published var latestWeightDate: Date? = nil
    
    // Recency thresholds for different metric types (Apple Health-like)
    private let recencyThresholdWatch: TimeInterval = 7 * 24 * 60 * 60   // 7 days for Apple Watch metrics
    private let recencyThresholdManual: TimeInterval = 90 * 24 * 60 * 60 // 90 days for manual metrics
    private let displayThreshold: TimeInterval = 365 * 24 * 60 * 60      // 1 year for display purposes
    
    /// Get 7-day average RHR
    var averageRHR7Days: Double? {
        let recent = Array(rhrSeries.suffix(7))
        guard !recent.isEmpty else { return nil }
        let sum = recent.reduce(0) { $0 + $1.value }
        return sum / Double(recent.count)
    }
    
    /// Get 7-day average HRV
    var averageHRV7Days: Double? {
        let recent = Array(hrvSeries.suffix(7))
        guard !recent.isEmpty else { return nil }
        let sum = recent.reduce(0) { $0 + $1.value }
        return sum / Double(recent.count)
    }
    
    /// Check if we have any biology data
    var hasBiologyData: Bool {
        return !vo2MaxSeries.isEmpty || !hrvSeries.isEmpty || !rhrSeries.isEmpty || !weightSeries.isEmpty
    }
    
    /// Check if we have today's basic metrics
    var hasTodayData: Bool {
        return todaySteps > 0 || todayHeartRate > 0 || todayActiveEnergy > 0 || todaySleepHours > 0
    }
    
    // MARK: - Recency Checks (Apple Health-like behavior)
    
    /// Check if VO2 Max data is recent enough for score computation (7 days for Apple Watch)
    var hasRecentVO2Max: Bool {
        guard let date = latestVO2MaxDate else { return false }
        return Date().timeIntervalSince(date) <= recencyThresholdWatch
    }
    
    /// Check if VO2 Max data exists for display (1 year threshold)
    var hasDisplayableVO2Max: Bool {
        guard let date = latestVO2MaxDate, let value = latestVO2Max else { return false }
        return Date().timeIntervalSince(date) <= displayThreshold && value > 0
    }
    
    /// Check if HRV data is recent enough for score computation (7 days for Apple Watch)
    var hasRecentHRV: Bool {
        guard let date = latestHRVDate else { return false }
        return Date().timeIntervalSince(date) <= recencyThresholdWatch
    }
    
    /// Check if HRV data exists for display (1 year threshold)
    var hasDisplayableHRV: Bool {
        guard let date = latestHRVDate, let value = latestHRV else { return false }
        return Date().timeIntervalSince(date) <= displayThreshold && value > 0
    }
    
    /// Check if RHR data is recent enough for score computation (7 days for Apple Watch)
    var hasRecentRHR: Bool {
        guard let date = latestRHRDate else { return false }
        return Date().timeIntervalSince(date) <= recencyThresholdWatch
    }
    
    /// Check if RHR data exists for display (1 year threshold)
    var hasDisplayableRHR: Bool {
        guard let date = latestRHRDate, let value = latestRHR else { return false }
        return Date().timeIntervalSince(date) <= displayThreshold && value > 0
    }
    
    /// Check if Weight data is recent enough for display (90 days for manual metrics)
    var hasRecentWeight: Bool {
        guard let date = latestWeightDate else { return false }
        return Date().timeIntervalSince(date) <= recencyThresholdManual
    }
    
    /// Check if Weight data exists for display (1 year threshold)
    var hasDisplayableWeight: Bool {
        guard let date = latestWeightDate, let value = latestWeight else { return false }
        return Date().timeIntervalSince(date) <= displayThreshold && value > 0
    }
    
    /// Check if we have enough recent data for recovery score computation
    var canComputeRecoveryScore: Bool {
        return hasRecentHRV && hasRecentRHR
    }
}
