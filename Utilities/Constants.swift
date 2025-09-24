import Foundation
import SwiftUI

// MARK: - App Constants
struct Constants {
    
    // MARK: - Icons
    struct Icons {
        static let recovery = "heart.fill"
        static let sleep = "moon.fill"
        static let strain = "bolt.fill"
        static let stress = "brain.head.profile"
    }
    
    // MARK: - Colors
    struct Colors {
        static let recoveryColor = Color.green
        static let sleepColor = Color.blue
        static let strainColor = Color.orange
        static let stressColor = Color.red
    }
    
    // MARK: - Strings
    struct Strings {
        // Health Score Descriptions
        static let recovery = "Recovery score reflects your body's readiness for strain based on HRV, resting heart rate, and sleep quality."
        static let sleep = "Sleep score evaluates your sleep duration, efficiency, and sleep stage distribution for optimal recovery."
        static let strain = "Strain score measures your cardiovascular and muscular exertion during activities and workouts."
        static let stress = "Stress score indicates your physiological stress levels based on HRV variability and breathing patterns."
        
        // Journal Categories
        static let all = "All"
        static let circadianHealth = "Circadian Health"
        static let lifestyle = "Lifestyle"
        static let medication = "Medication"
        static let nutrition = "Nutrition"
        static let sleep_category = "Sleep"
        
        // Journal Items - Lifestyle
        static let acupuncture = "Acupuncture"
        static let airTravel = "Air Travel"
        static let alcohol = "Alcohol"
        static let anxiety = "Anxiety"
        static let coldExposure = "Cold Exposure"
        static let exercise = "Exercise"
        static let meditation = "Meditation"
        static let stress_category = "Stress"
        
        // Journal Items - Nutrition
        static let addedSugar = "Added Sugar"
        static let caffeine = "Caffeine"
        static let lateMeals = "Late Meals"
        static let supplements = "Supplements"
        static let waterIntake = "Water Intake"
        
        // Journal Items - Medication
        static let adhdMedication = "ADHD Medication"
        static let antiAnxietyMedication = "Anti-Anxiety Medication"
        static let antiInflammatory = "Anti-Inflammatory"
        
        // Journal Items - Circadian Health
        static let artificialLight = "Artificial Light"
        static let blueLightExposure = "Blue Light Exposure"
        
        // Journal Items - Sleep
        static let sleepQuality = "Sleep Quality"
        
        // UI Titles and Labels
        static let customizeJournalTitle = "CUSTOMIZE JOURNAL"
        static let done = "Done"
        
        // Category Descriptions
        static let optimizeNaturalRhythm = "Optimize your natural circadian rhythm"
        static let trackDailyHabits = "Track daily habits and lifestyle factors"
        static let monitorMedicationEffects = "Monitor medication effects on your health"
        static let trackNutritionFactors = "Track nutrition factors affecting your wellbeing"
        static let trackSleepQuality = "Track sleep quality and recovery metrics"
        static let dailyTracking = "Daily tracking for optimal health insights"
        
        // General
        static let noData = "--"
        static let noDataAvailable = "No Data"
        static let dataUnavailable = "Data Unavailable"
        static let excellent = "Excellent"
        static let good = "Good"
        static let average = "Average"
        static let belowAverage = "Below Average"
        static let poor = "Poor"
        static let normalStatus = "Normal"
        static let healthyRange = "Healthy Range"
        static let sevenDays = "7 Days"
        static let insufficientDataForTrend = "Insufficient data for trend"
        
        // Biology View Strings
        static let biologyTitle = "Biology"
        static let vo2MaxTitle = "VO₂ Max"
        static let vo2MaxUnit = "ml/kg/min"
        static let vo2MaxMetricName = "VO₂ Max"
        static let vo2MaxExplanation = "VO₂ max measures your body's maximum oxygen uptake during exercise."
        static let vo2MaxRecommendation1 = "Incorporate high-intensity interval training"
        static let vo2MaxRecommendation2 = "Focus on cardiovascular endurance exercises"
        static let vo2MaxRecommendation3 = "Maintain consistent aerobic training"
        static let vo2MaxRecommendation4 = "Allow adequate recovery between sessions"
        
