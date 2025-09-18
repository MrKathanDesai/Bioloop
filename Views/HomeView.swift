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
                                    recoveryScore: Double(viewModel.recoveryScore),
                                    sleepScore: Double(viewModel.sleepScore),
                                    strainScore: Double(viewModel.strainScore),
                                    coachingMessage: CoachingMessage(
                                        message: viewModel.coachingMessage,
                                        type: .general,
                                        priority: .medium
                                    )
                                )
                                
                                // Vitals Status Section
                                VStack(spacing: 16) {
                                    HStack {
                                        Text("Health")
                                            .font(.headline)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    
                                    // Show vitals status using existing MetricCard style
                                    VStack(spacing: 12) {
                                        HStack(spacing: 20) {
                                            VitalStatusCard(
                                                title: "HRV",
                                                value: DataManager.shared.hasDisplayableHRV ? String(format: "%.1f ms", DataManager.shared.latestHRV!) : "No data",
                                                isInRange: DataManager.shared.hasRecentHRV && (DataManager.shared.latestHRV ?? 0) > 30,
                                                icon: "waveform.path.ecg"
                                            )
                                            
                                            VitalStatusCard(
                                                title: "RHR",
                                                value: DataManager.shared.hasDisplayableRHR ? String(format: "%.0f bpm", DataManager.shared.latestRHR!) : "No data",
                                                isInRange: DataManager.shared.hasRecentRHR && (DataManager.shared.latestRHR ?? 0) < 70,
                                                icon: "heart.fill"
                                            )
                                        }
                                        .padding(.horizontal)
                                        
                                        HStack(spacing: 20) {
                                            VitalStatusCard(
                                                title: "Resp",
                                                value: DataManager.shared.todayRespiratoryRate > 0 ? String(format: "%.0f bpm", DataManager.shared.todayRespiratoryRate) : "No data",
                                                isInRange: DataManager.shared.todayRespiratoryRate > 0 && DataManager.shared.todayRespiratoryRate >= 10 && DataManager.shared.todayRespiratoryRate <= 20,
                                                icon: "lungs.fill"
                                            )
                                            
                                            VitalStatusCard(
                                                title: "SpO2",
                                                value: DataManager.shared.todaySpO2Percent > 0 ? String(format: "%.0f%%", DataManager.shared.todaySpO2Percent) : "No data",
                                                isInRange: DataManager.shared.todaySpO2Percent >= 95,
                                                icon: "drop.fill"
                                            )
                                        }
                                        .padding(.horizontal)
                                        
                                        HStack(spacing: 20) {
                                            VitalStatusCard(
                                                title: "Temp",
                                                value: DataManager.shared.todayBodyTemperatureC > 0 ? String(format: "%.1f°C", DataManager.shared.todayBodyTemperatureC) : "No data",
                                                isInRange: DataManager.shared.todayBodyTemperatureC > 0 && DataManager.shared.todayBodyTemperatureC >= 35.5 && DataManager.shared.todayBodyTemperatureC <= 37.8,
                                                icon: "thermometer"
                                            )
                                            
                                            VitalStatusCard(
                                                title: "Intake",
                                                value: DataManager.shared.todayDietaryEnergy > 0 ? String(format: "%.0f kcal", DataManager.shared.todayDietaryEnergy) : "No data",
                                                isInRange: true,
                                                icon: "fork.knife"
                                            )
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Nutrition Section
                                VStack(spacing: 16) {
                                    HStack {
                                        Text("Nutrition")
                                            .font(.headline)
                                        Spacer()
                                    }
                                    .padding(.horizontal)

                                    // Single row: Intake donut left, macros level right
                                    HStack(spacing: 16) {
                                        // Intake Donut
                                        HStack(spacing: 12) {
                                            let totalTargetKcal: Double = 2200
                                            let consumed = DataManager.shared.todayDietaryEnergy
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
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)

                                        // Macros Level Bars
                                        VStack(alignment: .leading, spacing: 10) {
                                            MacroLevelRow(title: "Protein", value: DataManager.shared.todayProteinGrams, target: 120, color: .green)
                                            MacroLevelRow(title: "Carbs", value: DataManager.shared.todayCarbsGrams, target: 250, color: .blue)
                                            MacroLevelRow(title: "Fats", value: DataManager.shared.todayFatGrams, target: 70, color: .orange)
                                        }
                                        .frame(maxWidth: .infinity)
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
            }
            .onChange(of: selectedDate) { oldDate, newDate in
                // Refresh data when date changes
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
