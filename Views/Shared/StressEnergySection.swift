import SwiftUI

struct StressEnergySection: View {
    let stressMetrics: StressMetrics?
    let energyLevel: EnergyLevel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section title
            Text("Stress & Energy")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            if let stress = stressMetrics {
                // Stress overview row
                HStack {
                    // Left side - stress metrics
                    VStack(alignment: .leading, spacing: 12) {
                        // Today's stress label
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            
                            Text("Today's stress")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Last updated
                        Text("Last updated at \(timeString(from: stress.lastUpdated))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        // Stress metrics
                        HStack(spacing: 20) {
                            StressMetricItem(
                                value: stress.highest,
                                label: "Highest",
                                color: .orange
                            )
                            
                            StressMetricItem(
                                value: stress.lowest,
                                label: "Lowest",
                                color: .blue
                            )
                            
                            StressMetricItem(
                                value: stress.average,
                                label: "Average",
                                color: .green
                            )
                        }
                    }
                    
                    Spacer()
                    
                    // Right side - stress dial
                    VStack(spacing: 8) {
                        StressDial(value: stress.current, level: stress.level)
                        
                        HStack(spacing: 4) {
                            Text("Med")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if let energy = energyLevel {
                // Energy bar
                EnergyBar(percentage: energy.percentage, level: energy.level)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StressMetricItem: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct StressEnergySection_Previews: PreviewProvider {
    static var previews: some View {
        StressEnergySection(
            stressMetrics: StressMetrics(
                highest: 75,
                lowest: 0,
                average: 12,
                current: 48,
                level: .moderate,
                lastUpdated: Date()
            ),
            energyLevel: EnergyLevel(
                percentage: 90,
                level: .high,
                lastUpdated: Date()
            )
        )
        .previewLayout(.sizeThatFits)
    }
}
