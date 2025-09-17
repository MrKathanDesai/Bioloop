import SwiftUI

struct CoreRingsSection: View {
    let recoveryScore: Double
    let sleepScore: Double
    let strainScore: Double
    let coachingMessage: CoachingMessage?
    
    var body: some View {
        VStack(spacing: 20) {
            // Core rings
            HStack(spacing: 30) {
                // Strain ring
                VStack(spacing: 8) {
                    CircularProgressRing(
                        value: strainScore,
                        color: .orange,
                        size: 80
                    )
                    Text("Strain")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Recovery ring
                VStack(spacing: 8) {
                    CircularProgressRing(
                        value: recoveryScore,
                        color: .green,
                        size: 80
                    )
                    Text("Recovery")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Sleep ring
                VStack(spacing: 8) {
                    CircularProgressRing(
                        value: sleepScore,
                        color: .blue,
                        size: 80
                    )
                    Text("Sleep")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Coaching message
            if let coaching = coachingMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COACHING")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                    
                    Text(coaching.message)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
    }
}

struct CoreRingsSection_Previews: PreviewProvider {
    static var previews: some View {
        CoreRingsSection(
            recoveryScore: 95,
            sleepScore: 73,
            strainScore: 25,
            coachingMessage: CoachingMessage(
                message: "Excellent recovery! Target a Strain level of 24% - 62% for optimal training today.",
                type: .recovery,
                priority: .high
            )
        )
        .previewLayout(.sizeThatFits)
    }
}
