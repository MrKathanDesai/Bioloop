import SwiftUI

struct NutritionSection: View {
    let nutritionData: NutritionData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            HStack {
                Text("Nutrition")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Today's foods label with arrow
                HStack(spacing: 4) {
                    Text("Today's foods")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            // Main nutrition infographics card
            VStack(spacing: 0) {
                // Top Half - Today's Foods
                VStack(spacing: 20) {
                    // Sub-header with arrow
                    HStack {
                        Text("Today's foods")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Content area with gauge and macronutrients
                    HStack(spacing: 20) {
                        // Circular Gauge (Left side)
                        CircularGaugeView()
                        
                        // Macronutrient Breakdown (Right side)
                        MacronutrientBreakdownView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Divider Line
                Divider()
                    .background(Color(.separator))
                    .padding(.horizontal, 20)
                
                // Bottom Half - Blood Glucose
                HStack {
                    // Left side: Grey dot indicator
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 8, height: 8)
                    
                    // Label
                    Text("Blood glucose")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Right side: Reading placeholder
                    Text("- mg/dl")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 24) // 2xl rounded corners
                    .fill(Color(.systemBackground))
                    .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 12, x: 0, y: 4)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Circular Gauge View
struct CircularGaugeView: View {
    var body: some View {
        ZStack {
            // Semi-circle gauge with faint pastel ticks
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(Color(.systemGray5), lineWidth: 20)
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(180))
            
            // Tick marks around the arc
            ForEach(0..<18, id: \.self) { index in
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: 2, height: 6)
                    .offset(y: -35)
                    .rotationEffect(.degrees(Double(index) * 10 - 90))
            }
            
            // Center value - short grey line
            Rectangle()
                .fill(Color(.systemGray3))
                .frame(width: 20, height: 2)
        }
    }
}

// MARK: - Macronutrient Breakdown View
struct MacronutrientBreakdownView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Carbohydrates (Orange, Left)
            MacronutrientRow(
                icon: "leaf.fill",
                label: "21g",
                color: .orange,
                filledDots: 15,
                totalDots: 20,
                iconColor: .orange
            )
            
            // Protein (Pink, Middle)
            MacronutrientRow(
                icon: "fish.fill",
                label: "5g",
                color: .pink,
                filledDots: 5,
                totalDots: 20,
                iconColor: .pink
            )
            
            // Fats (Blue, Right)
            MacronutrientRow(
                icon: "drop.fill",
                label: "8g",
                color: .blue,
                filledDots: 8,
                totalDots: 20,
                iconColor: .blue
            )
        }
    }
}

// MARK: - Macronutrient Row
struct MacronutrientRow: View {
    let icon: String
    let label: String
    let color: Color
    let filledDots: Int
    let totalDots: Int
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)
            
            // Label
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 30, alignment: .leading)
            
            // Dot Grid (6x6 layout)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 6), spacing: 2) {
                ForEach(0..<totalDots, id: \.self) { index in
                    Circle()
                        .fill(index < filledDots ? color : color.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 48, height: 48)
        }
    }
}

struct NutritionSection_Previews: PreviewProvider {
    static var previews: some View {
        NutritionSection(
            nutritionData: NutritionData(
                carbohydrates: 88,
                fat: 4,
                protein: 0.8,
                lastUpdated: Date()
            )
        )
        .previewLayout(.sizeThatFits)
    }
}
