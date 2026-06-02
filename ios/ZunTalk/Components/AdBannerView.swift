import GoogleMobileAds
import SwiftUI

struct AdBannerView: View {
    private let adUnitID: String?

    init(adUnitID: String? = AdConfiguration.bannerAdUnitID) {
        self.adUnitID = adUnitID
    }

    var body: some View {
        if let adUnitID {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 320)
                let adSize = largeAnchoredAdaptiveBanner(width: width)

                BannerViewContainer(adSize: adSize, adUnitID: adUnitID)
                    .frame(width: adSize.size.width, height: adSize.size.height)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 100)
            .accessibilityHidden(true)
        }
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    let adSize: AdSize
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard banner.adSize.size != adSize.size else {
            return
        }

        banner.adSize = adSize
        banner.load(Request())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("Banner ad failed to load: \(error.localizedDescription)")
            #endif
        }
    }
}
