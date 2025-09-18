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
                                // Core rings section
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
                                
                                // Simple metrics display
                                VStack(spacing: 16) {
                                    Text("Today's Metrics")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 20) {
                                        MetricCard(
                                            title: "Steps",
                                            value: viewModel.formattedSteps,
                                            icon: "figure.walk"
                                        )
                                        
                                        MetricCard(
                                            title: "Heart Rate",
                                            value: viewModel.formattedHeartRate + " BPM",
                                            icon: "heart.fill"
                                        )
                                    }
                                    .padding(.horizontal)
                                    
                                    HStack(spacing: 20) {
                                        MetricCard(
                                            title: "Active Energy",
                                            value: viewModel.formattedActiveEnergy + " cal",
                                            icon: "flame.fill"
                                        )
                                        
                                        MetricCard(
                                            title: "Sleep",
                                            value: viewModel.formattedSleepHours + " hrs",
                                            icon: "moon.fill"
                                        )
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
