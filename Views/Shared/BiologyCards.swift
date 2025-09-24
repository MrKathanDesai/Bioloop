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
        VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
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
    let weight: Double?
    let leanBodyMass: Double?
    let bodyFat: Double?
    let hasData: Bool
    
    // Derive lean body mass from weight and body fat when possible
    private var computedLeanBodyMass: Double? {
        guard let weight = weight, let bodyFat = bodyFat, weight > 0, bodyFat > 0 else { return nil }
        return weight * (1.0 - bodyFat / 100.0)
    }
    
    // Calculate body composition from available data
    private var composition: BodyCompositionData? {
        guard hasData, let weight = weight, weight > 0 else { return nil }
        
        // If we have lean body mass (from HealthKit or derived from body fat)
        if let leanMass = (leanBodyMass ?? computedLeanBodyMass), leanMass > 0 {
            let fatMass = weight - leanMass
            let fatPercentage = (fatMass / weight) * 100
            
            // Calculate proper percentages that add up to 100%
            let leanPercentage = 100 - fatPercentage
            
            // Distribute lean mass properly (must add up to leanPercentage)
            let musclePercentage = leanPercentage * 0.75  // ~75% of lean is muscle
            let bonePercentage = leanPercentage * 0.15    // ~15% of lean is bone
            let waterPercentage = leanPercentage * 0.10   // ~10% of lean is other water/organs
            
            return BodyCompositionData(
                muscle: musclePercentage,
                fat: fatPercentage,
                bone: bonePercentage,
                water: waterPercentage
            )
        }
        
        // If we have body fat percentage
        if let bodyFatPercent = bodyFat, bodyFatPercent > 0 {
            // Calculate proper percentages that add up to 100%
            let leanPercentage = 100 - bodyFatPercent
            
            // Distribute lean mass properly (must add up to leanPercentage)
            let musclePercentage = leanPercentage * 0.75  // ~75% of lean is muscle
            let bonePercentage = leanPercentage * 0.15    // ~15% of lean is bone  
            let waterPercentage = leanPercentage * 0.10   // ~10% of lean is other water/organs
            
            return BodyCompositionData(
                muscle: musclePercentage,
                fat: bodyFatPercent,
                bone: bonePercentage,
                water: waterPercentage
            )
        }
        
        // If no real data available, don't show fake estimates
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16))
                    .foregroundColor(hasData ? BiologyColors.primary : BiologyColors.muted)
                
                Text("Body Composition")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                    .allowsTightening(true)
                
                Spacer()
            }
            
            if let comp = composition {
                HStack(alignment: .center, spacing: 12) {
                    // Pie chart - using actual percentage values (left)
                    Chart {
                        SectorMark(
                            angle: .value("Muscle", comp.muscle),
                            innerRadius: .ratio(0.4),
                            angularInset: 1
                        )
                        .foregroundStyle(BiologyColors.primary)
                        .opacity(0.8)
                        
                        SectorMark(
                            angle: .value("Fat", comp.fat),
                            innerRadius: .ratio(0.4),
                            angularInset: 1
                        )
                        .foregroundStyle(BiologyColors.warning)
                        .opacity(0.8)
                        
                        SectorMark(
                            angle: .value("Bone", comp.bone),
                            innerRadius: .ratio(0.4),
                            angularInset: 1
                        )
                        .foregroundStyle(BiologyColors.muted)
                        .opacity(0.8)
                        
                        SectorMark(
                            angle: .value("Other", comp.water),
                            innerRadius: .ratio(0.4),
                            angularInset: 1
                        )
                        .foregroundStyle(BiologyColors.violet)
                        .opacity(0.8)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)

                    // Metrics (right)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(BiologyColors.primary)
                                .frame(width: 8, height: 8)
                            Text(String(format: "Muscle %.1f%%", comp.muscle))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BiologyColors.text)
                        }
                        HStack {
                            Circle()
                                .fill(BiologyColors.warning)
                                .frame(width: 8, height: 8)
                            Text(String(format: "Fat %.1f%%", comp.fat))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BiologyColors.text)
                        }
                        HStack {
                            Circle()
                                .fill(BiologyColors.muted)
                                .frame(width: 8, height: 8)
                            Text(String(format: "Bone %.1f%%", comp.bone))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BiologyColors.text)
                        }
                        HStack {
                            Circle()
                                .fill(BiologyColors.violet)
                                .frame(width: 8, height: 8)
                            Text(String(format: "Other %.1f%%", comp.water))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BiologyColors.text)
                        }
                        let total = comp.muscle + comp.fat + comp.bone + comp.water
                        Text(String(format: "Total: %.1f%%", total))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(BiologyColors.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Not Enough Data Yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BiologyColors.muted)
                    
                    Text("Add weight and body composition data in the Health app to see detailed breakdown")
                        .font(.system(size: 12))
                        .foregroundColor(BiologyColors.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
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
    let weight: Double?
    let age: Int // Add age parameter for more accurate scoring
    let hasRecentData: Bool
    
    // Health score calculation based on scientific standards
    private var overallScore: Double {
        guard hasRecentData else { return 0 }
        
        var totalScore = 0.0
        var componentCount = 0
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        // VO2 Max Score (40% weight) - Most important fitness indicator
        if vo2Max > 0 {
            let vo2Score = calculateVO2MaxScore(vo2Max, age: age)
            weightedSum += vo2Score * 0.4
            totalWeight += 0.4
            componentCount += 1
        }
        
        // HRV Score (30% weight) - Recovery and autonomic health
        if hrv > 0 {
            let hrvScore = calculateHRVScore(hrv, age: age)
            weightedSum += hrvScore * 0.3
            totalWeight += 0.3
            componentCount += 1
        }
        
        // Resting Heart Rate Score (30% weight) - Cardiovascular fitness
        if rhr > 0 {
            let rhrScore = calculateRHRScore(rhr, age: age)
            weightedSum += rhrScore * 0.3
            totalWeight += 0.3
            componentCount += 1
        }
        
        // If we don't have all components, adjust weights proportionally
        if totalWeight > 0 {
            // weighted average already in 0-100 scale
            totalScore = weightedSum / totalWeight
        }
        
        return min(max(totalScore, 0), 100)
    }
    
    // VO2 Max scoring based on age and fitness standards (more realistic)
    private func calculateVO2MaxScore(_ vo2Max: Double, age: Int) -> Double {
        // Realistic VO2 Max percentiles for general population
        let ageGroup = min(max(age, 20), 70)
        let ageFactor = max(0.0, 1.0 - Double(ageGroup - 20) * 0.01) // Gradual decline with age
        
        // Base thresholds for 20-year-old (ml/kg/min)
        let baseExcellent = 55.0
        let baseVeryGood = 45.0
        let baseGood = 38.0
        let baseFair = 30.0
        let basePoor = 25.0
        
        // Apply age adjustment (decline with age)
        let excellent = baseExcellent * ageFactor
        let veryGood = baseVeryGood * ageFactor
        let good = baseGood * ageFactor
        let fair = baseFair * ageFactor
        let poor = basePoor * ageFactor
        
        switch vo2Max {
        case excellent...: return 90.0
        case veryGood..<excellent: return 80.0
        case good..<veryGood: return 65.0
        case fair..<good: return 50.0
        case poor..<fair: return 30.0
        default: return 10.0
        }
    }
    
    // HRV scoring based on age and population norms (more realistic)
    private func calculateHRVScore(_ hrv: Double, age: Int) -> Double {
        // Realistic HRV norms (RMSSD in ms) - most people have lower HRV
        let ageFactor = max(0.7, 1.0 - Double(age - 25) * 0.008) // Gradual decline with age
        
        // Base thresholds adjusted for real population
        let baseExcellent = 45.0
        let baseVeryGood = 32.0
        let baseGood = 22.0
        let baseFair = 15.0
        let basePoor = 10.0
        
        // Apply age adjustment
        let excellent = baseExcellent * ageFactor
        let veryGood = baseVeryGood * ageFactor
        let good = baseGood * ageFactor
        let fair = baseFair * ageFactor
        let poor = basePoor * ageFactor
        
        switch hrv {
        case excellent...: return 90.0
        case veryGood..<excellent: return 75.0
        case good..<veryGood: return 60.0
        case fair..<good: return 45.0
        case poor..<fair: return 25.0
        default: return 10.0
        }
    }
    
    // Resting Heart Rate scoring (lower is better, more realistic)
    private func calculateRHRScore(_ rhr: Double, age: Int) -> Double {
        // Realistic RHR norms (BPM) - adjusted for general population
        let ageAdjustment = Double(age - 25) * 0.15 // Slight increase with age
        
        let excellent = 50.0 + ageAdjustment
        let veryGood = 60.0 + ageAdjustment
        let good = 70.0 + ageAdjustment
        let fair = 80.0 + ageAdjustment
        let poor = 90.0 + ageAdjustment
        
        switch rhr {
        case 0..<excellent: return 90.0
        case excellent..<veryGood: return 75.0
        case veryGood..<good: return 60.0
        case good..<fair: return 45.0
        case fair..<poor: return 25.0
        default: return 10.0
        }
    }
    
    private var scoreColor: Color {
        switch overallScore {
        case 0..<25: return BiologyColors.danger
        case 25..<40: return BiologyColors.danger.opacity(0.8)
        case 40..<55: return BiologyColors.warning
        case 55..<70: return BiologyColors.primary
        case 70..<80: return BiologyColors.violet
        case 80..<90: return BiologyColors.success
        default: return BiologyColors.success.opacity(0.9) // Elite level
        }
    }
    
    private var scoreGrade: String {
        switch overallScore {
        case 0..<25: return "F"
        case 25..<35: return "D"
        case 35..<45: return "C-"
        case 45..<55: return "C"
        case 55..<65: return "C+"
        case 65..<70: return "B-"
        case 70..<75: return "B"
        case 75..<80: return "B+"
        case 80..<85: return "A-"
        case 85..<92: return "A"
        case 92..<97: return "A+"
        default: return "A++"  // Only for truly exceptional scores
        }
    }
    
    private var fitnessLevel: String {
        switch overallScore {
        case 0..<25: return "Very Poor"
        case 25..<40: return "Poor"
        case 40..<55: return "Fair"
        case 55..<70: return "Good"
        case 70..<80: return "Very Good"
        case 80..<90: return "Excellent"
        default: return "Elite"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16))
                    .foregroundColor(hasRecentData ? scoreColor : BiologyColors.muted)
                
                Text("Health Score")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
                    .allowsTightening(true)
                
                Spacer()
            }
            
            if hasRecentData && overallScore > 0 {
                HStack(alignment: .center, spacing: 12) {
                    // Score text (centered within its half)
                    VStack(alignment: .center, spacing: 6) {
                        Text(scoreGrade)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(scoreColor)
                        Text(fitnessLevel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(scoreColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Ring (right)
                    ZStack {
                        GeometryReader { geo in
                            let size = min(geo.size.width, geo.size.height)
                            let line: CGFloat = 6
                            Circle()
                                .stroke(BiologyColors.grid, lineWidth: line)
                            Circle()
                                .trim(from: 0, to: overallScore / 100)
                                .stroke(scoreColor, style: StrokeStyle(lineWidth: line, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 1), value: overallScore)
                            Text(String(format: "%.0f", overallScore))
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundColor(scoreColor)
                                .frame(width: size, height: size)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 100)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Not Enough Data Yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BiologyColors.muted)
                    
                    Text("Need recent VO₂ Max, HRV, and heart rate data to calculate health score")
                        .font(.system(size: 12))
                        .foregroundColor(BiologyColors.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
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
