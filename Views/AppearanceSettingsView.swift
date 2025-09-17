import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Appearance")) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text(mode.displayName)
                            
                            Spacer()
                            
                            if appearanceManager.currentMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appearanceManager.setAppearance(mode)
                        }
                    }
                }
                
                Section(footer: Text("Choose how Bioloop looks. System will follow your device settings.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AccountMenuView: View {
    @ObservedObject var appearanceManager: AppearanceManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAppearanceSettings = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("KD")
                                .font(.headline)
                            Text("Kathan Desai")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Settings") {
                    Button(action: {
                        showingAppearanceSettings = true
                    }) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            Text("Appearance")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAppearanceSettings) {
            AppearanceSettingsView(appearanceManager: appearanceManager)
        }
    }
} 