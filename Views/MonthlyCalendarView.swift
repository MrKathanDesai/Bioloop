import SwiftUI

struct MonthlyCalendarView: View {
    @Binding var selectedDate: Date
    @ObservedObject var viewModel: HomeViewModel
    @State private var currentMonth = Date()
    @State private var activeMetric: HealthScoreType = .strain
    @State private var scrollOffset: CGFloat = 0
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()
    
    private let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let monthHeight: CGFloat = 400
    
    var body: some View {
        VStack(spacing: 0) {
            // Metric tabs
            metricTabs
            
            // Scrollable calendar content
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(-6...6, id: \.self) { monthOffset in
                                let monthDate = getMonthDate(offset: monthOffset)
                                let monthId = "month_\(monthOffset)"
                                
                                VStack(spacing: 0) {
                                    // Month header
                                    monthHeader(for: monthDate)
                                    
                                    // Days of week header
                                    daysOfWeekHeader
                                    
                                    // Calendar grid
                                    calendarGrid(for: monthDate)
                                    
                                    // Spacing between months
                                    if monthOffset < 6 {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(height: 40)
                                    }
                                }
                                .id(monthId)
                            }
                        }
                        .background(
                            GeometryReader { scrollGeometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: scrollGeometry.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        handleScrollOffset(value, geometry: geometry)
                    }
                    .onAppear {
                        // Scroll to current month
                        proxy.scrollTo("month_0", anchor: .top)
                    }
                }
            }
            .frame(height: monthHeight + 100)
            
            // Navigation buttons
            navigationButtons
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Set current month to the month of selected date
            currentMonth = calendar.startOfMonth(for: selectedDate)
        }
    }
    
    // MARK: - Metric Tabs
    
    private var metricTabs: some View {
        HStack(spacing: 0) {
            ForEach(HealthScoreType.allCases, id: \.self) { metric in
                Button(action: {
                    activeMetric = metric
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(metric.color.opacity(activeMetric == metric ? 1.0 : 0.3))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: metric.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(activeMetric == metric ? .white : metric.color)
                        }
                        
                        Text(metric.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(activeMetric == metric ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Rectangle()
                            .fill(activeMetric == metric ? Color.primary.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Month Header
    
    private func monthHeader(for monthDate: Date) -> some View {
        VStack(spacing: 8) {
            Text(dateFormatter.string(from: monthDate))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(yearFormatter.string(from: monthDate))
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Days of Week Header
    
    private var daysOfWeekHeader: some View {
        HStack {
            ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Calendar Grid
    
    private func calendarGrid(for monthDate: Date) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(daysInMonth(for: monthDate).enumerated()), id: \.offset) { index, date in
                if let date = date {
                    CalendarDayView(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        metric: activeMetric,
                        value: getMetricValue(for: date, monthDate: monthDate)
                    )
                    .onTapGesture {
                        handleDayTap(date)
                    }
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            Button("Today") {
                goToToday()
            }
            .foregroundColor(.blue)
            .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    goToPreviousMonth()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Button(action: {
                    goToNextMonth()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Scroll Handling
    
    private func handleScrollOffset(_ offset: CGFloat, geometry: GeometryProxy) {
        scrollOffset = offset
        
        // Calculate which month is most visible
        let monthIndex = Int(round(-offset / monthHeight))
        if monthIndex >= -6 && monthIndex <= 6 {
            let newMonth = getMonthDate(offset: monthIndex)
            if !calendar.isDate(newMonth, inSameDayAs: currentMonth) {
                currentMonth = newMonth
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMonthDate(offset: Int) -> Date {
        return calendar.date(byAdding: .month, value: offset, to: currentMonth) ?? currentMonth
    }
    
    private func daysInMonth(for monthDate: Date) -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthDate) else {
            return []
        }
        
        let firstDayOfMonth = calendar.startOfMonth(for: monthDate)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Adjust for Monday start (weekday 2 = Monday)
        let adjustedFirstWeekday = firstWeekday == 1 ? 7 : firstWeekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: adjustedFirstWeekday - 1)
        
        for day in 1...monthRange.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func getMetricValue(for date: Date, monthDate: Date) -> Double? {
        // For today, use actual data if available
        if calendar.isDateInToday(date) && viewModel.currentHealthScore != nil {
            return getCurrentMetricValue(activeMetric)
        }
        
        // For demonstration, show some sample data for dates in the current month
        // In a real app, this would come from historical data
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: monthDate)
        let currentMonth = calendar.component(.month, from: self.currentMonth)
        
        // Only show sample data for the current month being displayed
        if month == currentMonth {
            // Show sample data for dates 19-31 (like in the image)
            if day >= 19 {
                // Generate some varied sample values
                let baseValue = 40 + (day % 3) * 20 // 40, 60, or 80
                let variation = (day % 7) * 5 // 0, 5, 10, 15, 20, 25, 30
                return Double(baseValue + variation)
            }
        }
        
        return nil
    }
    
    private func getCurrentMetricValue(_ metric: HealthScoreType) -> Double? {
        guard let score = viewModel.currentHealthScore else { return nil }
        
        switch metric {
        case .recovery:
            return score.recovery.value
        case .sleep:
            return score.sleep.value
        case .strain:
            return score.strain.value
        case .stress:
            return score.stress.value
        }
    }
    
    private func handleDayTap(_ date: Date) {
        selectedDate = date
        
        // Load data for the selected date
        Task {
            await viewModel.loadHealthData(for: date)
        }
    }
    
    private func goToToday() {
        let today = Date()
        selectedDate = today
        currentMonth = calendar.startOfMonth(for: today)
    }
    
    private func goToPreviousMonth() {
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = previousMonth
        }
    }
    
    private func goToNextMonth() {
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = nextMonth
        }
    }
}

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let metric: HealthScoreType
    let value: Double?
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 4) {
            // Date number
            Text(dayFormatter.string(from: date))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? metric.color : Color.clear)
                )
            
            // Score indicator (only show if there's a value)
            if let value = value {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: CGFloat(value / 100))
                            .stroke(
                                metric.color,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    )
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - HealthScoreType Extension

extension HealthScoreType: CaseIterable {
    static var allCases: [HealthScoreType] {
        return [.recovery, .sleep, .strain, .stress]
    }
}

struct MonthlyCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        MonthlyCalendarView(
            selectedDate: .constant(Date()),
            viewModel: HomeViewModel.shared
        )
    }
}
