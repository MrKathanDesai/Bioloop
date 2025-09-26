import Combine
import Foundation

@MainActor
final class DataManager: ObservableObject {
    static let shared = DataManager()
    private let hk = HealthKitManager.shared
    private var cancellables: Set<AnyCancellable> = []
    
    // Load guard to prevent redundant fetches
    private var isRefreshing = false
    private var lastFullRefreshDate: Date?
    private let refreshCooldown: TimeInterval = 300 // 5 minutes
    
    // Caching for baselines and recent data
    private let userDefaults = UserDefaults.standard
    private let baselineCacheKey = "baselineStats"
    private let lastCacheUpdateKey = "lastCacheUpdate"
    private let cacheValidityPeriod: TimeInterval = 24 * 60 * 60 // 24 hours

    // Biology metrics (30-day series)
    @Published var vo2MaxSeries: [HealthMetricPoint] = [] {
        didSet {
            print("🔗 DataManager: vo2MaxSeries updated with \(vo2MaxSeries.count) points")
        }
    }
    @Published var hrvSeries: [HealthMetricPoint] = [] {
        didSet {
            print("🔗 DataManager: hrvSeries updated with \(hrvSeries.count) points")
        }
    }
    @Published var rhrSeries: [HealthMetricPoint] = [] {
        didSet {
            print("🔗 DataManager: rhrSeries updated with \(rhrSeries.count) points")
        }
    }
    @Published var weightSeries: [HealthMetricPoint] = [] {
        didSet {
            print("🔗 DataManager: weightSeries updated with \(weightSeries.count) points")
        }
    }
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
    
    // Comprehensive sleep data
    @Published var todaySleepSession: SleepSession? = nil
    @Published var todaySleepSummary: DailySleepSummary? = nil
    @Published var recentSleepSessions: [SleepSession] = []
    
    // Body composition metrics
    @Published var latestLeanBodyMass: Double? = nil
    @Published var latestBodyFatPercentage: Double? = nil
    
    // Authorization state
    @Published var hasHealthKitPermission: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private init() {
        setupBindings()
        // Load cached baselines on initialization
        _ = loadCachedBaselines()
    }
    
    private func setupBindings() {
        print("🔗 Setting up DataManager bindings...")
        
        // Bind HealthKitManager -> DataManager for biology metrics
        hk.$vo2Max30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 VO2 Max series updated: \(series.count) points")
                self?.vo2MaxSeries = series
                // Update latest ACTUAL value for scoring (no LKV)
                if let latestActual = series.last(where: { $0.isActualData }) {
                    self?.updateLatestVO2MaxActual(latestActual.value, date: latestActual.date)
                    print("🔗 Latest ACTUAL VO2 Max: \(latestActual.value) from \(latestActual.date)")
                } else {
                    self?.updateLatestVO2MaxActual(nil, date: nil)
                }
            }
            .store(in: &cancellables)

