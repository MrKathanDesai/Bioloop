import SwiftUI

// MARK: - Design Tokens & Colors
struct BiologyColors {
    static let bg = Color(hex: "#F6F7FB")
    static let cardBorder = Color(hex: "#E9EDF3")
    static let shadow = Color(hex: "#0B1A2A").opacity(0.06)
    static let text = Color(hex: "#111316")
    static let subtext = Color(hex: "#6C6F74")
    static let muted = Color(hex: "#9CA0A9")
    static let primary = Color(hex: "#2E7BFF")
    static let violet = Color(hex: "#7A4CFF")
    static let danger = Color(hex: "#E45B2C")
    static let grid = Color(hex: "#E9EBF0")
}

// MARK: - Consistent Spacing Constants
struct BiologySpacing {
    static let cardSpacing: CGFloat = 16        // Vertical spacing between cards
    static let horizontalPadding: CGFloat = 16  // Left/right padding for cards
    static let cardInternalPadding: CGFloat = 16 // Internal padding within cards (increased from 12)
    static let sideBySideSpacing: CGFloat = 16  // Spacing between side-by-side cards (increased from 12)
    static let bottomSafeArea: CGFloat = 90     // Bottom safe area padding for floating tab
    static let headerTopPadding: CGFloat = 16   // Top padding for header
    static let headerSpacing: CGFloat = 12      // Spacing within header
    static let contentSpacing: CGFloat = 16     // Spacing between content sections
    static let chartPadding: CGFloat = 8        // Padding around charts
    static let textSpacing: CGFloat = 6         // Spacing between text elements
    static let metricChartSpacing: CGFloat = 8  // Spacing between metric and chart
}

// MARK: - Reusable Card Style Modifier
extension View {
    func biologyCard() -> some View {
        self
            .padding(.vertical, BiologySpacing.cardInternalPadding)
            .padding(.horizontal, BiologySpacing.cardInternalPadding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: BiologyColors.shadow, radius: 36, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(BiologyColors.cardBorder.opacity(0.6), lineWidth: 1)
            )
    }
}

