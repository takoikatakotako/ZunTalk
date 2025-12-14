import Foundation

protocol UserDefaultsRepositoryProtocol {
    var hasCompletedOnboarding: Bool { get set }
    func resetAll()
}

struct UserDefaultsRepository: UserDefaultsRepositoryProtocol {
    private enum Key: String {
        case hasCompletedOnboarding
    }

    var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.hasCompletedOnboarding.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue)
        }
    }

    func resetAll() {
        UserDefaults.standard.removeObject(forKey: Key.hasCompletedOnboarding.rawValue)
    }
}
