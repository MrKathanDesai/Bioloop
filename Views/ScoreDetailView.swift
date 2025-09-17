import SwiftUI
import HealthKit

// Extension to convert ScoreStatus to HealthStatus
extension HealthScore.ScoreStatus {
    var toHealthStatus: HealthStatus {
        switch self {
        case .optimal:
            return .optimal
        case .moderate:
            return .moderate
        case .poor:
            return .poor
        case .unavailable:
            return .unavailable
        }
    }
}

struct ScoreDetailView: View {
    let scoreType: HealthScoreType
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeRange: TimeRange = .sevenDays
    
    enum TimeRange: String, CaseIterable {
        case sevenDays = "7D"
        case thirtyDays = "30D"
        case ninetyDays = "90D"
        
        var title: String {
            switch self {
            case .sevenDays: return "7 Days"
            case .thirtyDays: return "30 Days"
            case .ninetyDays: return "90 Days"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Large Score Display
                    scoreHeaderSection
                    
                    // Explanation Section
                    explanationSection
                    
                    // Sub-metrics Section
                    if let score = viewModel.getScoreForType(scoreType), score.isDataAvailable, let subMetrics = score.subMetrics {
                        let subMetricArray = subMetrics.map { SubMetric(name: $0.key, value: $0.value, unit: nil, status: nil, optimalRange: nil) }
                        subMetricsSection(subMetricArray)
                    }
                    
                    // Chart Section
                    chartSection
                    
                    // AI Insights Section (placeholder)
                    aiInsightsSection
                }
                .padding()
            }
            .navigationTitle(scoreType.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Score Header Section
    private var scoreHeaderSection: some View {
        VStack(spacing: 16) {
            // Large icon and score
            VStack(spacing: 12) {
                Image(systemName: scoreType.icon)
                    .font(.system(size: 60))
                    .foregroundColor(statusColor)
                
                if let score = viewModel.getScoreForType(scoreType), score.isDataAvailable {
                    VStack(spacing: 4) {
                        HStack(alignment: .bottom, spacing: 8) {
                            Text("\(Int(score.value))")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(statusColor)
                            
                            Text("/100")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 12)
                        }
                        
                        statusBadge(score.status.toHealthStatus)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Data Unavailable")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("Enable Health data access to see your \(scoreType.rawValue.lowercased()) score")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            // Last updated - removed for now as component doesn't have date info
            // TODO: Add date tracking to ScoreComponent if needed
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(statusColor.opacity(0.1))
        )
    }
    
    // MARK: - Status Color
    private var statusColor: Color {
        guard let score = viewModel.getScoreForType(scoreType) else { return .gray }
        
        switch score.status {
        case .optimal:
            return .green
        case .moderate:
            return .orange
        case .poor:
            return .red
        case .unavailable:
            return .gray
        }
    }
    
    // MARK: - Status Badge
    private func statusBadge(_ status: HealthStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            Text(statusText(status))
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
    }
    
    private func statusText(_ status: HealthStatus) -> String {
        switch status {
        case .optimal:
            return "Optimal Range"
        case .moderate:
            return "Good Range"
        case .poor:
            return "Needs Attention"
        case .critical:
            return "Critical - Action Needed"
        case .unavailable:
            return "No Data"
        }
    }
    
    // MARK: - Explanation Section
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What This Means")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(scoreType.detailExplanation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Sub-metrics Section
    private func subMetricsSection(_ subMetrics: [SubMetric]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(subMetrics.enumerated()), id: \.offset) { _, metric in
                    SubMetricCard(metric: metric)
                }
            }
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trend Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            // Chart placeholder
            chartPlaceholder
        }
    }
    
    private var chartPlaceholder: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text("Chart Coming Soon")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Historical \(scoreType.rawValue.lowercased()) data will be displayed here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                )
            
