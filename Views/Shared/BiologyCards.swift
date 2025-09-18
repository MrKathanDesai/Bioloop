import SwiftUI
import Charts

// MARK: - HRV Card with Baseline Comparison
struct HRVCard: View {
    let currentValue: Double
    let history: [HealthMetricPoint]
    let hasData: Bool
    
    private var baselineValue: Double {
        guard !history.isEmpty else { return currentValue }
        let recent7Days = history.suffix(7)
        return recent7Days.map(\.value).reduce(0, +) / Double(recent7Days.count)
    }
    
    private var trend: String {
        guard history.count >= 7 else { return "Stable" }
        let recent = Array(history.suffix(3)).map(\.value).reduce(0, +) / 3
        let previous = Array(history.prefix(history.count - 3).suffix(7)).map(\.value).reduce(0, +) / 7
        
        let change = (recent - previous) / previous * 100
        if change > 5 { return "Improving" }
        else if change < -5 { return "Declining" }
        else { return "Stable" }
    }
    
    private var trendColor: Color {
        switch trend {
        case "Improving": return BiologyColors.success
        case "Declining": return BiologyColors.danger
        default: return BiologyColors.primary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16))
                    .foregroundColor(currentValue > 0 ? BiologyColors.primary : BiologyColors.muted)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heart Rate")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BiologyColors.text)
                    Text("Variability")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BiologyColors.text)
                }
                
                Spacer()
            }
            
            // Current value
            VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                if hasData && currentValue > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", currentValue))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(BiologyColors.text)
                        
                        Text("ms")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(BiologyColors.subtext)
                            .baselineOffset(-2)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: trend == "Improving" ? "arrow.up.right" : trend == "Declining" ? "arrow.down.right" : "minus")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(trendColor)
                        
                        Text(trend)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(trendColor)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not Enough Data Yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BiologyColors.muted)
                        
                        Text("Wear your Apple Watch at night to track HRV")
                            .font(.system(size: 12))
                            .foregroundColor(BiologyColors.subtext)
                    }
                }
            }
            
            // 7-day comparison chart
            if hasData && currentValue > 0 && !history.isEmpty {
                Chart(history.suffix(7)) { dataPoint in
                    AreaMark(
                        x: .value("Day", dataPoint.date),
                        y: .value("HRV", dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BiologyColors.primary.opacity(0.3), BiologyColors.primary.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Day", dataPoint.date),
                        y: .value("HRV", dataPoint.value)
                    )
                    .foregroundStyle(BiologyColors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 50)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .biologyCard()
    }
}

// MARK: - Resting Heart Rate Card with Zones
struct RestingHeartRateCard: View {
    let currentValue: Double
    let history: [HealthMetricPoint]
    let hasData: Bool
    
    private var heartRateZones: [HeartRateZone] {
        [
            HeartRateZone(name: "Athlete", minBPM: 40, maxBPM: 50, color: BiologyColors.success),
            HeartRateZone(name: "Excellent", minBPM: 50, maxBPM: 60, color: BiologyColors.primary),
            HeartRateZone(name: "Good", minBPM: 60, maxBPM: 70, color: BiologyColors.warning),
            HeartRateZone(name: "Fair", minBPM: 70, maxBPM: 80, color: BiologyColors.danger)
        ]
    }
    
    private var currentZone: HeartRateZone {
        heartRateZones.first { zone in
            currentValue >= zone.minBPM && currentValue < zone.maxBPM
        } ?? HeartRateZone(name: "High", minBPM: 80, maxBPM: 100, color: BiologyColors.danger)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(currentValue > 0 ? currentZone.color : BiologyColors.muted)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Resting")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BiologyColors.text)
                    Text("Heart Rate")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BiologyColors.text)
                }
                
                Spacer()
            }
            
            // Current value
            VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                if hasData && currentValue > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.0f", currentValue))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(BiologyColors.text)
                        
                        Text("bpm")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(BiologyColors.subtext)
                            .baselineOffset(-2)
                    }
                    
                    Text(currentZone.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(currentZone.color)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not Enough Data Yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BiologyColors.muted)
                        
                        Text("Apple Watch will track resting heart rate automatically")
                            .font(.system(size: 12))
                            .foregroundColor(BiologyColors.subtext)
                    }
                }
            }
            
            // Zone visualization
            if hasData && currentValue > 0 {
                VStack(spacing: 6) {
                    // Zone bars
                    HStack(spacing: 2) {
                        ForEach(heartRateZones.indices, id: \.self) { index in
                            let zone = heartRateZones[index]
                            let isCurrentZone = currentValue >= zone.minBPM && currentValue < zone.maxBPM
                            
                            Rectangle()
                                .fill(zone.color.opacity(isCurrentZone ? 1.0 : 0.3))
                                .frame(height: 8)
                                .cornerRadius(2)
                        }
                    }
                    
                    // 7-day trend
                    if !history.isEmpty {
                        Chart(history.suffix(7)) { dataPoint in
                            LineMark(
                                x: .value("Day", dataPoint.date),
                                y: .value("RHR", dataPoint.value)
                            )
                            .foregroundStyle(currentZone.color)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 30)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                    }
                }
            }
        }
        .biologyCard()
    }
}