        static let hrvBaselineTitle = "HRV Baseline"
        static let hrvUnit = "ms"
        static let hrvMetricName = "Heart Rate Variability"
        static let hrvExplanation = "HRV measures the variation in time between heartbeats, indicating recovery status."
        static let hrvRecommendation1 = "Prioritize quality sleep for better HRV"
        static let hrvRecommendation2 = "Manage stress through meditation"
        static let hrvRecommendation3 = "Avoid excessive alcohol consumption"
        static let hrvRecommendation4 = "Maintain consistent sleep schedule"
        
        static let rhrBaselineTitle = "RHR Baseline"
        static let rhrUnit = "bpm"
        static let rhrMetricName = "Resting Heart Rate"
        static let rhrExplanation = "Your resting heart rate indicates cardiovascular fitness and recovery."
        static let rhrRecommendation1 = "Improve cardiovascular fitness through aerobic exercise"
        static let rhrRecommendation2 = "Ensure adequate hydration"
        static let rhrRecommendation3 = "Get sufficient sleep for recovery"
        static let rhrRecommendation4 = "Monitor for signs of overtraining"
        
        static let weightTitle = "Weight"
        static let weightUnit = "kg"
        static let weightMetricName = "Body Weight"
        static let weightExplanation = "Regular weight tracking helps monitor health and fitness progress."
        static let weightRecommendation1 = "Maintain a balanced, nutritious diet"
        static let weightRecommendation2 = "Combine strength training with cardio"
        static let weightRecommendation3 = "Stay consistently hydrated"
        static let weightRecommendation4 = "Focus on gradual, sustainable changes"
        
        static let bodyCompositionTitle = "Body Composition"
        static let bodyFatTitle = "Body Fat"
        static let bodyFatUnit = "%"
        static let bloodOxygenTitle = "Blood Oxygen"
        static let bloodOxygenUnit = "%"
        static let noWeightData = "No weight data available"
        static let connectScalePrompt = "Connect a smart scale for automatic tracking"
        
        // Fitness View Strings
        static let fitnessTitle = "Fitness"
        static let last30Days = "Last 30 Days"
        static let activitySummaryTitle = "Activity Summary"
        static let activitySummaryTapped = "Activity Summary Tapped"
        static let strainPerformanceTitle = "Strain Performance"
        static let strainPerformanceTapped = "Strain Performance Tapped"
        static let cardioTitle = "Cardio Fitness"
        static let strengthTitle = "Strength Training"
        static let noActivityDataAvailable = "No activity data available"
        static let noStrainDataAvailable = "No strain data available"
        static let noCardioLoadDataAvailable = "No cardio load data available"
        static let cardioFocusTitle = "Cardio Focus"
        static let oneActivity = "1 Activity"
        static let belowTarget = "Below Target"
        static let cardioLoadTitle = "Cardio Load"
        static let cardioLoadTapped = "Cardio Load Tapped"
        static let totalVolumeTitle = "Total Volume"
        static let totalVolumeTapped = "Total Volume Tapped"
        static let twoActivities = "2 Activities"
        static let detraining = "Detraining"
        static let chest = "Chest"
        static let threePlusActivities = "3+ Activities"
        static let cardioFocusTapped = "Cardio Focus Tapped"
        static let arms = "Arms"
        static let hrrTitle = "Heart Rate Recovery"
        static let hrrTapped = "Heart Rate Recovery Tapped"
        static let back = "Back"
        static let core = "Core"
        static let legs = "Legs"
        static let shoulders = "Shoulders"
        static let strengthProgressionTitle = "Strength Progression"
        static let strengthProgressionTapped = "Strength Progression Tapped"
        static let noProgressionData = "No progression data available."
        static let noStrengthActivity = "No strength activity available"
        
        // Day abbreviations
        static let M = "M"
        static let T = "T"
        static let W = "W"
        static let F = "F"
        static let S = "S"
        
