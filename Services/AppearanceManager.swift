import SwiftUI
import Combine

class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @Published var colorScheme: ColorScheme? = nil
    
    private let userDefaults = UserDefaults.standard
    private let appearanceKey = "app_appearance"
    
    init() {
        loadAppearance()
    }
    
    func setAppearance(_ appearance: AppearanceMode) {
        switch appearance {
        case .system:
            colorScheme = nil
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        }
        
        userDefaults.set(appearance.rawValue, forKey: appearanceKey)
    }
    
    private func loadAppearance() {
        let savedAppearance = userDefaults.string(forKey: appearanceKey) ?? AppearanceMode.system.rawValue
        let appearance = AppearanceMode(rawValue: savedAppearance) ?? .system
        setAppearance(appearance)
    }
    
    var currentMode: AppearanceMode {
        let savedAppearance = userDefaults.string(forKey: appearanceKey) ?? AppearanceMode.system.rawValue
        return AppearanceMode(rawValue: savedAppearance) ?? .system
    }
}

enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
} 