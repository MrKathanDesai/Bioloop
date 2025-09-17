import SwiftUI

struct StressDial: View {
    let value: Int
    let level: StressMetrics.StressLevel
    let size: CGFloat
    
    init(value: Int, level: StressMetrics.StressLevel, size: CGFloat = 60) {
        self.value = value
        self.level = level
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: size, height: size)
            
            // Semi-circular progress arc
            Circle()
                .trim(from: 0.25, to: 0.75)
                .stroke(
                    stressColor,
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            
            // Center content
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(level.rawValue)
                    .font(.system(size: size * 0.2, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var stressColor: Color {
        switch level {
        case .low:
            return .green
        case .moderate:
            return .orange
        case .high:
            return .red
        }
    }
}

struct StressDial_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            StressDial(value: 25, level: .low)
            StressDial(value: 48, level: .moderate)
            StressDial(value: 75, level: .high)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