struct BiologyView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var healthData: HealthData?
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var useSampleData = false
    @State private var cardAppearStates: [Bool] = Array(repeating: false, count: 6)
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ScrollView {
            VStack(spacing: BiologySpacing.contentSpacing) {
                // Header Section
                VStack(spacing: BiologySpacing.headerSpacing) {
                    HStack {
                        Text("Biology")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(BiologyColors.text)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            // Segmented control for data source
                            HStack(spacing: 0) {
                                Button(action: {
                                    useSampleData = false
                                    loadHealthData()
                                }) {
                                    Text("Live")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(useSampleData ? BiologyColors.subtext : BiologyColors.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(useSampleData ? Color.clear : BiologyColors.primary.opacity(0.1))
                                        )
                                }
                                
                                Button(action: {
                                    useSampleData = true
                                    loadSampleData()
                                }) {
                                    Text("Sample")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(useSampleData ? BiologyColors.primary : BiologyColors.subtext)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(useSampleData ? BiologyColors.primary.opacity(0.1) : Color.clear)
                                        )
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(BiologyColors.cardBorder, lineWidth: 1)
                            )
                        }
                    }
                    
                    if useSampleData {
                        Text("This view is showing sample data for demonstration. To see your actual health data, tap 'Live Data' and grant HealthKit permissions when prompted.")
                            .font(.system(size: 12))
                            .foregroundColor(BiologyColors.subtext)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 4)
                    }
                }
                
                if isLoading {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(BiologyColors.primary)
                        
                        Text("Loading health data...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BiologyColors.subtext)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding(.vertical, 40)
                } else if let healthData = healthData {
                    // Content with staggered entrance animation
                    VStack(spacing: BiologySpacing.cardSpacing) {
                        VO2MaxCard(value: healthData.vo2Max ?? 0, status: vo2MaxStatus(for: healthData.vo2Max ?? 0))
                            .offset(y: cardAppearStates[0] ? 0 : 12)
                        
                        HStack(spacing: BiologySpacing.sideBySideSpacing) {
                            HRVBaselinesCard(value: healthData.hrv ?? 0, status: hrvStatus(for: healthData.hrv ?? 0))
                                .offset(y: cardAppearStates[1] ? 0 : 12)
                            
                            RHRBaselinesCard(value: healthData.restingHeartRate ?? 0, status: rhrStatus(for: healthData.restingHeartRate ?? 0))
                                .offset(y: cardAppearStates[2] ? 0 : 12)
                        }
                        
                        WeightCard(value: healthData.weight ?? 0, trend: "Decreasing")
                            .offset(y: cardAppearStates[3] ? 0 : 12)
                        
                        HStack(spacing: BiologySpacing.sideBySideSpacing) {
                            LeanBodyMassCard(value: healthData.leanBodyMass)
                                .offset(y: cardAppearStates[4] ? 0 : 12)
                            
                            BodyFatCard(value: healthData.bodyFat)
                                .offset(y: cardAppearStates[5] ? 0 : 12)
                        }
                    }
                    .padding(.horizontal, BiologySpacing.horizontalPadding)
                    .padding(.bottom, BiologySpacing.bottomSafeArea)
                    .opacity(cardAppearStates.allSatisfy { $0 } ? 1 : 0.3)
                    .animation(.easeOut(duration: 0.8), value: cardAppearStates.allSatisfy { $0 })
                }
            }
            .padding(.horizontal, BiologySpacing.horizontalPadding)
            .padding(.top, BiologySpacing.headerTopPadding)
        }
        .background(BiologyColors.bg)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selected: .constant(3)) // Biology tab selected
        }
        .onAppear {
            // Start with sample data by default to ensure the view loads
            useSampleData = true
            loadSampleData()
            
            // Staggered entrance animation for cards
            if !reduceMotion {
                startStaggeredAnimation()
            } else {
                // Set all cards to appear immediately for reduced motion
                for i in 0..<6 {
                    cardAppearStates[i] = true
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func startStaggeredAnimation() {
        // Animate each card in sequence with a longer delay to allow individual animations
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.easeOut(duration: 0.6)) {
                    cardAppearStates[i] = true
                }
            }
        }
    }
    
    private func loadHealthData() {
        // Only attempt HealthKit calls if not in sample mode
        guard !useSampleData else {
            loadSampleData()
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let data = try await healthKitManager.fetchHealthData(for: Date())
                await MainActor.run {
                    self.healthData = data
                    self.isLoading = false
                }
            } catch {
                print("Error loading health data: \(error)")
                await MainActor.run {
                    // Check if it's an authorization issue
                    if let healthKitError = error as? HealthKitError {
                        switch healthKitError {
                        case .permissionDenied, .healthDataNotAvailable:
                            // Don't show error for expected authorization issues
                            print("HealthKit not available, switching to sample data")
                            self.useSampleData = true
                            self.loadSampleData()
                        default:
                            // Show error for other issues
                            self.errorMessage = "Failed to load health data: \(error.localizedDescription)"
                            self.showError = true
                            self.useSampleData = true
                            self.loadSampleData()
                        }
                    } else {
                        // For other errors, show message and fall back to sample data
                        self.errorMessage = "HealthKit unavailable, showing sample data"
                        self.showError = true
                        self.useSampleData = true
                        self.loadSampleData()
                    }
                }
            }
        }
    }
    
    private func loadSampleData() {
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.healthData = HealthData(
                date: Date(),
                hrv: 118.8,
                restingHeartRate: 48.1,
                heartRate: 72.0,
                energyBurned: 450.0,
                sleepStart: Date().addingTimeInterval(-28800), // 8 hours ago
                sleepEnd: Date(),
                sleepDuration: 8.0,
                sleepEfficiency: 0.85,
                deepSleep: 2.5,
                remSleep: 1.8,
                wakeEvents: 2,
                workoutMinutes: 45.0,
                vo2Max: 34.6,
                weight: 96.5,
                leanBodyMass: 68.2,
                bodyFat: 18.5
            )
            self.isLoading = false
        }
    }
    
    // MARK: - Apple Health Standards Status Calculation Methods
    
    private func vo2MaxStatus(for value: Double) -> String {
        // VO2 Max ranges based on Apple Health and fitness standards
        switch value {
        case 0..<30: return "Poor"
        case 30..<40: return "Fair"
        case 40..<50: return "Good"
        case 50..<60: return "Very Good"
        case 60...100: return "Excellent"
        default: return "Unknown"
        }
    }
    
    private func rhrStatus(for value: Double) -> String {
        // Resting Heart Rate ranges based on Apple Health standards
        switch value {
        case 0..<40: return "Very Low"
        case 40..<60: return "Excellent"
        case 60..<80: return "Good"
        case 80..<100: return "Fair"
        case 100...200: return "High"
        default: return "Unknown"
        }
    }
    
    private func hrvStatus(for value: Double) -> String {
        // HRV ranges based on Apple Health standards (varies by age/gender)
        switch value {
        case 0..<20: return "Poor"
        case 20..<30: return "Fair"
        case 30..<50: return "Good"
        case 50..<70: return "Very Good"
        case 70...200: return "Excellent"
        default: return "Unknown"
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Poor": return BiologyColors.danger
        case "Fair": return Color.orange
        case "Good": return BiologyColors.primary
        case "Very Good": return BiologyColors.violet
        case "Excellent": return Color.green
        default: return BiologyColors.muted
        }
    }
    
    private func vo2MaxIndicatorOffset(for value: Double) -> CGFloat {
        // Calculate offset based on VO2 Max value ranges
        switch value {
        case 0..<30: return -66 // Poor
        case 30..<40: return -33 // Fair
        case 40..<50: return 0   // Good
        case 50..<60: return 33  // Very Good
        default: return 66        // Excellent
        }
    }
    
}