// MARK: - Weight Tracking Card with BMI Context
struct WeightTrackingCard: View {
    let currentWeight: Double
    let history: [HealthMetricPoint]
    let height: Double // in cm
    let hasData: Bool
    
    private var bmi: Double {
        guard currentWeight > 0, height > 0 else { return 0 }
        let heightInMeters = height / 100
        return currentWeight / (heightInMeters * heightInMeters)
    }
    
    private var bmiCategory: String {
        switch bmi {
        case 0..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
    
    private var bmiColor: Color {
        switch bmiCategory {
        case "Underweight": return BiologyColors.warning
        case "Normal": return BiologyColors.success
        case "Overweight": return BiologyColors.warning
        case "Obese": return BiologyColors.danger
        default: return BiologyColors.muted
        }
    }
    
    private var weightTrend: String {
        guard history.count >= 7 else { return "Stable" }
        let recent = Array(history.suffix(7)).map(\.value).reduce(0, +) / 7
        let previous = Array(history.dropLast(7).suffix(7)).map(\.value).reduce(0, +) / 7
        
        let change = recent - previous
        if change > 0.5 { return "Increasing" }
        else if change < -0.5 { return "Decreasing" }
        else { return "Stable" }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header
            HStack {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 16))
                    .foregroundColor(currentWeight > 0 ? BiologyColors.violet : BiologyColors.muted)
                
                Text("Weight Tracking")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Spacer()
                
                Text(String(format: "BMI: %.1f", bmi))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(bmiColor)
            }
            
            // Current weight and BMI
            VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                if hasData && currentWeight > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", currentWeight))
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(BiologyColors.text)
                        
                        Text("kg")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(BiologyColors.subtext)
                            .baselineOffset(-2)
                    }
                    
                    HStack(spacing: 8) {
                        Text(bmiCategory)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(bmiColor)
                        
                        Text("•")
                            .foregroundColor(BiologyColors.muted)
                        
                        HStack(spacing: 4) {
                            Image(systemName: weightTrend == "Increasing" ? "arrow.up" : 
                                  weightTrend == "Decreasing" ? "arrow.down" : "minus")
                                .font(.system(size: 10))
                                .foregroundColor(BiologyColors.subtext)
                            
                            Text(weightTrend)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not Enough Data Yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BiologyColors.muted)
                        
                        Text("Add weight data in the Health app to track BMI")
                            .font(.system(size: 12))
                            .foregroundColor(BiologyColors.subtext)
                    }
                }
            }
            
            // 30-day weight chart
            if hasData && currentWeight > 0 && !history.isEmpty {
                Chart(history.suffix(30)) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.value)
                    )
                    .foregroundStyle(BiologyColors.violet)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BiologyColors.violet.opacity(0.2), BiologyColors.violet.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 60)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .biologyCard()
    }
}

// MARK: - Body Composition Card
struct BodyCompositionCard: View {
    let composition: BodyCompositionData
    
