import SwiftUI
import FirebaseCore
import FirebaseCrashlytics
import GoogleMobileAds

@main
struct ZunTalkApp: App {
    init() {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .preferredColorScheme(.light)
        }
    }
}