// MARK: - Floating Tab Bar (Bevel Style)
struct FloatingTabBar: View {
    @Binding var selected: Int
    
    var body: some View {
        ZStack {
            // Main capsule
            Capsule()
                .fill(.white)
                .shadow(color: BiologyColors.shadow, radius: 28, x: 0, y: 8)
                .frame(height: 64)
                .overlay(
                    HStack(spacing: 40) {
                        tab(icon: "house.fill", title: "Home", idx: 0)
                        tab(icon: "book.fill", title: "Journal", idx: 1)
                        Spacer().frame(width: 56) // Space for the FAB
                        tab(icon: "figure.run", title: "Fitness", idx: 2)
                        tab(icon: "heart.fill", title: "Biology", idx: 3)
                    }
                    .padding(.horizontal, 24)
                )
            
            // FAB (Floating Action Button)
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

// MARK: - VO2 Max Card (Bevel Design)
struct VO2MaxCard: View {
    let value: Double
    let status: String
    @State private var knobOffset: CGFloat = 0
    @State private var knobScale: CGFloat = 0.7
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header with icon and title
            HStack {
                Image(systemName: "lungs.fill")
                    .font(.system(size: 16))
                    .foregroundColor(value > 0 ? BiologyColors.danger : BiologyColors.muted)
                
                Text("VO₂ Max")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Spacer()
            }
            
            // Metric and chart in vertical layout
            VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
                // Metric section
                VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                    if value > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(value, specifier: "%.1f")")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("ml/kg/min")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
                                .baselineOffset(-2)
                        }
                        
                        Text(status)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(statusColor(for: status))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("No data")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("ml/kg/min")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.muted)
                                .baselineOffset(-2)
                        }
                        
