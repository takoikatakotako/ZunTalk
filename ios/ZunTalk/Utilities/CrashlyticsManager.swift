import FirebaseCrashlytics

enum CrashlyticsManager {
    static func record(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
