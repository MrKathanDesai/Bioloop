import SwiftUI
import HealthKit

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel.shared
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with date and profile
                    HomeHeader(
                        selectedDate: $selectedDate,
                        userProfile: nil, // Will be handled by the new system
                        viewModel: viewModel
                    )
                    .padding(.top, 14)
                    
                    if viewModel.isLoading {
                        // Loading state
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Loading your health data...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else if viewModel.hasHealthKitPermission {
                        // Show health data view when we have permission
                        if viewModel.canShowScores {
                            // Show real health data
                            VStack(spacing: 20) {
                                // Core rings section - Quick Glance at Recovery, Strain, Sleep
                                CoreRingsSection(
                                    recoveryState: viewModel.recoveryScoreState,
                                    sleepState: viewModel.sleepScoreState,
                                    strainState: viewModel.strainScoreState,
                                    coachingMessage: CoachingMessage(
                                        message: viewModel.coachingMessage,
                                        type: .general,
                                        priority: .medium
                                    )
                                )
                                
                                // Health Status Widget (pill track with markers and labels)
                                HealthStatusWidget()
                                    .padding(.horizontal)
                                
                                // Nutrition Section
                                VStack(spacing: 16) {
                                    HStack {
                                        Text("Nutrition")
                                            .font(.headline)
                                        Spacer()
                                    }
                                    .padding(.horizontal)

                                    // Single row: Intake donut left, macros level right
                                    HStack(alignment: .top, spacing: 16) {
                                        // Intake Donut
                                        HStack(spacing: 12) {
                                            let totalTargetKcal: Double = 2200
                                            let consumed = viewModel.todayDietaryEnergy
                                            let pct = max(0, min(consumed / totalTargetKcal, 1)) * 100
                                            CircularProgressRing(
                                                value: pct,
                                                maxValue: 100,
                                                lineWidth: 10,
                                                color: .orange,
                                                showValue: false,
                                                size: 72
                                            )
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(String(format: "%.0f kcal", consumed))
                                                    .font(.system(size: 18, weight: .semibold))
                                                Text("of \(Int(totalTargetKcal))")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .frame(minHeight: 120)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)

                                        // Macros Level Bars
                                        VStack(alignment: .leading, spacing: 10) {
                                            MacroLevelRow(title: "Protein", value: viewModel.todayProteinGrams, target: 120, color: .green)
                                            MacroLevelRow(title: "Carbs", value: viewModel.todayCarbsGrams, target: 250, color: .blue)
                                            MacroLevelRow(title: "Fats", value: viewModel.todayFatGrams, target: 70, color: .orange)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 120)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Bottom spacing
                                Spacer(minLength: 100)
                            }
                        } else if viewModel.errorMessage != nil {
                            // We have permission but there was an error loading data
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                
                                Text("Unable to Load Health Data")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(viewModel.errorMessage ?? "Unknown error occurred")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                
                                Button(action: {
                                    Task {
                                        viewModel.refreshAll()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Try Again")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        } else {
                            // We have permission but no data yet
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                
                                Text("Fetching your health data...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("This may take a moment if you have a lot of health data.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 100)
                        }
                    } else {
                        // No HealthKit permission or no data
                        // Check if we've actually tested permissions vs just starting up
                        let hasTestedPermissions = viewModel.hasAnyData
                        let actuallyDenied = hasTestedPermissions && !viewModel.hasHealthKitPermission
                        
                        VStack(spacing: 24) {
                            Image(systemName: actuallyDenied ? "heart.slash" : "heart.circle")
                                .font(.system(size: 64))
                                .foregroundColor(actuallyDenied ? .red : .secondary)
                            
                            VStack(spacing: 8) {
                                if actuallyDenied {
                                    Text("HealthKit Access Needed")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("To view your health data, please enable HealthKit read permissions in Settings > Health > Data Access & Devices > Bioloop.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                } else {
                                    Text("Connect Your Health Data")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("Grant HealthKit permissions to see your personalized health insights and daily scores.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                            }
                            
                            if actuallyDenied {
                                Button(action: {
                                    // Open Settings app
                                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsURL)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "gear")
                                        Text("Open Settings")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.orange)
                                    .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    print("🔴 Retry HealthKit button pressed!")
                                    Task {
                                        print("🔴 Refreshing permissions status...")
                                        await viewModel.refreshPermissions()
                                        viewModel.refreshAll()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Retry")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            } else {
                                Button(action: {
                                    print("🔴 Connect HealthKit button pressed!")
                                    print("🔴 Current permission status: \(viewModel.hasHealthKitPermission)")
                                    print("🔴 Has any data: \(viewModel.hasAnyData)")
                                    Task {
                                        print("🔴 Calling viewModel.requestHealthKitPermissions()...")
                                        await viewModel.requestHealthKitPermissions()
                                        print("🔴 Permission request flow completed")
                                        print("🔴 New permission status: \(viewModel.hasHealthKitPermission)")
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "heart.fill")
                                        Text("Connect HealthKit")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Bottom spacing
                            Spacer(minLength: 100)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .onAppear {
                print("🏠 HomeView appeared - checking permission status")
                print("   Has HealthKit permission: \(viewModel.hasHealthKitPermission)")

                // Load data asynchronously without blocking UI
                viewModel.refreshAll()
                Task {
                    if HealthKitManager.shared.hasPermission {
                        await HealthKitManager.shared.loadTodayData()
                    }
                }
            }
            .onChange(of: selectedDate) { oldDate, newDate in
                // For now, keep today-only behavior. Optionally refresh data on date change.
                viewModel.refreshAll()
            }
        }
    }
}

// MARK: - MetricCard Component
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Vital Status Card (following existing MetricCard style)
struct VitalStatusCard: View {
    let title: String
    let value: String
    let isInRange: Bool
    let icon: String
    
    private var statusColor: Color {
        if value == "No data" {
            return .secondary
        }
        return isInRange ? .green : .orange
    }
    
    private var statusIcon: String {
        if value == "No data" {
            return "minus.circle"
        }
        return isInRange ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with icon and status
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: statusIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            // Value and title
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(value == "No data" ? .secondary : .primary)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Status bar (like in your screenshot)
            if value != "No data" {
                HStack(spacing: 0) {
                    // Poor section (red/orange)
                    Rectangle()
                        .fill(Color.orange.opacity(isInRange ? 0.2 : 1.0))
                        .frame(height: 4)
                    
                    // Good section (green)
                    Rectangle()
                        .fill(Color.green.opacity(isInRange ? 1.0 : 0.2))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
                .cornerRadius(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Macro Level Row
private struct MacroLevelRow: View {
    let title: String
    let value: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f g", value))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(CGFloat(value/target), 1)) * UIScreen.main.bounds.width * 0.35, height: 8)
                // Healthy range marker (target)
                Capsule()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 2, height: 14)
                    .offset(x: max(0, min(CGFloat(target/target), 1)) * UIScreen.main.bounds.width * 0.35 - 1)
            }
        }
    }
}

// MARK: - Health Status Widget
private struct HealthStatusWidget: View {
    @StateObject private var dm = DataManager.shared

    private struct Vital: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let state: MetricState<Double>
        let healthyRange: ClosedRange<Double>
    }

    private enum VitalState {
        case ok
        case warn
        case missing
    }

    private var vitals: [Vital] {
        return [
            Vital(title: "HRV", icon: "waveform.path.ecg", state: dm.hrvState, healthyRange: healthyRangeForHRV()),
            Vital(title: "RHR", icon: "heart.circle", state: dm.rhrState, healthyRange: healthyRangeForRHR()),
            Vital(title: "Resp", icon: "lungs.fill", state: dm.respState, healthyRange: 12...20),
            Vital(title: "SpO2", icon: "drop.fill", state: dm.spo2State, healthyRange: 95...100),
            Vital(title: "Temp", icon: "thermometer", state: dm.tempState, healthyRange: healthyRangeForTemp())
        ]
    }

    private func healthyRangeForHRV() -> ClosedRange<Double> {
        if let base = dm.baselineHRV {
            let minV = max(20, base.mean - base.stdDev)
            let maxV = min(120, base.mean + base.stdDev)
            if minV < maxV { return minV...maxV }
        }
        return 40...80
    }

    private func healthyRangeForRHR() -> ClosedRange<Double> {
        if let base = dm.baselineRHR {
            let minV = max(40, base.mean - base.stdDev)
            let maxV = min(80, base.mean + base.stdDev)
            if minV < maxV { return minV...maxV }
        }
        return 50...65
    }

    private func healthyRangeForTemp() -> ClosedRange<Double> {
        // If we have a valid temp and it's likely a wrist delta (small magnitude), center near 0
        if case .valid(let v, _) = dm.tempState, abs(v) < 5 {
            return -0.5...0.5
        }
        return 36.1...37.6
    }
    
    private func calculateYOffset(for vital: Vital, index: Int) -> CGFloat {
        guard case .valid(let value, _) = vital.state else { return 0 }
        let maxOffset: CGFloat = 45
        var normalizedPosition = normalizeValueClamped(value, healthy: vital.healthyRange, maxDeviationFactor: 2.0)
        // Direction tweaks: for RHR, lower is better so invert vertical sense (lower-than-center should go up)
        if vital.title == "RHR" {
            normalizedPosition = -normalizedPosition
        }
        return CGFloat(normalizedPosition) * maxOffset
    }
    
    private func normalizeValueClamped(_ value: Double, healthy: ClosedRange<Double>, maxDeviationFactor: Double) -> Double {
        let minHealthy = healthy.lowerBound
        let maxHealthy = healthy.upperBound
        guard minHealthy < maxHealthy else { return 0 }
        let center = (minHealthy + maxHealthy) / 2.0
        let halfBand = (maxHealthy - minHealthy) / 2.0
        let maxDev = halfBand * Swift.max(0.1, maxDeviationFactor)
        let deviation = value - center
        let normalized = deviation / maxDev
        // Inversion: higher-than-center -> positive offset (up), lower -> negative
        return Swift.max(-1.0, Swift.min(1.0, normalized))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Health")
                    .font(.headline)
                Spacer()
            }
            // Track with overlays
            ZStack {
                VStack(spacing: 4) {
                    // Upper limit line
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray4))
                        .frame(height: 6)
                    
                    // Green healthy zone
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.92), Color.green.opacity(0.75)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 80)
                    
                    // Lower limit line
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray4))
                        .frame(height: 6)
                }
                // Markers positioned by value
                HStack {
                    ForEach(Array(vitals.enumerated()), id: \.element.id) { index, v in
                        let state: VitalState = {
                            switch v.state {
                            case .valid(let val, _):
                                return v.healthyRange.contains(val) ? .ok : .warn
                            case .stale:
                                return .missing
                            case .missing:
                                return .missing
                            }
                        }()
                        let yOffset = calculateYOffset(for: v, index: index)
                        ZStack {
                            Circle()
                                .fill(state == .ok ? Color.green : (state == .warn ? Color.red : Color(.systemGray3)))
                                .frame(width: 32, height: 32)
                                .shadow(color: state == .ok ? Color.green.opacity(0.6) : (state == .warn ? Color.red.opacity(0.5) : .clear), radius: 8, x: 0, y: 0)
                            Image(systemName: state == .ok ? "checkmark" : (state == .warn ? "plus" : "xmark"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(state == .missing ? .black.opacity(0.8) : .white)
                        }
                        .offset(y: yOffset)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 6)
            }
            .padding(.vertical, 2)

            // Labels row
            HStack {
                ForEach(vitals) { v in
                    let state: VitalState = {
                        switch v.state {
                        case .valid(let val, _):
                            return v.healthyRange.contains(val) ? .ok : .warn
                        case .stale:
                            return .missing
                        case .missing:
                            return .missing
                        }
                    }()
                    VStack(spacing: 6) {
                        Image(systemName: v.icon)
                            .foregroundColor(state == .ok ? .primary : (state == .warn ? .red : .secondary))
                        Text(v.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(state == .ok ? .primary : (state == .warn ? .red : .secondary))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Nutrition Card (following existing MetricCard style)
struct NutritionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Macro Card (following existing MetricCard style)
struct MacroCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