                        Text("Unavailable")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(BiologyColors.muted)
                    }
                }
                
                // Chart section
                if value > 0 {
                    // Bevel-style horizontal stacked bands with geometry-based knob positioning
                    VStack(spacing: 4) {
                        // Five stacked bands
                        HStack(spacing: 6) {
                            ForEach(0..<5) { index in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(vo2MaxColor(for: index))
                                    .frame(width: 24, height: 12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.08),
                                                        Color.black.opacity(0.02)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    )
                            }
                        }
                        
                        // Active track below bands
                        GeometryReader { geo in
                            let trackWidth = geo.size.width
                            let minV: Double = 20, maxV: Double = 60 // VO2 Max range
                            let clamped = max(minV, min(maxV, value))
                            let t = (clamped - minV) / (maxV - minV) // 0...1
                            let x = CGFloat(t) * trackWidth - trackWidth/2 // center-based offset
                            
                            ZStack {
                                // Background track
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(BiologyColors.grid.opacity(0.4))
                                    .frame(height: 12)
                                
                                // Active track with gradient
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                BiologyColors.danger.opacity(0.3),
                                                BiologyColors.danger.opacity(0.6),
                                                BiologyColors.danger,
                                                BiologyColors.danger.opacity(0.8)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: trackWidth * CGFloat(t), height: 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Knob indicator
                                Circle()
                                    .fill(.white)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Circle()
                                            .stroke(BiologyColors.danger, lineWidth: 2)
                                    )
                                    .shadow(color: BiologyColors.danger.opacity(0.3), radius: 8, x: 0, y: 4)
                                    .offset(x: x, y: 0)
                                    .scaleEffect(knobScale)
                            }
                        }
                        .frame(height: 12)
                        .cornerRadius(6)
                    }
                } else {
                    // Placeholder for no data
                    Rectangle()
                        .fill(BiologyColors.muted.opacity(0.2))
                        .frame(height: 12)
                        .cornerRadius(6)
                }
            }
        }
        .biologyCard()
        .onAppear {
            // More pronounced entrance pop animation
            if !reduceMotion {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    knobScale = 1.0
                }
            } else {
                knobScale = 1.0
            }
        }
    }
    
    private func vo2MaxColor(for index: Int) -> Color {
        switch index {
        case 0: return BiologyColors.danger.opacity(0.1) // Very pale peach
        case 1: return BiologyColors.danger.opacity(0.2) // Light peach
        case 2: return BiologyColors.danger.opacity(0.4) // Medium peach
        case 3: return BiologyColors.danger.opacity(0.6) // Darker peach
        case 4: return BiologyColors.danger // Strong orange-red
        default: return BiologyColors.muted
        }
    }
    
    private func vo2MaxIndicatorOffset(for value: Double) -> CGFloat {
        // Calculate offset based on VO2 Max value ranges
        switch value {
        case 0..<30: return -66 // Poor
        case 30..<40: return -33 // Fair
        case 40..<50: return 0   // Good
        case 50..<60: return 33  // Very Good
        default: return 66        // Excellent
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Poor": return BiologyColors.danger
        case "Fair": return Color.orange
        case "Good": return BiologyColors.primary
        case "Very Good": return BiologyColors.violet
        case "Excellent": return Color.green
        default: return BiologyColors.muted
        }
    }
}

// MARK: - HRV Baselines Card (Bevel Design)
struct HRVBaselinesCard: View {
    let value: Double
    let status: String
    @State private var lineProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header with icon and title
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16))
                    .foregroundColor(value > 0 ? BiologyColors.primary : BiologyColors.muted)
                
                Text("HRV Baselines")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Spacer()
            }
            
            // Metric and chart in vertical layout
            VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
                // Metric section
                VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                    if value > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(value, specifier: "%.1f")")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("ms")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
                                .baselineOffset(-2)
                        }
                        
                        Text(status)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(statusColor(for: status))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("No data")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("ms")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.muted)
                                .baselineOffset(-2)
                        }
                        
                        Text("Unavailable")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(BiologyColors.muted)
                    }
                }
                
                // Chart section
                if value > 0 {
                    // Bevel-style line chart with animated line drawing
                    GeometryReader { geo in
                        let width = geo.size.width
                        let height = geo.size.height
                        
                        ZStack {
                            // Faint grid lines
                            VStack(spacing: height / 4) {
                                ForEach(0..<3) { _ in
                                    Rectangle()
                                        .fill(BiologyColors.grid.opacity(0.3))
                                        .frame(height: 1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Line chart with animated drawing
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: height * 0.8))
                                path.addLine(to: CGPoint(x: width * 0.2, y: height * 0.6))
                                path.addLine(to: CGPoint(x: width * 0.4, y: height * 0.7))
                                path.addLine(to: CGPoint(x: width * 0.6, y: height * 0.4))
                                path.addLine(to: CGPoint(x: width * 0.8, y: height * 0.3))
                                path.addLine(to: CGPoint(x: width, y: height * 0.2))
                            }
                            .trim(from: 0, to: lineProgress)
                            .stroke(BiologyColors.primary, lineWidth: 2.5)
                            
                            // Endpoint marker with entrance animation
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(BiologyColors.primary, lineWidth: 2)
                                )
                                .shadow(color: BiologyColors.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                                .offset(x: width, y: 0)
                                .scaleEffect(lineProgress > 0.8 ? 1.0 : 0.8)
                                .opacity(lineProgress > 0.8 ? 1.0 : 0.0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .onAppear {
                            // Animated line drawing
                            if !reduceMotion {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    lineProgress = 1.0
                                }
                            } else {
                                lineProgress = 1.0
                            }
                        }
                    }
                } else {
                    // Placeholder for no data
                    Rectangle()
                        .fill(BiologyColors.muted.opacity(0.2))
                        .frame(height: 40)
                        .cornerRadius(6)
                }
            }
        }
        .biologyCard()
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Poor": return BiologyColors.danger
        case "Fair": return Color.orange
        case "Good": return BiologyColors.primary
        case "Very Good": return BiologyColors.violet
        case "Excellent": return Color.green
        default: return BiologyColors.muted
        }
    }
}

