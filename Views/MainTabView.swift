import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var appearanceManager = AppearanceManager.shared
    
    var body: some View {
        ZStack {
            // Main content without TabView
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    FitnessView()
                case 2:
                    BiologyView()
                default:
                    HomeView()
                }
            }
            
            // Custom floating navigation bar
            VStack {
                Spacer()
                
                // Floating navigation bar with frosted glass effect
                HStack(spacing: 0) {
                    // Home tab
                    Button(action: { selectedTab = 0 }) {
                        VStack(spacing: 4) {
                            Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                                .font(.system(size: 20, weight: selectedTab == 0 ? .semibold : .regular))
                                .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                            Text("Home")
                                .font(.system(size: 10, weight: selectedTab == 0 ? .semibold : .regular))
                                .foregroundColor(selectedTab == 0 ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    
                    // Fitness tab
                    Button(action: { selectedTab = 1 }) {
                        VStack(spacing: 4) {
                            Image(systemName: selectedTab == 1 ? "figure.run" : "figure.run")
                                .font(.system(size: 20, weight: selectedTab == 1 ? .semibold : .regular))
                                .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                            Text("Fitness")
                                .font(.system(size: 10, weight: selectedTab == 1 ? .semibold : .regular))
                                .foregroundColor(selectedTab == 1 ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    
                    // Biology tab
                    Button(action: { selectedTab = 2 }) {
                        VStack(spacing: 4) {
                            Image(systemName: selectedTab == 2 ? "heart.fill" : "heart")
                                .font(.system(size: 20, weight: selectedTab == 2 ? .semibold : .regular))
                                .foregroundColor(selectedTab == 2 ? .primary : .secondary)
                            Text("Biology")
                                .font(.system(size: 10, weight: selectedTab == 2 ? .semibold : .regular))
                                .foregroundColor(selectedTab == 2 ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            // Reset to home tab when view appears
            selectedTab = 0
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Handle tab selection
            print("Selected tab: \(newValue)")
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
