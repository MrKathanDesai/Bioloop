import SwiftUI
import Charts

// MARK: - Design Tokens & Colors
struct BiologyColors {
    static let bg = Color(hex: "#F6F7FB")
    static let cardBorder = Color(hex: "#E9EDF3")
    static let shadow = Color(hex: "#0B1A2A").opacity(0.06)
    static let text = Color(hex: "#111316")
    static let subtext = Color(hex: "#6C6F74")
    static let muted = Color(hex: "#9CA0A9")
    static let primary = Color(hex: "#2E7BFF")
    static let violet = Color(hex: "#7A4CFF")
    static let danger = Color(hex: "#E45B2C")
    static let success = Color(hex: "#10B981")
    static let warning = Color(hex: "#F59E0B")
    static let grid = Color(hex: "#E9EBF0")
}

// MARK: - Spacing Constants
struct BiologySpacing {
    static let cardSpacing: CGFloat = 16
    static let horizontalPadding: CGFloat = 16
    static let cardInternalPadding: CGFloat = 16
    static let sideBySideSpacing: CGFloat = 16
    static let bottomSafeArea: CGFloat = 90
    static let headerTopPadding: CGFloat = 16
    static let headerSpacing: CGFloat = 12
    static let contentSpacing: CGFloat = 16
    static let chartPadding: CGFloat = 8
    static let textSpacing: CGFloat = 6
    static let metricChartSpacing: CGFloat = 12
}

// MARK: - Data Models

struct VO2MaxPercentile {
    let ageRange: String
    let poor: Double
    let fair: Double
    let good: Double
    let excellent: Double
}

struct HeartRateZone {
    let name: String
    let minBPM: Double
    let maxBPM: Double
    let color: Color
}

struct BodyCompositionData {
    let muscle: Double
    let fat: Double
    let bone: Double
    let water: Double
}

// MARK: - Card Style Modifier
extension View {
    func biologyCard() -> some View {
        self
            .padding(.vertical, BiologySpacing.cardInternalPadding)
            .padding(.horizontal, BiologySpacing.cardInternalPadding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: BiologyColors.shadow, radius: 36, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(BiologyColors.cardBorder.opacity(0.6), lineWidth: 1)
            )
    }
}