// MARK: - RHR Baselines Card (Bevel Design)
struct RHRBaselinesCard: View {
    let value: Double
    let status: String
    @State private var arcProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    // Calculate target arc progress based on value
    private var targetArcProgress: CGFloat {
        let range: ClosedRange<Double> = 40...80
        let p = (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(p)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header with icon and title
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(value > 0 ? BiologyColors.primary : BiologyColors.muted)
                
                Text("RHR Baselines")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Spacer()
            }
            
            // Metric and chart in vertical layout
            VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
                // Metric section
                VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                    if value > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(value, specifier: "%.1f")")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("bpm")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
                                .baselineOffset(-2)
                        }
                        
                        Text(status)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(BiologyColors.text)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("No data")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("bpm")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.muted)
                                .baselineOffset(-2)
                        }
                        
                        Text("Unavailable")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(BiologyColors.muted)
                    }
                }
                
                // Chart section
                if value > 0 {
                    // Bevel-style semicircular gauge with animated arc fill
                    ZStack {
                        // Background track
                        Arc(startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                            .stroke(BiologyColors.grid.opacity(0.6), lineWidth: 8)
                            .frame(height: 24)
                        
                        // Colored arc with animated progress
                        Arc(startAngle: .degrees(180), endAngle: .degrees(180 - (180 * Double(arcProgress))), clockwise: false)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        BiologyColors.primary.opacity(0.3),
                                        BiologyColors.primary.opacity(0.6),
                                        BiologyColors.primary,
                                        BiologyColors.primary.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 8
                            )
                            .frame(height: 24)
                        
                        // Knob indicator with entrance animation
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(BiologyColors.primary, lineWidth: 1.5)
                            )
                            .shadow(color: BiologyColors.primary.opacity(0.12), radius: 6, x: 0, y: 3)
                            .offset(x: 0, y: -12)
                            .scaleEffect(arcProgress > 0.8 ? 1.0 : 0.8)
                            .opacity(arcProgress > 0.8 ? 1.0 : 0.0)
                            .rotationEffect(.degrees(180 * arcProgress))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .onAppear {
                        // Animated arc fill
                        if !reduceMotion {
                            withAnimation(.easeOut(duration: 0.8)) {
                                arcProgress = targetArcProgress
                            }
                        } else {
                            arcProgress = targetArcProgress
                        }
                    }
                } else {
                    // Placeholder for no data
                    Rectangle()
                        .fill(BiologyColors.muted.opacity(0.2))
                        .frame(height: 40)
                        .cornerRadius(6)
                }
            }
        }
        .biologyCard()
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Very Low": return BiologyColors.primary
        case "Excellent": return BiologyColors.primary
        case "Good": return BiologyColors.primary
        case "Fair": return Color.orange
        case "High": return BiologyColors.danger
        default: return BiologyColors.muted
        }
    }
}