        hk.$hrv30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 HRV series updated: \(series.count) points")
                self?.hrvSeries = series
                // Update latest ACTUAL value for scoring (no LKV)
                if let latestActual = series.last(where: { $0.isActualData }) {
                    self?.updateLatestHRVActual(latestActual.value, date: latestActual.date)
                    print("🔗 Latest ACTUAL HRV: \(latestActual.value) from \(latestActual.date)")
                } else {
                    self?.updateLatestHRVActual(nil, date: nil)
                }
            }
            .store(in: &cancellables)

        hk.$rhr30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 RHR series updated: \(series.count) points")
                self?.rhrSeries = series
                // Update latest ACTUAL value for scoring (no LKV)
                if let latestActual = series.last(where: { $0.isActualData }) {
                    self?.updateLatestRHRActual(latestActual.value, date: latestActual.date)
                    print("🔗 Latest ACTUAL RHR: \(latestActual.value) from \(latestActual.date)")
                } else {
                    self?.updateLatestRHRActual(nil, date: nil)
                }
            }
            .store(in: &cancellables)

        hk.$weight30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 Weight series updated: \(series.count) points")
                self?.weightSeries = series
                // Update latest ACTUAL value for scoring (no LKV)
                if let latestActual = series.last(where: { $0.isActualData }) {
                    self?.updateLatestWeightActual(latestActual.value, date: latestActual.date)
                    print("🔗 Latest ACTUAL Weight: \(latestActual.value) from \(latestActual.date)")
                } else {
                    self?.updateLatestWeightActual(nil, date: nil)
                }
            }
            .store(in: &cancellables)

        // Bind activity series for Fitness
        hk.$steps30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 Steps series updated: \(series.count) points")
                self?.stepsSeries = series
                // Recompute baselines when data changes
                self?.computeAndCacheBaselines()
            }
            .store(in: &cancellables)

        hk.$activeEnergy30
            .receive(on: RunLoop.main)
            .sink { [weak self] series in
                print("🔗 Active energy series updated: \(series.count) points")
                self?.activeEnergySeries = series
                // Recompute baselines when data changes
                self?.computeAndCacheBaselines()
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
            .sink { [weak self] steps in
                self?.todaySteps = steps
                self?.updateMetricStates()
            }
            .store(in: &cancellables)
            
        hk.$todayHeartRate
            .receive(on: RunLoop.main)
            .assign(to: \.todayHeartRate, on: self)
            .store(in: &cancellables)
            
        hk.$todayActiveEnergy
            .receive(on: RunLoop.main)
            .sink { [weak self] energy in
                self?.todayActiveEnergy = energy
                self?.updateMetricStates()
            }
            .store(in: &cancellables)
            
        hk.$todaySleepHours
            .receive(on: RunLoop.main)
            .sink { [weak self] hours in
                self?.todaySleepHours = hours
                self?.updateMetricStates()
            }
            .store(in: &cancellables)
            
        // Bind comprehensive sleep data
        hk.$todaySleepSession
            .receive(on: RunLoop.main)
            .assign(to: \.todaySleepSession, on: self)
            .store(in: &cancellables)
            
        hk.$todaySleepSummary
            .receive(on: RunLoop.main)
            .assign(to: \.todaySleepSummary, on: self)
            .store(in: &cancellables)
            
        hk.$recentSleepSessions
            .receive(on: RunLoop.main)
            .assign(to: \.recentSleepSessions, on: self)
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
        
        // Check if we're already refreshing or recently refreshed
        guard !isRefreshing else {
            print("🔄 Already refreshing, skipping redundant call")
            return
        }
        
        // Check cooldown period
        if let lastRefresh = lastFullRefreshDate,
           Date().timeIntervalSince(lastRefresh) < refreshCooldown {
            print("🔄 Recent refresh (\(Int(Date().timeIntervalSince(lastRefresh)))s ago), skipping")
            return
        }
        
        isRefreshing = true
        lastFullRefreshDate = Date()
        
        Task {
            do {
                // Use consolidated flow that also loads today's metrics and activity
                let success = await hk.requestAuthorizationIfNeeded()
                if success {
                    print("🔄 Authorization successful - loading data")
                    // requestAuthorizationIfNeeded already loads today, biology, activity, workouts, and starts observers
                } else {
                    print("🔄 Authorization failed")
                }
            }
            
            // Reset refreshing flag on main actor
            await MainActor.run { 
                isRefreshing = false 
            }
        }
    }
    
    /// Compute scores for a specific date D using ACTUAL samples only (no LKV for scoring)
    func scores(on date: Date) async -> HealthScore {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date

        // Use only ACTUAL latests for scoring (no LKV). Gate by recency flags.
        let hrvActual = hasRecentHRV ? latestHRVActual?.value : nil
        let rhrActual = hasRecentRHR ? latestRHRActual?.value : nil
        let vo2Actual = hasRecentVO2Max ? latestVO2MaxActual?.value : nil

        // Manual metrics for display only can still use last-known
        let weight = latestValue(onOrBefore: dayEnd, from: weightSeries)

        // Get sleep data for the specific day
        let sleepSummary = try? await hk.fetchDailySleepSummary(for: dayStart)
        let sleepSession = sleepSummary?.primarySession
        
        let healthData = HealthData(
            date: dayStart,
            hrv: hrvActual,
            restingHeartRate: rhrActual,
            heartRate: nil,
            energyBurned: energyForDay(dayStart),
            sleepSession: sleepSession,
            sleepDuration: sleepSession?.durationHours,
            sleepEfficiency: sleepSession?.efficiency,
            deepSleep: sleepSession.map { $0.stages.deep / 3600.0 }, // Convert to hours
            remSleep: sleepSession.map { $0.stages.rem / 3600.0 },   // Convert to hours
            wakeEvents: sleepSession?.wakeEvents,
            workoutMinutes: nil,
            vo2Max: vo2Actual,
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
    
    // Latest ACTUAL values for scoring (no LKV, only recent samples)
    @Published var latestVO2MaxActual: HealthMetricPoint? = nil {
        didSet {
            print("🔗 DataManager: latestVO2MaxActual changed to: \(latestVO2MaxActual?.value ?? 0)")
            vo2MaxLatestActualDate = latestVO2MaxActual?.date
        }
    }
    // Convenience: expose latest actual date separately for policy checks/visuals
    @Published var vo2MaxLatestActualDate: Date? = nil
    @Published var latestHRVActual: HealthMetricPoint? = nil {
        didSet {
            print("🔗 DataManager: latestHRVActual changed to: \(latestHRVActual?.value ?? 0)")
        }
    }
    @Published var latestRHRActual: HealthMetricPoint? = nil {
        didSet {
            print("🔗 DataManager: latestRHRActual changed to: \(latestRHRActual?.value ?? 0)")
        }
    }
    @Published var latestWeightActual: HealthMetricPoint? = nil {
        didSet {
            print("🔗 DataManager: latestWeightActual changed to: \(latestWeightActual?.value ?? 0)")
        }
    }
    
    // Recency flags for scoring (single source of truth)
    @Published var hasRecentVO2Max: Bool = false {
        didSet {
            print("🔗 DataManager: hasRecentVO2Max changed to: \(hasRecentVO2Max)")
        }
    }
    @Published var hasRecentHRV: Bool = false {
        didSet {
            print("🔗 DataManager: hasRecentHRV changed to: \(hasRecentHRV)")
        }
    }
    @Published var hasRecentRHR: Bool = false {
        didSet {
            print("🔗 DataManager: hasRecentRHR changed to: \(hasRecentRHR)")
        }
    }
    @Published var hasRecentWeight: Bool = false {
        didSet {
            print("🔗 DataManager: hasRecentWeight changed to: \(hasRecentWeight)")
        }
    }
    
    // Validated metric states for scoring
    @Published var hrvState: MetricState<Double> = .missing
    @Published var rhrState: MetricState<Double> = .missing
    @Published var respState: MetricState<Double> = .missing
    @Published var spo2State: MetricState<Double> = .missing
    @Published var tempState: MetricState<Double> = .missing
    @Published var sleepState: MetricState<Double> = .missing
    @Published var stepsState: MetricState<Double> = .missing
    @Published var energyState: MetricState<Double> = .missing
    
    // Recency thresholds for different metric types (Apple Health-like)
    private let recencyThresholdWatch: TimeInterval = 7 * 24 * 60 * 60   // 7 days for Apple Watch metrics
    private let recencyThresholdManual: TimeInterval = 90 * 24 * 60 * 60 // 90 days for manual metrics
    private let displayThreshold: TimeInterval = 365 * 24 * 60 * 60      // 1 year for display purposes
    
    // MARK: - Centralized Recency Management
    
    /// Check if a date is recent within specified days
    func isRecent(_ date: Date?, within days: Int) -> Bool {
        guard let d = date else { return false }
        return d >= Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }
    
    /// Validate metric state based on value and recency
    private func validateMetricState<T>(_ value: T?, date: Date?, threshold: TimeInterval) -> MetricState<T> {
        guard let val = value, let d = date else { return .missing }
        let recent = d >= Date().addingTimeInterval(-threshold)
        return recent ? .valid(val, d) : .stale(d)
    }
    
    /// Update validated metric states
    private func updateMetricStates() {
        hrvState = validateMetricState(
            latestHRVActual?.value,
            date: latestHRVActual?.date,
            threshold: recencyThresholdWatch
        )

        rhrState = validateMetricState(
            latestRHRActual?.value,
            date: latestRHRActual?.date,
            threshold: recencyThresholdWatch
        )

        // For today metrics, use today's date as lastSeen when present
        let today = Date()
        let dayThreshold: TimeInterval = 24 * 60 * 60

        respState = validateMetricState(
            todayRespiratoryRate > 0 ? todayRespiratoryRate : nil,
            date: todayRespiratoryRate > 0 ? today : nil,
            threshold: dayThreshold
        )

        // SpO2 can be fractional percent; keep 0 as missing unless explicitly valid
        spo2State = validateMetricState(
            todaySpO2Percent > 0 ? todaySpO2Percent : nil,
            date: todaySpO2Percent > 0 ? today : nil,
            threshold: dayThreshold
        )

        // Temperature may be absolute or delta; treat any Double as available for today if present
        tempState = validateMetricState(
            // Accept non-zero temp; 0 treated as missing to avoid default masking
            todayBodyTemperatureC != 0 ? todayBodyTemperatureC : nil,
            date: todayBodyTemperatureC != 0 ? today : nil,
            threshold: dayThreshold
        )

        sleepState = validateMetricState(
            todaySleepHours > 0 ? todaySleepHours : nil,
            date: todaySleepHours > 0 ? today : nil,
            threshold: dayThreshold
        )

        stepsState = validateMetricState(
            todaySteps > 0 ? todaySteps : nil,
            date: todaySteps > 0 ? today : nil,
            threshold: dayThreshold
        )

        energyState = validateMetricState(
            todayActiveEnergy > 0 ? todayActiveEnergy : nil,
            date: todayActiveEnergy > 0 ? today : nil,
            threshold: dayThreshold
        )
    }
    
    /// Update latest actual value with centralized recency logic
    private func updateLatestActualValue<T>(_ value: T?, date: Date?, 
                                          publishedValue: inout T?, 
                                          publishedRecency: inout Bool,
                                          threshold: TimeInterval) {
        publishedValue = value
        publishedRecency = isRecent(date, within: Int(threshold / (24 * 60 * 60)))
    }
    
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
    
    // MARK: - Recency Management (Single Source of Truth)
    
    func updateLatestVO2MaxActual(_ value: Double?, date: Date?) {
        print("🔗 DataManager: Updating latest VO2 Max: \(value ?? 0) from \(date?.description ?? "nil")")
        let point = value != nil ? HealthMetricPoint(date: date ?? Date(), value: value!, isActualData: true) : nil
        updateLatestActualValue(point, date: date, 
                              publishedValue: &latestVO2MaxActual, 
                              publishedRecency: &hasRecentVO2Max,
                              threshold: recencyThresholdWatch)
        updateMetricStates()
        print("🔗 DataManager: VO2 Max updated - hasRecent: \(hasRecentVO2Max), value: \(latestVO2MaxActual?.value ?? 0)")
    }
    
    func updateLatestHRVActual(_ value: Double?, date: Date?) {
        let point = value != nil ? HealthMetricPoint(date: date ?? Date(), value: value!, isActualData: true) : nil
        updateLatestActualValue(point, date: date, 
                              publishedValue: &latestHRVActual, 
                              publishedRecency: &hasRecentHRV,
                              threshold: recencyThresholdWatch)
        updateMetricStates()
    }
    
    func updateLatestRHRActual(_ value: Double?, date: Date?) {
        let point = value != nil ? HealthMetricPoint(date: date ?? Date(), value: value!, isActualData: true) : nil
        updateLatestActualValue(point, date: date, 
                              publishedValue: &latestRHRActual, 
                              publishedRecency: &hasRecentRHR,
                              threshold: recencyThresholdWatch)
        updateMetricStates()
    }
    
    func updateLatestWeightActual(_ value: Double?, date: Date?) {
        let point = value != nil ? HealthMetricPoint(date: date ?? Date(), value: value!, isActualData: true) : nil
        updateLatestActualValue(point, date: date, 
                              publishedValue: &latestWeightActual, 
                              publishedRecency: &hasRecentWeight,
                              threshold: recencyThresholdManual)
        updateMetricStates()
    }
    
    /// Check if we have today's basic metrics
    var hasTodayData: Bool {
        return todaySteps > 0 || todayHeartRate > 0 || todayActiveEnergy > 0 || todaySleepHours > 0
    }
    
    // MARK: - Caching Methods
    
    /// Load cached baseline stats if available and recent
    private func loadCachedBaselines() -> [String: BaselineStats]? {
        guard let lastUpdate = userDefaults.object(forKey: lastCacheUpdateKey) as? Date,
              Date().timeIntervalSince(lastUpdate) < cacheValidityPeriod,
              let data = userDefaults.data(forKey: baselineCacheKey),
              let baselines = try? JSONDecoder().decode([String: BaselineStats].self, from: data) else {
            return nil
        }
        print("📦 Loaded cached baselines from \(lastUpdate)")
        return baselines
    }
    
    /// Save baseline stats to cache
    private func saveBaselinesToCache(_ baselines: [String: BaselineStats]) {
        do {
            let data = try JSONEncoder().encode(baselines)
            userDefaults.set(data, forKey: baselineCacheKey)
            userDefaults.set(Date(), forKey: lastCacheUpdateKey)
            print("📦 Saved baselines to cache")
        } catch {
            print("❌ Failed to cache baselines: \(error)")
        }
    }
    
    /// Compute and cache baseline stats with minimum thresholds
    private func computeAndCacheBaselines() {
        var baselines: [String: BaselineStats] = [:]
        
        // Steps baseline with minimum threshold
        if stepsSeries.count >= 14 {
            let values = stepsSeries.map { $0.value }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            let std = sqrt(variance)
            // Cap stddev floor to 5% of mean to avoid division by near-zero
            let cappedStd = max(std, mean * 0.05)
            baselines["steps"] = BaselineStats(mean: mean, stdDev: cappedStd, count: values.count)
        }
        
        // Active energy baseline with minimum threshold
        if activeEnergySeries.count >= 14 {
            let values = activeEnergySeries.map { $0.value }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            let std = sqrt(variance)
            let cappedStd = max(std, mean * 0.05)
            baselines["activeEnergy"] = BaselineStats(mean: mean, stdDev: cappedStd, count: values.count)
        }
        
        // HRV baseline with minimum threshold
        if hrvSeries.count >= 14 {
            let values = hrvSeries.compactMap { $0.isActualData ? $0.value : nil }
            if values.count >= 14 {
                let mean = values.reduce(0, +) / Double(values.count)
                let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
                let std = sqrt(variance)
                let cappedStd = max(std, mean * 0.05)
                baselines["hrv"] = BaselineStats(mean: mean, stdDev: cappedStd, count: values.count)
            }
        }
        
        // RHR baseline with minimum threshold
        if rhrSeries.count >= 14 {
            let values = rhrSeries.compactMap { $0.isActualData ? $0.value : nil }
            if values.count >= 14 {
                let mean = values.reduce(0, +) / Double(values.count)
                let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
                let std = sqrt(variance)
                let cappedStd = max(std, mean * 0.05)
                baselines["rhr"] = BaselineStats(mean: mean, stdDev: cappedStd, count: values.count)
            }
        }
        
        if !baselines.isEmpty {
            saveBaselinesToCache(baselines)
        }
    }
    
    /// Check if we can compute recovery score (has recent HRV and RHR)
    var canComputeRecoveryScore: Bool {
        return hasRecentHRV && hasRecentRHR
    }
    
    // MARK: - Personalized Baselines (Rolling Averages)
    
    /// Get 30-day rolling baseline for steps with caching and minimum thresholds
    var baselineSteps: BaselineStats {
        // Try cached baselines first
        if let cached = loadCachedBaselines(), let steps = cached["steps"] {
            return steps
        }
        
        let recent = Array(stepsSeries.suffix(30))
        guard recent.count >= 14 else { 
            return BaselineStats(mean: 8000, stdDev: 2000, count: 0) 
        }
        
        let values = recent.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let std = sqrt(variance)
        let cappedStd = max(std, mean * 0.05) // Cap stddev floor to 5% of mean
        
        let baseline = BaselineStats(mean: mean, stdDev: cappedStd, count: values.count)
        
        // Cache the computed baseline
        var cached = loadCachedBaselines() ?? [:]
        cached["steps"] = baseline
        saveBaselinesToCache(cached)
        
        return baseline
    }
    
    /// Get 30-day rolling baseline for active energy with caching and minimum thresholds
    var baselineActiveEnergy: BaselineStats {
        // Try cached baselines first
        if let cached = loadCachedBaselines(), let energy = cached["activeEnergy"] {
            return energy
        }
        
        let recent = Array(activeEnergySeries.suffix(30))
        guard recent.count >= 14 else { 
            return BaselineStats(mean: 400, stdDev: 100, count: 0) 
        }
        
        let values = recent.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let std = sqrt(variance)
        let cappedStd = max(std, mean * 0.05) // Cap stddev floor to 5% of mean
        
        let baseline = BaselineStats(mean: mean, stdDev: cappedStd, count: values.count)
        
        // Cache the computed baseline
        var cached = loadCachedBaselines() ?? [:]
        cached["activeEnergy"] = baseline
        saveBaselinesToCache(cached)
        
        return baseline
    }
    
    /// Get 30-day rolling baseline for HRV
    var baselineHRV: BaselineStats? {
        let recent = Array(hrvSeries.suffix(30))
        guard !recent.isEmpty else { return nil }
        let values = recent.map { $0.value }
        return BaselineStats.from(values: values)
    }
    
    /// Get 30-day rolling baseline for RHR
    var baselineRHR: BaselineStats? {
        let recent = Array(rhrSeries.suffix(30))
        guard !recent.isEmpty else { return nil }
        let values = recent.map { $0.value }
        return BaselineStats.from(values: values)
    }
}

// MARK: - Baseline Statistics

struct BaselineStats: Codable {
    let mean: Double
    let stdDev: Double
    let count: Int
    
    static func from(values: [Double]) -> BaselineStats {
        guard !values.isEmpty else {
            return BaselineStats(mean: 0, stdDev: 0, count: 0)
        }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        
        return BaselineStats(mean: mean, stdDev: stdDev, count: values.count)
    }
    
    /// Calculate z-score normalized value (maps z-score to 0-100 scale)
    func normalizedScore(value: Double, scale: Double = 3.0) -> Double {
        guard stdDev > 0 else { 
            // If no variance, use simple percentage of mean
            return min(max((value / mean * 50 + 50), 0), 100)
        }
        
        let z = (value - mean) / stdDev
        // Map z-score in [-scale, +scale] to [0, 100]
        let normalized = ((z + scale) / (2 * scale)) * 100
        return min(max(normalized, 0), 100)
    }
}
