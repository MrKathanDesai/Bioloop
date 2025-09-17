import SwiftUI

@main
struct BioloopApp: App {
    @StateObject private var appearanceManager = AppearanceManager.shared
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(appearanceManager.colorScheme)
        }
    }
}

struct AppRootView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var appearanceManager = AppearanceManager.shared
    @State private var hasCompletedOnboarding = false

    var body: some View {
        VStack {
            if hasCompletedOnboarding {
                // Main app with tab navigation
                MainTabView()
            } else {
                // Simple onboarding
                SimpleOnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                })
            }
        }
        .onAppear {
            // Check if onboarding was completed
            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
    }
}

// MARK: - Simple Onboarding

struct SimpleOnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Welcome content
            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("Welcome to Bioloop")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your personal health optimization companion")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Track your recovery, sleep, strain, and stress scores using your Apple Watch data.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Get Started button
            Button(action: onComplete) {
                Text("Get Started")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

// MARK: - Preview

struct SimpleBioloopApp_Previews: PreviewProvider {
    static var previews: some View {
        AppRootView()
    }
}