// MARK: - Weight Card (Bevel Design)
struct WeightCard: View {
    let value: Double
    let trend: String
    @State private var lineProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header with icon and title
            HStack {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 16))
                    .foregroundColor(value > 0 ? BiologyColors.violet : BiologyColors.muted)
                
                Text("Weight")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Spacer()
            }
            
            // Chart extends behind the metric text
            ZStack {
                // Chart background layer
                if value > 0 {
                    VStack {
                        ZStack {
                            // X-axis tick marks
                            VStack {
                                Spacer()
                                HStack(spacing: 16) {
                                    ForEach(0..<5) { _ in
                                        Rectangle()
                                            .fill(BiologyColors.grid)
                                            .frame(width: 1, height: 4)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                            
                            // Moving average line (dotted)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 60))
                                path.addLine(to: CGPoint(x: 20, y: 55))
                                path.addLine(to: CGPoint(x: 40, y: 58))
                                path.addLine(to: CGPoint(x: 60, y: 52))
                                path.addLine(to: CGPoint(x: 80, y: 48))
                                path.addLine(to: CGPoint(x: 100, y: 50))
                                path.addLine(to: CGPoint(x: 120, y: 44))
                            }
                            .stroke(BiologyColors.violet.opacity(0.28), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            
                            // Main line with animated drawing
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 60))
                                path.addLine(to: CGPoint(x: 20, y: 55))
                                path.addLine(to: CGPoint(x: 40, y: 58))
                                path.addLine(to: CGPoint(x: 60, y: 52))
                                path.addLine(to: CGPoint(x: 80, y: 48))
                                path.addLine(to: CGPoint(x: 100, y: 50))
                                path.addLine(to: CGPoint(x: 120, y: 44))
                            }
                            .trim(from: 0, to: lineProgress)
                            .stroke(BiologyColors.violet, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .shadow(color: BiologyColors.violet.opacity(0.08), radius: 12, x: 0, y: 4)
                            
                            // Endpoint marker with entrance animation
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(BiologyColors.violet, lineWidth: 2)
                                )
                                .shadow(color: BiologyColors.violet.opacity(0.3), radius: 8, x: 0, y: 4)
                                .offset(x: 120, y: 44)
                                .scaleEffect(lineProgress > 0.8 ? 1.0 : 0.8)
                                .opacity(lineProgress > 0.8 ? 1.0 : 0.0)
                            
                            // Target indicator (faint circle)
                            Circle()
                                .stroke(BiologyColors.violet.opacity(0.2), lineWidth: 1)
                                .frame(width: 16, height: 16)
                                .offset(x: 120, y: 44)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .onAppear {
                            // Animated line drawing
                            if !reduceMotion {
                                withAnimation(.easeOut(duration: 0.8)) {
                                    lineProgress = 1.0
                                }
                            } else {
                                lineProgress = 1.0
                            }
                        }
                    }
                } else {
                    // Placeholder for no data
                    Rectangle()
                        .fill(BiologyColors.muted.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .cornerRadius(6)
                }
                
                // Metric text overlay on top
                VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                    if value > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(value, specifier: "%.1f")")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("kg")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
                                .baselineOffset(-2)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(BiologyColors.violet)
                            
                            Text(trend)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.violet)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("No data")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("kg")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.muted)
                                .baselineOffset(-2)
                        }
                        
                        Text("Unavailable")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(BiologyColors.muted)
                    }
                }
                .zIndex(1) // Ensure text is on top
            }
        }
        .biologyCard()
    }
}

// MARK: - Lean Body Mass Card (Bevel Design)
struct LeanBodyMassCard: View {
    let value: Double?
    