    private var totalMass: Double {
        composition.muscle + composition.fat + composition.bone + composition.water
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16))
                    .foregroundColor(BiologyColors.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BiologyColors.text)
                    Text("Composition")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BiologyColors.text)
                }
                
                Spacer()
            }
            
            // Pie chart
            Chart {
                SectorMark(
                    angle: .value("Muscle", composition.muscle),
                    innerRadius: .ratio(0.4),
                    angularInset: 2
                )
                .foregroundStyle(BiologyColors.primary)
                .opacity(0.8)
                
                SectorMark(
                    angle: .value("Fat", composition.fat),
                    innerRadius: .ratio(0.4),
                    angularInset: 2
                )
                .foregroundStyle(BiologyColors.warning)
                .opacity(0.8)
                
                SectorMark(
                    angle: .value("Bone", composition.bone),
                    innerRadius: .ratio(0.4),
                    angularInset: 2
                )
                .foregroundStyle(BiologyColors.muted)
                .opacity(0.8)
                
                SectorMark(
                    angle: .value("Other", composition.water),
                    innerRadius: .ratio(0.4),
                    angularInset: 2
                )
                .foregroundStyle(BiologyColors.violet)
                .opacity(0.8)
            }
            .frame(height: 80)
            
            // Legend
            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(BiologyColors.primary)
                        .frame(width: 8, height: 8)
                    Text(String(format: "Muscle %.1fkg", composition.muscle))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(BiologyColors.text)
                    Spacer()
                }
                
                HStack {
                    Circle()
                        .fill(BiologyColors.warning)
                        .frame(width: 8, height: 8)
                    Text(String(format: "Fat %.1f%%", composition.fat))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(BiologyColors.text)
                    Spacer()
                }
            }
        }
        .biologyCard()
    }
}

// MARK: - Health Score Card
struct HealthScoreCard: View {
    let vo2Max: Double
    let hrv: Double
    let rhr: Double
    
    private var overallScore: Double {
        var score = 0.0
        var components = 0
        
        // VO2 Max component (0-100)
        if vo2Max > 0 {
            let vo2Score = min(max((vo2Max - 20) / 40 * 100, 0), 100)
            score += vo2Score
            components += 1
        }
        
        // HRV component (0-100)
        if hrv > 0 {
            let hrvScore = min(max((hrv - 20) / 60 * 100, 0), 100)
            score += hrvScore
            components += 1
        }
        
        // RHR component (0-100, inverted)
        if rhr > 0 {
            let rhrScore = min(max((80 - rhr) / 40 * 100, 0), 100)
            score += rhrScore
            components += 1
        }
        
        return components > 0 ? score / Double(components) : 0
    }
    
    private var scoreColor: Color {
        switch overallScore {
        case 0..<40: return BiologyColors.danger
        case 40..<60: return BiologyColors.warning
        case 60..<80: return BiologyColors.primary
        default: return BiologyColors.success
        }
    }
    
    private var scoreGrade: String {
        switch overallScore {
        case 0..<40: return "C"
        case 40..<60: return "B-"
        case 60..<70: return "B"
        case 70..<80: return "B+"
        case 80..<90: return "A-"
        default: return "A"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16))
                    .foregroundColor(scoreColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Health")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BiologyColors.text)
                    Text("Score")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BiologyColors.text)
                }
                
                Spacer()
            }
            
            // Score display
            VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(scoreGrade)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(scoreColor)
                    
                    Text(String(format: "%.0f", overallScore))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(BiologyColors.subtext)
                        .baselineOffset(8)
                }
                
                Text("Overall Fitness")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(BiologyColors.subtext)
            }
            
            // Score breakdown
            VStack(spacing: 6) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(BiologyColors.grid, lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: overallScore / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1), value: overallScore)
                    
                    Text(String(format: "%.0f", overallScore))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(scoreColor)
                }
            }
        }
        .biologyCard()
    }
}

// MARK: - Floating Tab Bar
struct FloatingTabBar: View {
    @Binding var selected: Int
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(.white)
                .shadow(color: BiologyColors.shadow, radius: 28, x: 0, y: 8)
                .frame(height: 64)
                .overlay(
                    HStack(spacing: 40) {
                        tab(icon: "house.fill", title: "Home", idx: 0)
                        tab(icon: "book.fill", title: "Journal", idx: 1)
                        Spacer().frame(width: 56)
                        tab(icon: "figure.run", title: "Fitness", idx: 2)
                        tab(icon: "heart.fill", title: "Biology", idx: 3)
                    }
                    .padding(.horizontal, 24)
                )
            
            Circle()
                .fill(.white)
                .frame(width: 56, height: 56)
                .shadow(color: BiologyColors.shadow, radius: 18, x: 0, y: 6)
                .overlay(
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(BiologyColors.primary)
                )
                .offset(y: -28)
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder private func tab(icon: String, title: String, idx: Int) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(selected == idx ? BiologyColors.primary : BiologyColors.subtext)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(selected == idx ? BiologyColors.primary : BiologyColors.subtext)
        }
        .onTapGesture { selected = idx }
    }
}
