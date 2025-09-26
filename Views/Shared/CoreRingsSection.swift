import SwiftUI

struct CoreRingsSection: View {
    let recoveryState: ScoreState
    let sleepState: ScoreState
    let strainState: ScoreState
    let coachingMessage: CoachingMessage?
    
    var body: some View {
        VStack(spacing: 20) {
            // Core rings
            HStack(spacing: 30) {
                // Strain ring
                VStack(spacing: 8) {
                    RingView(state: strainState, color: .orange)
                    Text("Strain")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Recovery ring
                VStack(spacing: 8) {
                    RingView(state: recoveryState, color: .green)
                    Text("Recovery")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Sleep ring
                VStack(spacing: 8) {
                    RingView(state: sleepState, color: .blue)
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

private struct RingView: View {
    let state: ScoreState
    let color: Color
    let size: CGFloat = 80
    
    var body: some View {
        switch state {
        case .pending:
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: size, height: size)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.gray)
            }
        case .unavailable(let reason):
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: size, height: size)
                VStack(spacing: 2) {
                    Image(systemName: "slash.circle")
                        .foregroundColor(.gray)
                    if let reason = reason {
                        Text(reason)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        case .computed(let value):
            ZStack {
                CircularProgressRing(
                    value: Double(value),
                    maxValue: 100,
                    lineWidth: 10,
                    color: color,
                    showValue: false,
                    size: size
                )
                Text("\(value)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
    }
}

struct CoreRingsSection_Previews: PreviewProvider {
    static var previews: some View {
        CoreRingsSection(
            recoveryState: .computed(95),
            sleepState: .pending,
            strainState: .unavailable(reason: "No recent data"),
            coachingMessage: CoachingMessage(
                message: "Excellent recovery! Target a Strain level of 24% - 62% for optimal training today.",
                type: .recovery,
                priority: .high
            )
        )
        .previewLayout(.sizeThatFits)
    }
}
