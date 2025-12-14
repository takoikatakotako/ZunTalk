import Foundation

enum UserDefaultsManager {
    private enum Key: String {
        case hasCompletedOnboarding
    }

    static var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.hasCompletedOnboarding.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue)
        }
    }
}
