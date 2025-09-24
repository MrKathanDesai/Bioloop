import SwiftUI

struct HealthDataDiagnosticsView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var viewModel = HomeViewModel.shared
    @StateObject private var hkManager = HealthKitManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Health Data Diagnostics")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Real-time data flow monitoring")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Authorization Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Authorization Status")
                            .font(.headline)
                        
                        HStack {
                            Circle()
                                .fill(dataManager.hasHealthKitPermission ? .green : .red)
                                .frame(width: 12, height: 12)
                            Text("HealthKit Permission: \(dataManager.hasHealthKitPermission ? "✅ Granted" : "❌ Denied")")
                        }
                        
                        if let error = dataManager.errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Today's Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Metrics")
                            .font(.headline)
                        
                        MetricRow(label: "Steps", value: dataManager.todaySteps.formatted())
                        MetricRow(label: "Heart Rate", value: dataManager.todayHeartRate > 0 ? "\(Int(dataManager.todayHeartRate)) BPM" : "—")
                        MetricRow(label: "Active Energy", value: "\(Int(dataManager.todayActiveEnergy)) cal")
                        MetricRow(label: "Sleep", value: dataManager.todaySleepHours > 0 ? String(format: "%.1f hrs", dataManager.todaySleepHours) : "—")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Biology Metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Biology Metrics (Latest)")
                            .font(.headline)
                        
                        MetricRow(label: "VO₂ Max", value: dataManager.latestVO2Max != nil ? String(format: "%.1f ml/kg/min", dataManager.latestVO2Max!) : "—")
                        MetricRow(label: "HRV", value: dataManager.latestHRV != nil ? String(format: "%.1f ms", dataManager.latestHRV!) : "—")
                        MetricRow(label: "Resting HR", value: dataManager.latestRHR != nil ? "\(Int(dataManager.latestRHR!)) BPM" : "—")
                        MetricRow(label: "Weight", value: dataManager.latestWeight != nil ? String(format: "%.1f kg", dataManager.latestWeight!) : "—")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Data Series Counts
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Series (30-day)")
                            .font(.headline)
                        
                        MetricRow(label: "VO₂ Max Points", value: "\(dataManager.vo2MaxSeries.count)")
                        MetricRow(label: "HRV Points", value: "\(dataManager.hrvSeries.count)")
                        MetricRow(label: "RHR Points", value: "\(dataManager.rhrSeries.count)")
                        MetricRow(label: "Weight Points", value: "\(dataManager.weightSeries.count)")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Computed Scores
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Computed Scores")
                            .font(.headline)
                        
                        MetricRow(label: "Recovery Score", value: scoreText(viewModel.recoveryScoreState))
                        MetricRow(label: "Sleep Score", value: scoreText(viewModel.sleepScoreState))
                        MetricRow(label: "Strain Score", value: scoreText(viewModel.strainScoreState))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button("Refresh All Data") {
                            dataManager.refreshAll()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Request Permissions") {
                            Task {
                                await dataManager.requestHealthKitPermissions()
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Refresh Permissions") {
                            Task {
                                await dataManager.refreshPermissions()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    
                    // Debug Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Debug Info")
                            .font(.headline)
                        
                        Text("Last Updated: \(Date(), formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Data Manager: \(dataManager.hasBiologyData ? "Has Biology Data" : "No Biology Data")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Today Data: \(dataManager.hasTodayData ? "Has Today Data" : "No Today Data")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Diagnostics")
            .onAppear {
                print("🔍 Diagnostics view appeared")
            }
        }
    }

    private func scoreText(_ state: HomeViewModel.ScoreState) -> String {
        switch state {
        case .pending: return "pending"
        case .unavailable: return "—"
        case .computed(let v): return String(v)
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    HealthDataDiagnosticsView()
}
