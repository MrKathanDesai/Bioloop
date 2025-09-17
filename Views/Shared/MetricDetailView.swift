import SwiftUI

struct MetricDetailView: View {
    let metric: BiologyMetric
    @Environment(\.presentationMode) var presentationMode
    @State private var historicalData: [DayData] = []
    @State private var isLoadingHistoricalData = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with metric value
                    headerSection
                    
                    // Status and trend
                    statusSection
                    
                    // Explanation
                    explanationSection
                    
                    // Historical trend
                    trendSection
                    
                    // Recommendations
                    recommendationsSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle(metric.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .padding(.top)
        .onAppear {
            loadHistoricalData()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: metric.icon)
                .font(.system(size: 60))
                .foregroundColor(metric.color)
            
            // Value
            HStack(alignment: .bottom, spacing: 8) {
                Text(metric.displayValue)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(metric.unit)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    private var statusSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(metric.statusColor)
                        .frame(width: 12, height: 12)
                    
                    Text(metric.status)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(metric.statusColor)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text("7-Day Trend")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: metric.trendIcon)
                        .font(.caption)
                        .foregroundColor(metric.trendColor)
                    
                    Text(metric.trendText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(metric.trendColor)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About \(metric.name)")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(metric.explanation)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-Day History")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Enhanced trend chart with better data
            if metric.isDataAvailable && !historicalData.isEmpty {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(historicalData.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(metric.color)
                                .frame(width: 24, height: CGFloat(value.normalized * 80))
                            
                            VStack(spacing: 2) {
                                Text(value.displayValue)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Today")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Show placeholder bars for missing historical data
                    ForEach(1..<7) { index in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(width: 24, height: 20)
                            
                            VStack(spacing: 2) {
                                Text("--")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text(dayAbbreviation(for: 7 - index))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 120)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    VStack(spacing: 4) {
                        Text("No Data Available")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Historical trends will appear here once you have HealthKit data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
            
            // Trend summary
            HStack {
                Image(systemName: trendIcon)
                    .font(.caption)
                    .foregroundColor(trendColor)
                
                Text(trendSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(metric.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.top, 2)
                        
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                        
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func dayAbbreviation(for index: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        let targetDate = calendar.date(byAdding: .day, value: index - 6, to: today) ?? today
        
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: targetDate)
    }
    
    private struct DayData {
        let value: Double
        let normalized: Double
        let displayValue: String
    }
    
    private func generateRealistic7DayData() -> [DayData] {
        // Only show current data if available
        guard metric.isDataAvailable else {
            // Return empty data to show "no data available" state
            return []
        }
        
        // Only return current value - no historical data simulation
        // Historical data would require proper HealthKit historical queries
        let currentValue = metric.value
        let displayValue: String
        
        if metric.unit == "kg" {
            displayValue = String(format: "%.1f", currentValue)
        } else if metric.unit == "bpm" || metric.unit == "ms" {
            displayValue = String(format: "%.0f", currentValue)
        } else {
            displayValue = String(format: "%.1f", currentValue)
        }
        
        // Return only today's data point - no fake historical data
        return [DayData(value: currentValue, normalized: 0.5, displayValue: displayValue)]
    }
    
    private var trendIcon: String {
        guard metric.isDataAvailable else { return "minus" }
        
        // Since we only have current data, show stable trend
        return "minus"
    }
    
    private var trendColor: Color {
        guard metric.isDataAvailable else { return .secondary }
        
        // Since we only have current data, show neutral color
        return .secondary
    }
    
    private var trendSummary: String {
        guard metric.isDataAvailable else { 
            return "No trend data available - need more HealthKit data"
        }
        
        // Since we only have current data, explain the limitation
        return "Current value recorded - historical trends require more data collection"
    }
    
    // MARK: - Historical Data Loading
    private func loadHistoricalData() {
        guard metric.isDataAvailable else {
            historicalData = []
            return
        }
        
        isLoadingHistoricalData = true
        
        Task {
            var weekData: [DayData] = []
            let calendar = Calendar.current
            
            // Get data for the past 7 days
            for dayOffset in 0..<7 {
                if let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) {
                    // For now, we only have current day data
                    // In a full implementation, this would fetch historical metrics from HealthKit
                    if calendar.isDateInToday(targetDate) {
                        let displayValue: String
                        if metric.unit == "kg" {
                            displayValue = String(format: "%.1f", metric.value)
                        } else if metric.unit == "bpm" || metric.unit == "ms" {
                            displayValue = String(format: "%.0f", metric.value)
                        } else {
                            displayValue = String(format: "%.1f", metric.value)
                        }
                        
                        weekData.append(DayData(value: metric.value, normalized: 0.5, displayValue: displayValue))
                    } else {
                        // No historical data available yet - would need HealthKit historical queries
                        // For now, skip historical days to avoid fake data
                    }
                }
            }
            
            await MainActor.run {
                historicalData = weekData.reversed() // Show oldest to newest
                isLoadingHistoricalData = false
            }
        }
    }
}

// MARK: - Biology Metric Model
struct BiologyMetric {
    let name: String
    let value: Double
    let unit: String
    let icon: String
    let color: Color
    let status: String
    let statusColor: Color
    let explanation: String
    let recommendations: [String]
    let weeklyData: [Double]
    let maxValue: Double
    let isDataAvailable: Bool
    
    var displayValue: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    var trendIcon: String {
        let recentAverage = weeklyData.suffix(3).reduce(0, +) / 3
        let previousAverage = weeklyData.prefix(4).reduce(0, +) / 4
        
        if recentAverage > previousAverage * 1.05 {
            return "arrow.up.right"
        } else if recentAverage < previousAverage * 0.95 {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }
    
    var trendColor: Color {
        let recentAverage = weeklyData.suffix(3).reduce(0, +) / 3
        let previousAverage = weeklyData.prefix(4).reduce(0, +) / 4
        
        // For most metrics, higher is better
        if recentAverage > previousAverage * 1.05 {
            return .green
        } else if recentAverage < previousAverage * 0.95 {
            return .red
        } else {
            return .gray
        }
    }
    
    var trendText: String {
        let recentAverage = weeklyData.suffix(3).reduce(0, +) / 3
        let previousAverage = weeklyData.prefix(4).reduce(0, +) / 4
        let percentChange = abs((recentAverage - previousAverage) / previousAverage * 100)
        
        if recentAverage > previousAverage * 1.05 {
            return "+\(String(format: "%.1f", percentChange))%"
        } else if recentAverage < previousAverage * 0.95 {
            return "-\(String(format: "%.1f", percentChange))%"
        } else {
            return "Stable"
        }
    }
}