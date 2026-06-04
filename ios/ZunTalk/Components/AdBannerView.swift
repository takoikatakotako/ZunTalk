import GoogleMobileAds
import SwiftUI

/// チャット画面に表示するアンカー型アダプティブバナー広告。
/// 広告の読み込みに成功したときだけ、実サイズ分の高さを確保する。
struct AdBannerView: View {
    private let adUnitID: String

    @State private var bannerHeight: CGFloat = 0

    init(adUnitID: String = AdManager.bannerAdUnitID) {
        self.adUnitID = adUnitID
    }

    var body: some View {
        GeometryReader { geometry in
            BannerViewContainer(
                adUnitID: adUnitID,
                width: geometry.size.width,
                onHeightChange: { bannerHeight = $0 }
            )
        }
        // 読み込み成功までは高さ0で余白を作らない
        .frame(height: bannerHeight)
        .accessibilityHidden(true)
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat
    let onHeightChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize(for: width))
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.backgroundColor = .clear
        banner.rootViewController = Self.rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        let newSize = adSize(for: width)
        // 幅が変わった（回転など）ときだけ再読み込みする
        guard banner.adSize.size.width != newSize.size.width else { return }
        banner.adSize = newSize
        banner.load(Request())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onHeightChange: onHeightChange)
    }

    private func adSize(for width: CGFloat) -> AdSize {
        currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let onHeightChange: (CGFloat) -> Void

        init(onHeightChange: @escaping (CGFloat) -> Void) {
            self.onHeightChange = onHeightChange
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onHeightChange(bannerView.adSize.size.height)
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onHeightChange(0)
            #if DEBUG
            print("Banner ad failed to load: \(error.localizedDescription)")
            #endif
        }
    }
}
