import Foundation
import SwiftUI

// MARK: - Health Status
enum HealthStatus {
    case optimal
    case moderate
    case poor
    case critical
    case unavailable
}

// MARK: - Date Extensions
extension Date {
    /// Returns the start of the day for this date
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Returns the end of the day for this date
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    /// Returns true if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Returns true if this date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Returns the number of days between this date and another date
    func daysBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: date)
        return components.day ?? 0
    }
    
    /// Returns a formatted string for time display
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Returns a formatted string for date display
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
    
    /// Returns a relative time string (e.g., "2 hours ago")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: self)
    }
    
    var monthDayYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }
}

// MARK: - Double Extensions
extension Double {
    /// Formats a double value for display with appropriate decimal places
    func formatted(decimals: Int = 1) -> String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.\(decimals)f", self)
        }
    }
    
    /// Converts seconds to hours and minutes string
    var durationString: String {
        let hours = Int(self) / 3600
        let minutes = Int(self.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Converts a percentage to a 0-1 range for progress views
    var asProgress: Double {
        return max(0, min(1, self / 100))
    }
    
    /// Clamps a value between min and max
    func clamped(min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, self))
    }
}

// MARK: - Color Extensions
extension Color {
    /// Health status colors
    static let healthOptimal = Color.green
    static let healthModerate = Color.orange
    static let healthPoor = Color.red
    static let healthCritical = Color.red.opacity(0.8)
    static let healthUnavailable = Color.gray
    
    /// App theme colors
    static let primaryBlue = Color.blue
    static let backgroundGray = Color(.systemGray6)
    static let cardBackground = Color(.systemBackground)
    
    /// Creates a color from health status
    static func from(status: HealthStatus) -> Color {
        switch status {
        case .optimal:
            return .healthOptimal
        case .moderate:
            return .healthModerate
        case .poor:
            return .healthPoor
        case .critical:
            return .healthCritical
        case .unavailable:
            return .healthUnavailable
        }
    }
    
    /// Initialize a Color from a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a card style with shadow and corner radius
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
    }
    
    /// Applies a subtle card style
    func subtleCardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.backgroundGray)
            )
    }
    
    /// Conditional view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Adds a loading overlay
    func loadingOverlay(_ isLoading: Bool) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.1))
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                        )
                }
            }
        )
    }
}

// MARK: - Array Extensions
extension Array where Element == Double {
    /// Calculates the average of an array of doubles
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    
    /// Calculates the standard deviation
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = average
        let variance = map { pow($0 - avg, 2) }.average
        return sqrt(variance)
    }
    
    /// Returns the last n elements
    func last(_ n: Int) -> [Double] {
        return Array(suffix(n))
    }
}

// MARK: - String Extensions
extension String {
    /// Capitalizes the first letter of the string
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).capitalized + dropFirst()
    }
    
    /// Truncates a string to a maximum length
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count <= length {
            return self
        } else {
            return String(prefix(length)) + trailing
        }
    }
}

// MARK: - HealthStatus Extensions
extension HealthStatus {
    /// Returns the appropriate SF Symbol for the health status
    var icon: String {
        switch self {
        case .optimal:
            return "checkmark.circle.fill"
        case .moderate:
            return "exclamationmark.triangle.fill"
        case .poor:
            return "xmark.circle.fill"
        case .critical:
            return "exclamationmark.triangle.fill"
        case .unavailable:
            return "questionmark.circle.fill"
        }
    }
    
    /// Returns a descriptive message for the health status
    var message: String {
        switch self {
        case .optimal:
            return "Excellent"
        case .moderate:
            return "Good"
        case .poor:
            return "Needs Attention"
        case .critical:
            return "Critical - Action Needed"
        case .unavailable:
            return "No Data"
        }
    }
}

// MARK: - TimeInterval Extensions
extension TimeInterval {
    /// Converts TimeInterval to hours
    var hours: Double {
        return self / 3600
    }
    
    /// Converts TimeInterval to minutes
    var minutes: Double {
        return self / 60
    }
    
    /// Returns a formatted string for sleep duration
    var sleepDurationString: String {
        let hours = Int(self) / 3600
        let minutes = Int(self.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
} 