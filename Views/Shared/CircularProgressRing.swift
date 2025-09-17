import SwiftUI

struct CircularProgressRing: View {
    let value: Double
    let maxValue: Double
    let lineWidth: CGFloat
    let color: Color
    let showValue: Bool
    let size: CGFloat
    
    init(
        value: Double,
        maxValue: Double = 100,
        lineWidth: CGFloat = 8,
        color: Color,
        showValue: Bool = true,
        size: CGFloat = 80
    ) {
        self.value = value
        self.maxValue = maxValue
        self.lineWidth = lineWidth
        self.color = color
        self.showValue = showValue
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    Color(.systemGray5),
                    lineWidth: lineWidth
                )
                .frame(width: size, height: size)
            
            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
            
            // Center content
            if showValue {
                VStack(spacing: 2) {
                    Text("\(Int(value))%")
                        .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    private var progress: Double {
        return min(max(value / maxValue, 0), 1)
    }
}

struct CircularProgressRing_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                CircularProgressRing(value: 25, color: .orange)
                CircularProgressRing(value: 95, color: .green)
                CircularProgressRing(value: 73, color: .blue)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
