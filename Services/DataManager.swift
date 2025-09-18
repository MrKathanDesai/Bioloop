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

    // Today's basic metrics
    @Published var todaySteps: Double = 0
    @Published var todayHeartRate: Double = 0
    @Published var todayActiveEnergy: Double = 0
    @Published var todaySleepHours: Double = 0
    
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
    
    // Recency threshold for considering data "recent" (30 days)
    private let recencyThreshold: TimeInterval = 30 * 24 * 60 * 60 // 30 days in seconds
    
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
    
    /// Check if VO2 Max data is recent enough for score computation
    var hasRecentVO2Max: Bool {
        guard let date = latestVO2MaxDate else { return false }
        return Date().timeIntervalSince(date) <= recencyThreshold
    }
    
    /// Check if HRV data is recent enough for score computation
    var hasRecentHRV: Bool {
        guard let date = latestHRVDate else { return false }
        return Date().timeIntervalSince(date) <= recencyThreshold
    }
    
    /// Check if RHR data is recent enough for score computation
    var hasRecentRHR: Bool {
        guard let date = latestRHRDate else { return false }
        return Date().timeIntervalSince(date) <= recencyThreshold
    }
    
    /// Check if Weight data is recent enough for display
    var hasRecentWeight: Bool {
        guard let date = latestWeightDate else { return false }
        return Date().timeIntervalSince(date) <= recencyThreshold
    }
    
    /// Check if we have enough recent data for recovery score computation
    var canComputeRecoveryScore: Bool {
        return hasRecentHRV && hasRecentRHR
    }
}
