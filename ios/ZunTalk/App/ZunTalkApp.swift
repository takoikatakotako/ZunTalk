import SwiftUI
import FirebaseCore

@main
struct ZunTalkApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .preferredColorScheme(.light)
        }
    }
}
