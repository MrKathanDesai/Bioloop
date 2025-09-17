import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        icon: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            EmptyStateView(
                title: "No Data Available",
                message: "Connect your Apple Watch to see your health metrics",
                icon: "applewatch"
            )
            
            EmptyStateView(
                title: "Feature Coming Soon",
                message: "This feature is under development and will be available in a future update",
                icon: "hammer.fill",
                actionTitle: "Learn More"
            ) {
                print("Learn more tapped")
            }
        }
    }
} 