            // Chart legend placeholder
            HStack {
                Text("▲ Trending up compared to last week")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
            }
        }
    }
    
    // MARK: - AI Insights Section
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                
                Text("AI Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InsightRow(
                    icon: "lightbulb.fill",
                    color: .blue,
                    text: getAIInsight()
                )
                
                if let recommendation = getRecommendation() {
                    InsightRow(
                        icon: "target",
                        color: .orange,
                        text: recommendation
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private func getAIInsight() -> String {
        guard let score = viewModel.getScoreForType(scoreType), score.isDataAvailable else {
            return "Enable Health data access to receive personalized insights"
        }
        
        switch scoreType {
        case .recovery:
            if score.value >= 80 {
                return "Your recovery is excellent. This is a great day for intense training."
            } else if score.value >= 60 {
                return "Your recovery is moderate. Consider lighter activity today."
            } else {
                return "Your recovery is low. Focus on rest and stress management."
            }
            
        case .sleep:
            if score.value >= 80 {
                return "Your sleep quality is excellent and supporting your health goals."
            } else if score.value >= 60 {
                return "Your sleep is decent but could be optimized for better recovery."
            } else {
                return "Your sleep quality needs attention. Consider improving your sleep environment."
            }
            
        case .strain:
            if score.value >= 80 {
                return "You're maintaining an optimal training load for your fitness level."
            } else if score.value >= 60 {
                return "Your training load is moderate. Consider gradually increasing intensity."
            } else {
                return "Your activity level is low. Try to incorporate more movement into your day."
            }
            
        case .stress:
            if score.value >= 80 {
                return "Your stress levels are well-managed. Keep up your healthy habits."
            } else if score.value >= 60 {
                return "Moderate stress detected. Consider practicing breathing exercises."
            } else {
                return "High stress levels detected. Focus on stress reduction techniques."
            }
        }
    }
    
    private func getRecommendation() -> String? {
        guard let score = viewModel.getScoreForType(scoreType), score.isDataAvailable else { return nil }
        
        switch scoreType {
        case .recovery:
            if score.value < 60 {
                return "Try a cold shower or ice bath to boost recovery"
            }
        case .sleep:
            if score.value < 70 {
                return "Aim for 7-9 hours of sleep and avoid screens 1 hour before bed"
            }
        case .strain:
            if score.value < 50 {
                return "Try a 20-minute walk or light workout today"
            }
        case .stress:
            if score.value < 70 {
                return "Practice 5 minutes of deep breathing exercises"
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Sub Metric Card
struct SubMetricCard: View {
    let metric: SubMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if metric.isDataAvailable {
                HStack(alignment: .bottom, spacing: 4) {
                    Text(formatValue(metric.value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let unit = metric.unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Optimal range indicator
                if let range = metric.optimalRange {
                    OptimalRangeIndicator(
                        value: metric.value,
                        range: range
                    )
                }
            } else {
                Text("No data")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Optimal Range Indicator
struct OptimalRangeIndicator: View {
    let value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray4))
                        .frame(height: 4)
                    
                    // Optimal range
                    let rangeWidth = geometry.size.width * 0.6 // Assume optimal range is 60% of total
                    let rangeStart = geometry.size.width * 0.2 // Start at 20% of total width
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.3))
                        .frame(width: rangeWidth, height: 4)
                        .offset(x: rangeStart)
                    
                    // Current value indicator
                    let normalizedValue = min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
                    let indicatorPosition = rangeStart + (normalizedValue * rangeWidth)
                    
                    Circle()
                        .fill(isInOptimalRange ? .green : .orange)
                        .frame(width: 8, height: 8)
                        .offset(x: indicatorPosition - 4)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("Optimal: \(Int(range.lowerBound))-\(Int(range.upperBound))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(isInOptimalRange ? "✓" : "!")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(isInOptimalRange ? .green : .orange)
            }
        }
    }
    
    private var isInOptimalRange: Bool {
        range.contains(value)
    }
}

// MARK: - Insight Row
struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(2)
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct ScoreDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreDetailView(
            scoreType: .recovery,
            viewModel: HomeViewModel()
        )
    }
} 