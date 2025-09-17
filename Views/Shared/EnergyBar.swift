import SwiftUI

struct EnergyBar: View {
    let percentage: Int
    let level: EnergyLevel.Level
    let height: CGFloat
    
    init(percentage: Int, level: EnergyLevel.Level, height: CGFloat = 12) {
        self.percentage = percentage
        self.level = level
        self.height = height
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Lightning icon
            Image(systemName: "bolt.fill")
                .font(.system(size: height * 0.8))
                .foregroundColor(.green)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color(.systemGray5))
                        .frame(height: height)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(energyColor)
                        .frame(width: geometry.size.width * progress, height: height)
                        .overlay(
                            // Tick marks
                            HStack(spacing: 0) {
                                ForEach(0..<Int(progress * 10), id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 1, height: height * 0.6)
                                        .padding(.leading, 1)
                                }
                            }
                        )
                }
            }
            .frame(height: height)
            
            // Percentage text
            Text("\(percentage)%")
                .font(.system(size: height * 0.8, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    private var progress: Double {
        return Double(percentage) / 100.0
    }
    
    private var energyColor: Color {
        switch level {
        case .low:
            return .red
        case .medium:
            return .orange
        case .high:
            return .green
        }
    }
}

struct EnergyBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EnergyBar(percentage: 25, level: .low)
            EnergyBar(percentage: 60, level: .medium)
            EnergyBar(percentage: 90, level: .high)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
