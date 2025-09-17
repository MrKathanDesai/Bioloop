import Foundation
import HealthKit

// MARK: - Core Health Data Models

/// Raw health data from HealthKit
struct HealthData {
    var date: Date
    var hrv: Double?          // Heart Rate Variability (SDNN in ms)
    var restingHeartRate: Double?  // Resting Heart Rate (BPM)
    var heartRate: Double?    // Active Heart Rate (BPM)
    var energyBurned: Double? // Active Energy Burned (kcal)
    var sleepStart: Date?     // Sleep start time
    var sleepEnd: Date?       // Sleep end time
    var sleepDuration: Double? // Sleep duration (hours)
    var sleepEfficiency: Double? // Sleep efficiency (0-1)
    var deepSleep: Double?    // Deep sleep duration (hours)
    var remSleep: Double?     // REM sleep duration (hours)
    var wakeEvents: Int?      // Number of wake events
    var workoutMinutes: Double? // Workout duration (minutes)
    var vo2Max: Double?       // VO2 Max (ml/kg/min)
    var weight: Double?       // Body weight (kg)
    var leanBodyMass: Double? // Lean body mass (kg)
    var bodyFat: Double?      // Body fat percentage (%)

    /// Check if we have enough data for recovery score
    var hasRecoveryData: Bool {
        return hrv != nil || restingHeartRate != nil || sleepEfficiency != nil
    }

    /// Check if we have enough data for sleep score
    var hasSleepData: Bool {
        return sleepDuration != nil || sleepEfficiency != nil
    }

    /// Check if we have enough data for strain score
    var hasStrainData: Bool {
        return energyBurned != nil || workoutMinutes != nil || heartRate != nil
    }
}

/// Health scores calculated from raw data
struct HealthScore {
    var recovery: ScoreComponent
    var sleep: ScoreComponent
    var strain: ScoreComponent
    var stress: ScoreComponent
    var date: Date
    var dataAvailability: DataAvailability

    var isDataAvailable: Bool {
        return dataAvailability.isFullyAvailable
    }

    struct ScoreComponent {
        var value: Double          // 0-100 score
        var status: ScoreStatus    // Ready, Low, High, Unavailable
        var trend: [Double]?       // Last 7 days for mini chart
        var subMetrics: [String: Double]? // Detailed metrics

        var isDataAvailable: Bool {
            return value > 0 && status != .unavailable
        }
    }

    enum ScoreStatus {
        case optimal, moderate, poor, unavailable

        var color: String {
            switch self {
            case .optimal: return "green"
            case .moderate: return "yellow"
            case .poor: return "red"
            case .unavailable: return "gray"
            }
        }
    }
}

/// Data availability status
struct DataAvailability {
    var hasHealthKitPermission: Bool = false
    var hasAppleWatchData: Bool = false
    var lastSyncDate: Date?
    var missingDataTypes: [String] = []

    var isFullyAvailable: Bool {
        return hasHealthKitPermission && hasAppleWatchData
    }
}

/// Baseline data for score calculations
struct HealthBaseline {
    var hrvBaseline: Double?      // Average HRV over 30 days
    var rhrBaseline: Double?      // Average RHR over 30 days
    var sleepBaseline: Double?    // Average sleep duration
    var energyBaseline: Double?   // Average daily energy burn

    mutating func update(with data: HealthData) {
        // Simple baseline calculation - in production, you'd use more sophisticated methods
        if let hrv = data.hrv {
            hrvBaseline = (hrvBaseline ?? hrv + 10) * 0.95 + hrv * 0.05 // Moving average
        }
        if let rhr = data.restingHeartRate {
            rhrBaseline = (rhrBaseline ?? rhr + 5) * 0.95 + rhr * 0.05
        }
        if let sleep = data.sleepDuration {
            sleepBaseline = (sleepBaseline ?? sleep) * 0.95 + sleep * 0.05
        }
        if let energy = data.energyBurned {
            energyBaseline = (energyBaseline ?? energy) * 0.95 + energy * 0.05
        }
    }
}

/// Journal Entry for lifestyle tracking
struct JournalEntry: Identifiable {
    var id = UUID()
    var date: Date
    var title: String
    var content: String
    var mood: Int? // 1-5 scale
    var factors: [String] // Caffeine, exercise, sleep quality, etc.

    static func sampleEntries() -> [JournalEntry] {
        return [
            JournalEntry(
                date: Date(),
                title: "Morning Check-in",
                content: "Feeling good after yesterday's workout",
                mood: 4,
                factors: ["Exercise", "Sleep"]
            )
        ]
    }
}

// MARK: - Journal Question Types (for compatibility with existing views)

enum JournalQuestionType {
    case text
    case scale(ClosedRange<Int>)
    case multipleChoice
    case boolean
    case yesNo
    case numeric(String?) // Optional unit parameter
    case time
    case counter
}

enum JournalAnswer {
    case yes
    case no
    case maybe
}

struct JournalQuestion {
    var id: String
    var type: JournalQuestionType
    var title: String
    var options: [String]?

    // Alias for compatibility with existing views
    var question: String {
        return title
    }
}

enum JournalResponseValue {
    case text(String)
    case scale(Int)
    case multipleChoice(String)
    case boolean(Bool)
    case number(Int)
    case time(Date)

    var displayText: String {
        switch self {
        case .text(let value):
            return value
        case .scale(let value):
            return "\(value)"
        case .multipleChoice(let value):
            return value
        case .boolean(let value):
            return value ? "Yes" : "No"
        case .number(let value):
            return "\(value)"
        case .time(let value):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: value)
        }
    }
}

// MARK: - SubMetric (for compatibility with existing views)
struct SubMetric {
    var name: String
    var value: Double
    var unit: String?
    var status: String?
    var optimalRange: ClosedRange<Double>? // Optional optimal range for display

    var isDataAvailable: Bool {
        return value > 0 // Simple check - data is available if value > 0
    }
}

// MARK: - Enhanced UI Data Models

/// Coaching message for user guidance
struct CoachingMessage {
    var message: String
    var type: CoachingType
    var priority: Priority
    
    enum CoachingType {
        case recovery, sleep, strain, stress, general
    }
    
    enum Priority {
        case high, medium, low
        
        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "yellow"
            case .low: return "red"
            }
        }
    }
}

/// Stress metrics for detailed stress tracking
struct StressMetrics {
    var highest: Int
    var lowest: Int
    var average: Int
    var current: Int
    var level: StressLevel
    var lastUpdated: Date
    
    enum StressLevel: String {
        case low = "Low"
        case moderate = "Med"
        case high = "High"
        
        var color: String {
            switch self {
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "red"
            }
        }
    }
}

/// Energy level tracking
struct EnergyLevel {
    var percentage: Int
    var level: Level
    var lastUpdated: Date
    
    enum Level: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var color: String {
            switch self {
            case .low: return "red"
            case .medium: return "yellow"
            case .high: return "green"
            }
        }
    }
}

/// Nutrition data for macronutrient tracking
struct NutritionData {
    var carbohydrates: Double // in grams
    var fat: Double // in grams
    var protein: Double // in grams
    var lastUpdated: Date
    
    var totalCalories: Double {
        return carbohydrates * 4 + fat * 9 + protein * 4
    }
}

/// User profile information
struct UserProfile {
    var initials: String
    var name: String
    var avatarURL: URL?
    
    init(initials: String, name: String, avatarURL: URL? = nil) {
        self.initials = initials
        self.name = name
        self.avatarURL = avatarURL
    }
}
