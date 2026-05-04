import SwiftUI
import UIKit
import GoogleMobileAds

enum AdMobConfiguration {
    static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let productionBannerAdUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"

    static var bannerAdUnitID: String {
        #if DEBUG
        testBannerAdUnitID
        #else
        productionBannerAdUnitID
        #endif
    }
}

struct AdMobBannerView: View {
    let width: CGFloat

    var body: some View {
        let adSize = largeAnchoredAdaptiveBanner(width: max(320, width))

        BannerViewContainer(adSize: adSize, adUnitID: AdMobConfiguration.bannerAdUnitID)
            .frame(width: adSize.size.width, height: adSize.size.height)
            .accessibilityHidden(true)
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    let adSize: AdSize
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        banner.adUnitID = adUnitID
    }

    func makeCoordinator() -> BannerCoordinator {
        BannerCoordinator()
    }
}

private final class BannerCoordinator: NSObject, BannerViewDelegate {
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("AdMob banner failed to load: \(error.localizedDescription)")
        #endif
    }
}
