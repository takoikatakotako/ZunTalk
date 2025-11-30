import SwiftUI

@main
struct ZunTalkApp: App {
    var body: some Scene {
        WindowGroup {
            ContactView()
                .preferredColorScheme(.light)
        }
    }
}
