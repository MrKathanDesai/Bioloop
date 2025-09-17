import Foundation
import SwiftUI

// MARK: - Basic Calendar Types

/// Simple calendar view types for basic functionality
enum CalendarViewType {
    case monthly
    case weekly
}

/// Basic calendar day state
enum CalendarDayState {
    case normal
    case selected
    case today
    case disabled
}
