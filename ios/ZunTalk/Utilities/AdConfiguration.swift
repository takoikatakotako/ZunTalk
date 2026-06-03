import Foundation
import GoogleMobileAds

enum AdConfiguration {
    private static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    static var bannerAdUnitID: String? {
        if shouldUseTestAds {
            return testBannerAdUnitID
        }

        guard let value = Bundle.main.object(forInfoDictionaryKey: "ADMOB_BANNER_AD_UNIT_ID") as? String else {
            return testBannerAdUnitID
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? testBannerAdUnitID : trimmed
    }

    private static var shouldUseTestAds: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}

@MainActor
final class AdManager {
    static let shared = AdManager()

    private var isStarted = false

    private init() {}

    func startIfNeeded() {
        guard !ProcessInfo.processInfo.arguments.contains("UI-TESTING") else {
            return
        }

        guard !isStarted else {
            return
        }

        isStarted = true
        MobileAds.shared.start()
    }
}
