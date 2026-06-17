import GoogleMobileAds

/// AdMob の設定取得と SDK 初期化を一元管理する。
@MainActor
final class AdManager {
    static let shared = AdManager()

    /// Google 公式のテスト用バナー広告ユニットID
    nonisolated private static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    /// 表示するバナー広告ユニットID。
    /// Debug / TestFlight ではテスト広告、App Store 本番では Info.plist の値を使う。
    nonisolated static var bannerAdUnitID: String {
        if shouldUseTestAds {
            return testBannerAdUnitID
        }

        guard let value = Bundle.main.object(forInfoDictionaryKey: "AdMobBannerAdUnitID") as? String else {
            return testBannerAdUnitID
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? testBannerAdUnitID : trimmed
    }

    /// Debug ビルドまたは TestFlight 配信時は true。App Store 本番のみ false。
    nonisolated private static var shouldUseTestAds: Bool {
        #if DEBUG
        return true
        #else
        // App Store 配信ビルドには embedded.mobileprovision が含まれない。
        // TestFlight / 開発ビルドには含まれるため、その場合はテスト広告を使う。
        return Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") != nil
        #endif
    }

    private var isStarted = false

    private init() {}

    /// SDK を一度だけ初期化する。UIテスト時はネットワーク読み込みを避けるためスキップする。
    func startIfNeeded() {
        guard !ProcessInfo.processInfo.arguments.contains("UI-TESTING") else { return }
        guard !isStarted else { return }
        isStarted = true
        MobileAds.shared.start()
    }
}
