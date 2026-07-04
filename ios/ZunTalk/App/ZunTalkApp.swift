import SwiftUI
import FirebaseCore
import FirebaseCrashlytics
import AppTrackingTransparency
import GoogleSignIn

@main
struct ZunTalkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var callKitManager = CallKitManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasRequestedATT = false

    init() {
        Self.configureFirebase()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    // Google サインインの OAuth コールバックを処理する
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onAppear {
                    // 前回の Google 連携を復元する
                    GoogleAuthManager.shared.restore()
                }
                // CallKit の着信に応答したら、画面状態に関係なく通話画面を全画面で出す
                .fullScreenCover(isPresented: $callKitManager.isPresentingCallScreen) {
                    CallView(mode: .callKit)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, !hasRequestedATT else { return }
            guard !ProcessInfo.processInfo.arguments.contains("UI-TESTING") else { return }
            hasRequestedATT = true
            Task {
                // ATTダイアログはscene activeになり切ってから呼ばないと無音で失敗するため少し待つ
                try? await Task.sleep(for: .milliseconds(500))
                await requestTrackingAuthorizationIfNeeded()
                AdManager.shared.startIfNeeded()
            }
        }
    }

    private func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    private static func configureFirebase() {
        let plistName = Bundle.main.object(forInfoDictionaryKey: "FirebasePlistName") as? String
        guard
            let plistName,
            let filePath = Bundle.main.path(forResource: plistName, ofType: "plist"),
            let options = FirebaseOptions(contentsOfFile: filePath)
        else {
            FirebaseApp.configure()
            return
        }

        FirebaseApp.configure(options: options)
    }
}
