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
                        userProfile: viewModel.userProfile,
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
                    } else {
                        // Always show the main content - either real data or sample data
                        VStack(spacing: 20) {
                            // Core rings section
                            CoreRingsSection(
                                recoveryScore: viewModel.currentHealthScore?.recovery.value ?? 95,
                                sleepScore: viewModel.currentHealthScore?.sleep.value ?? 73,
                                strainScore: viewModel.currentHealthScore?.strain.value ?? 25,
                                coachingMessage: viewModel.coachingMessage
                            )
                            
                            // Stress & Energy section
                            StressEnergySection(
                                stressMetrics: viewModel.stressMetrics,
                                energyLevel: viewModel.energyLevel
                            )
                            
                            // Nutrition section
                            NutritionSection(
                                nutritionData: viewModel.nutritionData
                            )
                            
                            // Bottom spacing
                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .onAppear {
                print("🏠 HomeView appeared - checking permission status")
                print("   Has HealthKit permission: \(viewModel.hasHealthKitPermission)")

                // Load data asynchronously without blocking UI
                Task {
                    await viewModel.loadHealthData(for: selectedDate)
                }
            }
            .onChange(of: selectedDate) { oldDate, newDate in
                Task {
                    await viewModel.loadHealthData(for: newDate)
                }
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