    init(value: Double? = nil) {
        self.value = value
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            // Header with icon and title
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16))
                    .foregroundColor(value != nil ? BiologyColors.primary : BiologyColors.muted)
                
                Text("Lean Body Mass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Spacer()
            }
            
            // Metric and chart in vertical layout
            VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
                // Metric section
                VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                    if let value = value {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(value, specifier: "%.1f")")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("kg")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
                                .baselineOffset(-2)
                        }
                        
                        Text("Available")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(BiologyColors.primary)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("No data")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("kg")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.muted)
                                .baselineOffset(-2)
                        }
                        
                        Text("No range")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(BiologyColors.muted)
                    }
                }
                
                // Chart section
                if let value = value {
                    // Bevel-style horizontal track with geometry-based knob positioning
                    GeometryReader { geo in
                        let width = geo.size.width
                        let knobWidth: CGFloat = 10
                        let leftEdge = -width/2 + knobWidth/2
                        let rightEdge = width/2 - knobWidth/2
                        
                        // Assuming 50-100kg range for lean body mass
                        let minV: Double = 50
                        let maxV: Double = 100
                        let clamped = max(minV, min(maxV, value))
                        let t = (clamped - minV) / (maxV - minV) // 0...1 normalized
                        let x = leftEdge + CGFloat(t) * (rightEdge - leftEdge)
                        
                        ZStack {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            BiologyColors.primary.opacity(0.1),
                                            BiologyColors.primary.opacity(0.05)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 6)
                            
                            // Knob with proper positioning
                            Circle()
                                .fill(BiologyColors.muted)
                                .frame(width: knobWidth, height: knobWidth)
                                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                .offset(x: x, y: 0)
                        }
                    }
                    .frame(height: 40)
                } else {
                    // Placeholder for no data
                    Rectangle()
                        .fill(BiologyColors.muted.opacity(0.2))
                        .frame(height: 40)
                        .cornerRadius(6)
                }
            }
        }
        .biologyCard()
    }
}

// MARK: - Body Fat Card (Bevel Design)
struct BodyFatCard: View {
    let value: Double?
    
    init(value: Double? = nil) {
        self.value = value
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
            HStack {
                Image(systemName: "ruler.fill")
                    .font(.system(size: 16))
                    .foregroundColor(value != nil ? BiologyColors.violet : BiologyColors.muted)
                
                Text("Body Fat")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BiologyColors.text)
                
                Spacer()
            }
            
            // Metric and chart in vertical layout
            VStack(alignment: .leading, spacing: BiologySpacing.metricChartSpacing) {
                // Metric section
                VStack(alignment: .leading, spacing: BiologySpacing.textSpacing) {
                    if let value = value {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(value, specifier: "%.1f")")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.subtext)
                                .baselineOffset(-2)
                        }
                        
                        Text("Available")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(BiologyColors.violet)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("No data")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(BiologyColors.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .layoutPriority(1)
                            
                            Text("%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BiologyColors.muted)
                                .baselineOffset(-2)
                        }
                        
                        Text("No range")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(BiologyColors.muted)
                    }
                }
                
                // Chart section
                if let value = value {
                    // Bevel-style horizontal track with geometry-based knob positioning
                    GeometryReader { geo in
                        let width = geo.size.width
                        let knobWidth: CGFloat = 10
                        let leftEdge = -width/2 + knobWidth/2
                        let rightEdge = width/2 - knobWidth/2
                        
                        // Assuming 10-30% range for body fat
                        let minV: Double = 10
                        let maxV: Double = 30
                        let clamped = max(minV, min(maxV, value))
                        let t = (clamped - minV) / (maxV - minV) // 0...1 normalized
                        let x = leftEdge + CGFloat(t) * (rightEdge - leftEdge)
                        
                        ZStack {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            BiologyColors.violet.opacity(0.1),
                                            BiologyColors.violet.opacity(0.05)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 6)
                            
                            // Knob with proper positioning
                            Circle()
                                .fill(BiologyColors.muted)
                                .frame(width: knobWidth, height: knobWidth)
                                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                .offset(x: x, y: 0)
                        }
                    }
                    .frame(height: 40)
                } else {
                    // Placeholder for no data
                    Rectangle()
                        .fill(BiologyColors.muted.opacity(0.2))
                        .frame(height: 40)
                        .cornerRadius(6)
                }
            }
        }
        .biologyCard()
    }
}

// MARK: - Arc Shape for Gauge
struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let clockwise: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        
        return path
    }
}

// MARK: - Preview
struct BiologyView_Previews: PreviewProvider {
    static var previews: some View {
        BiologyView()
    }
}