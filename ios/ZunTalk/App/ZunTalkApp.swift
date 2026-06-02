import SwiftUI
import FirebaseCore
import FirebaseCrashlytics

@main
struct ZunTalkApp: App {
    init() {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        AdManager.shared.startIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .preferredColorScheme(.light)
        }
    }
}