        // Home View Strings
        static let healthCalendarTitle = "Health Calendar"
        static let readyToOptimize = "Ready to optimize your health?"
        static let recoveryTitle = "Recovery"
        static let strainTitle = "Strain"
        static let stressTitle = "Stress"
        static let welcome = "Welcome"
        static let needsAttention = "Needs Attention"
        static let noDataHome = "No Data Available"
        static let goodMorning = "Good Morning"
        static let goodAfternoon = "Good Afternoon"
        static let goodEvening = "Good Evening"
        static let goodNight = "Good Night"
        static let home = "Home"
        static let biology = "Biology"
        static let fitness = "Fitness"
        static let journal = "Journal"
        static let weekly = "Weekly"
        
        // Journal View Strings
        static let journalTitle = "Journal"
        static let selectDate = "Select Date"
        static let cancel = "Cancel"
        static let tapToAnswer = "Tap to answer"
        static let addNote = "Add note"
        
        // Weekly View Strings
        static let weeklyTitle = "Weekly"
        static let trendAnalysisTitle = "Trend Analysis"
        static let recommendationsTitle = "Recommendations"
        static let recoveryStatusTitle = "Recovery Status"
        static let sleepQualityTitle = "Sleep Quality"
        static let activityLevelTitle = "Activity Level"
        static let noTrendDataTitle = "No Trend Data"
        static let noTrendDataSubtitle = "Not enough data to show trends"
        static let noRecommendationsTitle = "No Recommendations"
        static let noRecommendationsSubtitle = "Keep tracking to get personalized insights"
        static let fair = "Fair"
        static let noRecoveryData = "No recovery data available"
        static let monitorHRVAndRest = "Monitor HRV and get adequate rest"
        static let noSleepData = "No sleep data available"
        static let focusOnSleepSchedule = "Focus on consistent sleep schedule"
        static let noActivityData = "No activity data available"
        static let balanceTrainingAndRecovery = "Balance training with recovery"
        static let primaryFocus = "Primary Focus"
        static let sleepOptimization = "Sleep Optimization"
        static let activityBalance = "Activity Balance"
        static let healthTip = "Health Tip"
        static let connectBluetoothScale = "Connect a bluetooth scale for body composition"
        static let sleepTitle = "Sleep"
        
        // Stress View Strings
        static let noStressData = "No stress data available"

        // Home View
        static let today = "Today"
        static let lastUpdated = "Last Updated"
        static let noStrainData = "No Strain Data"
        static let enableHealth = "Enable HealthKit to start tracking"
        static let getStarted = "Get Started"
        
        // App/Onboarding Strings
        static let onboarding_completed = "onboarding_completed"
        static let welcomeToBioloop = "Welcome to Bioloop"
        static let healthOptimizationCompanion = "Your health optimization companion"
        static let trackAndOptimize = "Track and optimize your health metrics"
        static let healthDataAccess = "Health Data Access"
        static let enableHealthData = "Enable Health Data"
        static let weNeedAccess = "We need access to your health data"
        static let permissionNotGranted = "Permission not granted"
        static let permissionRequestTimedOut = "Permission request timed out"
        static let healthDataNotAvailable = "Health data not available"
        static let requestingPermission = "Requesting Permission"
        static let enableHealthDataButton = "Enable Health Data"
        static let continueButton = "Continue"
        static let checkAgain = "Check Again"
        static let alreadyGranted = "Already Granted"
        static let skipForNow = "Skip for Now"
    }
}

// MARK: - Health Metrics Configuration
struct HealthMetricsConfiguration {
    static let recencyWindowWatch: TimeInterval = 7 * 24 * 60 * 60
    static let displayWindow: TimeInterval = 365 * 24 * 60 * 60
    static let snapshotDebounceInterval: TimeInterval = 1.0
}

// Keeping existing AppConstants for backward compatibility  
struct AppConstants {
    
    // MARK: - Health Score Ranges
    struct HealthScoreRanges {
        static let optimal = 70.0...100.0
        static let moderate = 40.0..<70.0
        static let poor = 0.0..<40.0
    }
    
    // MARK: - Optimal Health Values
    struct OptimalRanges {
        // Recovery metrics
        static let hrvOptimal = 30.0...60.0 // milliseconds
        static let restingHROptimal = 50.0...70.0 // bpm
        static let sleepEfficiencyOptimal = 85.0...100.0 // percentage
        
        // Sleep metrics
        static let sleepDurationOptimal = 7.0...9.0 // hours
        static let remSleepOptimal = 15.0...25.0 // percentage
        static let deepSleepOptimal = 15.0...20.0 // percentage
        
