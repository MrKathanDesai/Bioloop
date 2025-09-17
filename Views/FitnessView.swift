import SwiftUI
import Charts

struct FitnessView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section with improved spacing and typography
                    VStack(spacing: 8) {
                        Text("Fitness")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Last 30 days")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    
                    // Calendar Heatmap Card
                    CalendarHeatmapCard()
                        .padding(.horizontal, 20)
                    
                    // Activity Summary Graph Card
                    ActivitySummaryCard()
                        .padding(.horizontal, 20)
                    
                    // Strain Performance Card
                    StrainPerformanceCard()
                        .padding(.horizontal, 20)
                    
                    // Bottom spacing
                    Spacer(minLength: 100)
                }
                .frame(maxWidth: geometry.size.width)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
}

// MARK: - Calendar Heatmap Card
struct CalendarHeatmapCard: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                // July Calendar
                VStack(spacing: 12) {
                    Text("Jul 2025")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Days of week header
                    HStack(spacing: 6) {
                        ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                            Text(day)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                        }
                    }
                    
                    // July calendar grid - proper week-based layout
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                        // July starts on a Tuesday, so we need to offset the first week
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.clear)
                                .frame(width: 24, height: 24)
                        }
                        
                        // July days (1-31)
                        ForEach(1...31, id: \.self) { day in
                            let activityCount = julyActivityCount(for: day)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5)) // Default gray background
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(activityTint(for: activityCount))
                                )
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                
                // August Calendar
                VStack(spacing: 12) {
                    Text("Aug 2025")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Days of week header
                    HStack(spacing: 6) {
                        ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                            Text(day)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                        }
                    }
                    
                    // August calendar grid - proper week-based layout
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                        // August starts on a Friday, so we need to offset the first week
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.clear)
                                .frame(width: 24, height: 24)
                        }
                        
                        // August days (1-30)
                        ForEach(1...30, id: \.self) { day in
                            let activityCount = augustActivityCount(for: day)
                            let isToday = day == 6 // Current day (Aug 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5)) // Default gray background
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(activityTint(for: activityCount))
                                )
                                .overlay(
                                    Group {
                                        if isToday {
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.accentColor, lineWidth: 2)
                                        }
                                    }
                                )
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            
            // Clear legend explaining the activity levels
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 12, height: 12)
                    Text("1 activity")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.teal.opacity(0.7))
                        .frame(width: 12, height: 12)
                    Text("2 activities")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 12, height: 12)
                    Text("3+ activities")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 12)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // Clear activity count function for July
    private func julyActivityCount(for day: Int) -> Int {
        // Simulate realistic activity patterns for July
        let activities = [
            1, 2, 1, 3, 2, 1, 2, 3, 1, 2, 1, 3, 2, 1, 2, 3, 1, 2, 1, 3, 2, 1, 2, 3, 1, 2, 1, 3, 2, 1, 2
        ]
        return activities[day - 1]
    }
    
    // Clear activity count function for August
    private func augustActivityCount(for day: Int) -> Int {
        // Simulate realistic activity patterns for August
        if day <= 7 {
            // First week: some activity
            let activities = [1, 2, 1, 3, 2, 1, 2]
            return activities[day - 1]
        } else {
            // Rest of August: mostly inactive (realistic for future dates)
            return 0
        }
    }
    
    // Clear activity tint function with meaningful color progression
    private func activityTint(for count: Int) -> Color {
        switch count {
        case 1: return Color.green.opacity(0.6)      // Light green for 1 activity
        case 2: return Color.teal.opacity(0.7)       // Teal for 2 activities
        case 3...: return Color.blue.opacity(0.8)    // Blue for 3+ activities
        default: return Color.clear                   // No overlay for inactive days
        }
    }
}

// MARK: - Activity Summary Card
struct ActivitySummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "grid")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Text("Activity Summary")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("53m")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Jul 31 - Aug 30, 2025")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("8h 44m")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Activity Chart with responsive sizing
            VStack(spacing: 8) {
                Chart {
                    ForEach(activityData, id: \.date) { data in
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Activity", data.activity)
                        )
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Highlight the final point
                    if let lastData = activityData.last {
                        PointMark(
                            x: .value("Date", lastData.date),
                            y: .value("Activity", lastData.activity)
                        )
                        .foregroundStyle(Color.orange)
                        .symbolSize(30)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120) // Reduced height to match design
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month().day())
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundColor(.primary.opacity(0.4))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 11]) { value in
                        AxisValueLabel {
                            Text("\(value.index)")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.primary.opacity(0.4))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16) // Reduced from 22
                .fill(Color(.systemBackground))
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 8, x: 0, y: 2) // Reduced shadow
        )
    }
    
    private var activityData: [ActivityData] {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 31))!
        let endDate = calendar.date(from: DateComponents(year: 2025, month: 8, day: 30))!
        
        var data: [ActivityData] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dayOffset = calendar.dateComponents([.day], from: startDate, to: currentDate).day ?? 0
            let activity = max(0, 11 - dayOffset) // Decreasing activity
            let recovery = min(11, dayOffset) // Increasing recovery
            
            data.append(ActivityData(date: currentDate, activity: Double(activity), recovery: Double(recovery)))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return data
    }
}

// MARK: - Strain Performance Card
struct StrainPerformanceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Text("Strain Performance")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("-30%")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Below target")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.accentColor.opacity(0.8))
                }
                
                Spacer()
            }
            
            // Strain Chart with responsive sizing
            VStack(spacing: 8) {
                Chart {
                    ForEach(strainData, id: \.date) { data in
                        AreaMark(
                            x: .value("Date", data.date),
                            y: .value("Target", data.target)
                        )
                        .foregroundStyle(Color.green.opacity(0.08)) // Reduced opacity for subtle effect
                        
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Strain", data.strain)
                        )
                        .foregroundStyle(Color.accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Highlight only the final point
                    if let lastData = strainData.last {
                        PointMark(
                            x: .value("Date", lastData.date),
                            y: .value("Strain", lastData.strain)
                        )
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(20)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120) // Reduced height to match design
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.month().day())
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundColor(.primary.opacity(0.4))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 10]) { value in
                        AxisValueLabel {
                            Text("\(value.index)")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.primary.opacity(0.4))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16) // Reduced from 22
                .fill(Color(.systemBackground))
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 8, x: 0, y: 2) // Reduced shadow
        )
    }
    
    private var strainData: [StrainData] {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2025, month: 7, day: 31))!
        let endDate = calendar.date(from: DateComponents(year: 2025, month: 8, day: 30))!
        
        var data: [StrainData] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dayOffset = calendar.dateComponents([.day], from: startDate, to: currentDate).day ?? 0
            let strain = 3 + sin(Double(dayOffset) * 0.3) * 3 // Fluctuating strain
            let target = 7.0 // Constant target
            
            data.append(StrainData(date: currentDate, strain: strain, target: target))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return data
    }
}

// MARK: - Data Models
struct ActivityData {
    let date: Date
    let activity: Double
    let recovery: Double
}

struct StrainData {
    let date: Date
    let strain: Double
    let target: Double
}

// MARK: - Preview
struct FitnessView_Previews: PreviewProvider {
    static var previews: some View {
        FitnessView()
    }
}
