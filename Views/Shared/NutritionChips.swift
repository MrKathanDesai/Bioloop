import SwiftUI

struct NutritionChips: View {
    let nutritionData: NutritionData
    
    var body: some View {
        HStack(spacing: 12) {
            // Carbohydrates
            NutritionChip(
                icon: "leaf.fill",
                value: nutritionData.carbohydrates,
                unit: "g",
                color: .orange,
                label: "Carbs"
            )
            
            // Fat
            NutritionChip(
                icon: "drop.fill",
                value: nutritionData.fat,
                unit: "g",
                color: .pink,
                label: "Fat"
            )
            
            // Protein
            NutritionChip(
                icon: "flask.fill",
                value: nutritionData.protein,
                unit: "g",
                color: .blue,
                label: "Protein"
            )
        }
    }
}

struct NutritionChip: View {
    let icon: String
    let value: Double
    let unit: String
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            // Icon and value
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // Label
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

struct NutritionChips_Previews: PreviewProvider {
    static var previews: some View {
        NutritionChips(
            nutritionData: NutritionData(
                carbohydrates: 88,
                fat: 4,
                protein: 0.8,
                lastUpdated: Date()
            )
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