struct BiologyView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var healthData: HealthData?
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var cardAppearStates: [Bool] = Array(repeating: false, count: 6)
    
    // Real trend data from HealthKit - now reactive via DataManager (declared above)
    @State private var bodyComposition: BodyCompositionData?
    @State private var userProfile: UserProfile?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ScrollView {
            VStack(spacing: BiologySpacing.contentSpacing) {
                // Header Section
                headerSection
                
                if isLoading {
                    loadingSection
                } else if DataManager.shared.hasHealthKitPermission, let healthData = healthData {
                    contentSection(healthData: healthData)
                } else {
                    noDataSection
                }
            }
            .padding(.horizontal, BiologySpacing.horizontalPadding)
        }
        .background(BiologyColors.bg)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selected: .constant(3))
        }
        .onAppear {
            loadHealthData()
            setupHistoricalDataObserver()
            
            if !reduceMotion {
                startStaggeredAnimation()
            } else {
                cardAppearStates = Array(repeating: true, count: 6)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
                VStack(spacing: BiologySpacing.headerSpacing) {
                    HStack {
                        Text("Biology")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(BiologyColors.text)
                        
                        Spacer()
                        
                if !DataManager.shared.hasHealthKitPermission {
                                Button(action: {
                        requestHealthKitPermissions()
                                }) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                            Text("Connect Health")
                                        .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                        .background(BiologyColors.primary)
                        .cornerRadius(8)
                    }
                }
            }
            
            if !DataManager.shared.hasHealthKitPermission {
                Text("Connect to HealthKit to view your real health data and insights.")
                            .font(.system(size: 12))
                            .foregroundColor(BiologyColors.subtext)
                    .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
            }
        }
    }
    
    private var noDataSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.circle")
                .font(.system(size: 64))
                .foregroundColor(BiologyColors.muted)
            
            VStack(spacing: 8) {
                Text("No Health Data")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Text("Connect to HealthKit to view your personalized health insights and track your progress over time.")
                    .font(.system(size: 14))
                    .foregroundColor(BiologyColors.subtext)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                requestHealthKitPermissions()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                    Text("Connect HealthKit")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(BiologyColors.primary)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(.vertical, 40)
    }
    
    private var loadingSection: some View {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(BiologyColors.primary)
                        
                        Text("Loading health data...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BiologyColors.subtext)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding(.vertical, 40)
    }
    
    private func contentSection(healthData: HealthData) -> some View {
                    VStack(spacing: BiologySpacing.cardSpacing) {
            // Cardio Fitness (VO2 Max) with percentile chart
            VO2MaxCard(
                value: dataManager.latestVO2Max ?? 0,
                history: dataManager.vo2MaxSeries,
                userAge: 30, // Default age - could be enhanced to calculate from birth date
                hasData: dataManager.hasRecentVO2Max
            )
                            .offset(y: cardAppearStates[0] ? 0 : 12)
                        
                        HStack(spacing: BiologySpacing.sideBySideSpacing) {
                // HRV with baseline comparison
                HRVCard(
                    currentValue: dataManager.latestHRV ?? 0,
                    history: dataManager.hrvSeries,
                    hasData: dataManager.hasRecentHRV
                )
                                .offset(y: cardAppearStates[1] ? 0 : 12)
                            
                // Resting Heart Rate with zones
                RestingHeartRateCard(
                    currentValue: dataManager.latestRHR ?? 0,
                    history: dataManager.rhrSeries,
                    hasData: dataManager.hasRecentRHR
                )
                                .offset(y: cardAppearStates[2] ? 0 : 12)
                        }
                        
            // Weight tracking with BMI context
            WeightTrackingCard(
                currentWeight: dataManager.latestWeight ?? 0,
                history: dataManager.weightSeries,
                height: 175, // Default height in cm - could be enhanced to fetch from HealthKit
                hasData: dataManager.hasRecentWeight
            )
                            .offset(y: cardAppearStates[3] ? 0 : 12)
                        
                        HStack(spacing: BiologySpacing.sideBySideSpacing) {
                // Body composition pie chart
                BodyCompositionCard(
                    composition: bodyComposition ?? BodyCompositionData(
                        muscle: healthData.leanBodyMass ?? 0,
                        fat: healthData.bodyFat ?? 0,
                        bone: 12.0,
                        water: 60.0
                    )
                )
                                .offset(y: cardAppearStates[4] ? 0 : 12)
                            
                // Health score summary (only with recent data)
                HealthScoreCard(
                    vo2Max: dataManager.hasRecentVO2Max ? (dataManager.latestVO2Max ?? 0) : 0,
                    hrv: dataManager.hasRecentHRV ? (dataManager.latestHRV ?? 0) : 0,
                    rhr: dataManager.hasRecentRHR ? (dataManager.latestRHR ?? 0) : 0
                )
                                .offset(y: cardAppearStates[5] ? 0 : 12)
                        }
                    }
                    .padding(.horizontal, BiologySpacing.horizontalPadding)
                    .padding(.bottom, BiologySpacing.bottomSafeArea)
                    .opacity(cardAppearStates.allSatisfy { $0 } ? 1 : 0.3)
                    .animation(.easeOut(duration: 0.8), value: cardAppearStates.allSatisfy { $0 })
                }
    
    // MARK: - Data Loading
    
    private func setupHistoricalDataObserver() {
        // Subscribe to DataManager changes instead of custom notifications
        // The new system uses @Published properties that automatically update the UI
        print("🏥 Historical data observer setup - using @Published properties from DataManager")
    }
    
    private func startStaggeredAnimation() {
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.easeOut(duration: 0.6)) {
                    cardAppearStates[i] = true
                }
            }
        }
    }
    
    private func requestHealthKitPermissions() {
        Task {
            // Use DataManager for comprehensive authorization
            await DataManager.shared.requestHealthKitPermissions()
            
            await MainActor.run {
                if DataManager.shared.hasHealthKitPermission {
                    print("🏥 BiologyView: HealthKit authorization successful")
                    loadHealthData()
                } else {
                    errorMessage = "Failed to connect to HealthKit. Please check your permissions in Settings > Health > Data Access & Devices > Bioloop."
                    showError = true
                }
            }
        }
    }
    
    private func loadHealthData() {
        guard DataManager.shared.hasHealthKitPermission else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        Task {
            // Trigger DataManager to refresh all data (including latest values)
            await DataManager.shared.refreshAll()
            
            await MainActor.run {
                // Create HealthData from DataManager's latest values (LKV fallback)
                let rawData = HealthData(
                    date: Date(),
                    hrv: dataManager.latestHRV,
                    restingHeartRate: dataManager.latestRHR,
                    heartRate: dataManager.todayHeartRate > 0 ? dataManager.todayHeartRate : nil,
                    energyBurned: dataManager.todayActiveEnergy > 0 ? dataManager.todayActiveEnergy : nil,
                    sleepStart: nil,
                    sleepEnd: nil,
                    sleepDuration: dataManager.todaySleepHours > 0 ? dataManager.todaySleepHours : nil,
                    sleepEfficiency: nil,
                    deepSleep: nil,
                    remSleep: nil,
                    wakeEvents: nil,
                    workoutMinutes: nil,
                    vo2Max: dataManager.latestVO2Max,
                    weight: dataManager.latestWeight,
                    leanBodyMass: nil, // Not currently tracked
                    bodyFat: nil // Not currently tracked
                )
                
                healthData = rawData
                
                // User profile would be loaded from user settings in a real app
                userProfile = nil
                
                // Body composition would be calculated from real HealthKit data
                // For now, don't show fake estimates
                bodyComposition = nil
                
                isLoading = false
                print("🏥 Biology data loaded with latest values:")
                print("   VO2 Max: \(dataManager.latestVO2Max ?? 0)")
                print("   HRV: \(dataManager.latestHRV ?? 0)")
                print("   RHR: \(dataManager.latestRHR ?? 0)")
                print("   Weight: \(dataManager.latestWeight ?? 0)")
            }
        }
    }
    
    // Removed loadHistoricalDataFromDataManager - now using direct reactive binding
    
}

