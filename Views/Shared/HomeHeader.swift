import SwiftUI

// Import the MonthlyCalendarView

struct HomeHeader: View {
    @Binding var selectedDate: Date
    let userProfile: UserProfile?
    let viewModel: HomeViewModel
    @StateObject private var appearanceManager = AppearanceManager.shared
    @State private var showingAppearanceToggle = false
    @State private var showingCalendar = false
    
    var body: some View {
        HStack {
            // Date selector
            Button(action: {
                showingCalendar.toggle()
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text("Today")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Profile badge with appearance toggle
            Button(action: {
                showingAppearanceToggle.toggle()
            }) {
                ZStack {
                    Circle()
                        .fill(Color(.systemBlue).opacity(0.2))
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    Image(systemName: appearanceManager.currentMode.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .sheet(isPresented: $showingAppearanceToggle) {
            AppearanceToggleView(appearanceManager: appearanceManager)
        }
        .sheet(isPresented: $showingCalendar) {
            MonthlyCalendarView(selectedDate: $selectedDate, viewModel: viewModel)
        }
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: selectedDate)
    }
}

// MARK: - Appearance Toggle View
struct AppearanceToggleView: View {
    @ObservedObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Appearance")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose how Bioloop looks")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.horizontal, 20)
                
                // Appearance options
                VStack(spacing: 12) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        AppearanceOptionRow(
                            mode: mode,
                            isSelected: appearanceManager.currentMode == mode,
                            onTap: {
                                appearanceManager.setAppearance(mode)
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                
                Spacer()
                
                // Done button
                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Appearance Option Row
struct AppearanceOptionRow: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: mode.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .frame(width: 24)
                
                // Text
                Text(mode.displayName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HomeHeader_Previews: PreviewProvider {
    static var previews: some View {
        HomeHeader(
            selectedDate: .constant(Date()),
            userProfile: UserProfile(initials: "KD", name: "Katharine Desai"),
            viewModel: HomeViewModel.shared
        )
        .previewLayout(.sizeThatFits)
    }
}