        // Strain metrics
        static let activeEnergyDaily = 300.0...600.0 // kcal
        static let workoutTimeDaily = 30.0...90.0 // minutes
        
        // Stress metrics
        static let hrvStabilityOptimal = 80.0...100.0 // percentage
        static let breathingRateOptimal = 12.0...20.0 // breaths per minute
    }
    
    // MARK: - Data Timeframes
    struct DataTimeframes {
        static let dailyHours = 24
        static let weeklyDays = 7
        static let monthlyDays = 30
        static let hrvAnalysisDays = 7
        static let trendAnalysisDays = 14
    }
    
    // MARK: - UI Constants
    struct UI {
        static let cardCornerRadius: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 16
        static let trendChartHeight: CGFloat = 60
        static let scoreCardHeight: CGFloat = 200
        static let animationDuration: Double = 0.3
        static let hapticFeedbackDelay: Double = 0.1
    }
    
    // MARK: - Chart Configuration
    struct Charts {
        static let trendLineWidth: CGFloat = 2
        static let maxTrendPoints = 7
        static let chartAnimationDuration: Double = 0.8
        static let gridlineColor = Color.gray.opacity(0.2)
    }
    
    // MARK: - App Configuration
    struct AppConfig {
        static let appName = "Bioloop"
        static let appVersion = "1.0.0"
        static let minIOSVersion = "16.0"
        static let developerEmail = "support@bioloop.app"
        static let privacyPolicyURL = "https://bioloop.app/privacy"
        static let termsOfServiceURL = "https://bioloop.app/terms"
    }
    
    // MARK: - HealthKit Configuration
    struct HealthKit {
        static let minDataPoints = 3 // Minimum data points needed for score calculation
        static let maxRetryAttempts = 3
        static let cacheExpirationHours = 1
        static let backgroundRefreshInterval: TimeInterval = 3600 // 1 hour
    }
    
    // MARK: - Notification Time
struct NotificationTime {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    var dateComponents: DateComponents {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }
}

// MARK: - Notification Configuration
    struct Notifications {
        static let defaultBreathingReminderTimes = [
            NotificationTime(hour: 9, minute: 0),
            NotificationTime(hour: 17, minute: 0)
        ]
        static let defaultJournalReminderTime = NotificationTime(hour: 21, minute: 0)
        static let defaultSleepReminderTime = NotificationTime(hour: 22, minute: 0)
        
        // Notification identifiers
        static let breathingReminderID = "breathing_reminder"
        static let journalReminderID = "journal_reminder"
        static let sleepReminderID = "sleep_reminder"
        static let weeklyReportID = "weekly_report"
        static let healthInsightID = "health_insight"
    }
    
    // MARK: - User Defaults Keys
    struct UserDefaultsKeys {
        static let userProfile = "user_profile"
        static let onboardingCompleted = "onboarding_completed"
        static let lastHealthKitSync = "last_healthkit_sync"
        static let notificationsEnabled = "notifications_enabled"
        static let firstLaunchDate = "first_launch_date"
        static let appLaunchCount = "app_launch_count"
    }
    
    // MARK: - API Configuration (for future use)
    struct API {
        static let baseURL = "https://api.bioloop.app"
        static let timeoutInterval: TimeInterval = 30
        static let maxRetryAttempts = 3
    }
    
    // MARK: - Analytics Events (for future use)
    struct AnalyticsEvents {
        static let appLaunched = "app_launched"
        static let healthKitAuthorized = "healthkit_authorized"
        static let scoreViewed = "score_viewed"
        static let journalEntryCreated = "journal_entry_created"
        static let breathingSessionCompleted = "breathing_session_completed"
        static let onboardingCompleted = "onboarding_completed"
    }
    
    // MARK: - Feature Flags (for future use)
    struct FeatureFlags {
        static let enableAIInsights = true
        static let enableWeeklyReports = true
        static let enablePushNotifications = true
        static let enableHapticFeedback = true
        static let enableAdvancedMetrics = false
        static let enableSocialFeatures = false
    }
}

// MARK: - App Colors
extension Color {
    static let appPrimary = Color.blue
    static let appSecondary = Color.orange
}