// MARK: - VO2 Max Card with Percentile Chart
struct VO2MaxCard: View {
    let value: Double
    let history: [HealthMetricPoint]
    let userAge: Int
    let hasData: Bool
    
    private var percentileData: VO2MaxPercentile {
        // Simplified age-based percentiles for men (should be more comprehensive)
        switch userAge {
        case 20...29:
            return VO2MaxPercentile(ageRange: "20-29", poor: 32, fair: 37, good: 44, excellent: 51)
        case 30...39:
            return VO2MaxPercentile(ageRange: "30-39", poor: 31, fair: 35, good: 41, excellent: 48)
        case 40...49:
            return VO2MaxPercentile(ageRange: "40-49", poor: 30, fair: 33, good: 38, excellent: 45)
        default:
            return VO2MaxPercentile(ageRange: "30-39", poor: 31, fair: 35, good: 41, excellent: 48)
        }
    }
    
    private var fitnessLevel: String {
        let percentile = percentileData
        switch value {
        case 0..<percentile.poor: return "Below Average"
        case percentile.poor..<percentile.fair: return "Fair"
        case percentile.fair..<percentile.good: return "Good"
        case percentile.good..<percentile.excellent: return "Very Good"
        default: return "Excellent"
        }
    }
    
    private var fitnessColor: Color {
        switch fitnessLevel {
        case "Below Average": return BiologyColors.danger
        case "Fair": return BiologyColors.warning
        case "Good": return BiologyColors.primary
        case "Very Good": return BiologyColors.violet
        case "Excellent": return BiologyColors.success
        default: return BiologyColors.muted
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header
            HStack {
                Image(systemName: "lungs.fill")
                    .font(.system(size: 16))
                    .foregroundColor(value > 0 ? fitnessColor : BiologyColors.muted)
                
                Text("Cardio Fitness")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Spacer()
                
                Text("VO₂ Max")
                    .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
            }
            
            // Current value and status
                VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                    if hasData && value > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", value))
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.text)
                            
                        Text("ml/kg/min")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
                                .baselineOffset(-2)
                        }
                        
                    Text(fitnessLevel)
                            .font(.system(size: 14, weight: .medium))
                        .foregroundColor(fitnessColor)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not Enough Data Yet")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(BiologyColors.muted)
                            
                            Text("Apple Watch Series 3+ tracks VO₂ Max during outdoor workouts")
                                .font(.system(size: 12))
                                .foregroundColor(BiologyColors.subtext)
                        }
                }
            }
            
            // Percentile chart
                if hasData && value > 0 {
                VStack(spacing: 8) {
                    // Age group percentile bars
                    Chart {
                        BarMark(
                            x: .value("Range", percentileData.poor),
                            y: .value("Level", "Fitness Level")
                        )
                        .foregroundStyle(BiologyColors.danger.opacity(0.3))
                        .cornerRadius(4)
                        
                        BarMark(
                            x: .value("Range", percentileData.fair - percentileData.poor),
                            y: .value("Level", "Fitness Level")
                        )
                        .foregroundStyle(BiologyColors.warning.opacity(0.3))
                        .cornerRadius(4)
                        
                        BarMark(
                            x: .value("Range", percentileData.good - percentileData.fair),
                            y: .value("Level", "Fitness Level")
                        )
                        .foregroundStyle(BiologyColors.primary.opacity(0.3))
                        .cornerRadius(4)
                        
                        BarMark(
                            x: .value("Range", percentileData.excellent - percentileData.good),
                            y: .value("Level", "Fitness Level")
                        )
                        .foregroundStyle(BiologyColors.success.opacity(0.3))
                        .cornerRadius(4)
                        
                        // Current value marker
                        RuleMark(x: .value("Current", value))
                            .foregroundStyle(fitnessColor)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                    .frame(height: 20)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    
                    // 30-day trend line
                    if !history.isEmpty {
                        Chart(history) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("VO2 Max", dataPoint.value)
                            )
                            .foregroundStyle(fitnessColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 40)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                    }
                }
            }
        }
        .biologyCard()
    }
}

// MARK: - Preview
struct BiologyView_Previews: PreviewProvider {
    static var previews: some View {
        BiologyView()
    }
}
