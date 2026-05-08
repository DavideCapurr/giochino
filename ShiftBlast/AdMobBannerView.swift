import SwiftUI
import UIKit
import GoogleMobileAds
import UserMessagingPlatform

enum AdMobConfiguration {
    static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let productionBannerAdUnitID = "ca-app-pub-2326857958249865/2629125814"

    static var usesTestAds: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static var bannerAdUnitID: String {
        usesTestAds ? testBannerAdUnitID : productionBannerAdUnitID
    }
}

@MainActor
final class AdMobConsentState: ObservableObject {
    static let shared = AdMobConsentState()

    @Published private(set) var privacyOptionsRequirementStatus: PrivacyOptionsRequirementStatus = ConsentInformation.shared.privacyOptionsRequirementStatus
    @Published private(set) var lastError: String?

    var isPrivacyOptionsRequired: Bool {
        privacyOptionsRequirementStatus == .required
    }

    func refresh() {
        privacyOptionsRequirementStatus = ConsentInformation.shared.privacyOptionsRequirementStatus
    }

    func presentPrivacyOptions() async {
        guard isPrivacyOptionsRequired else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: UIApplication.shared.adMobTopViewController())
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}

struct AdMobBannerView: View {
    let width: CGFloat

    private var adSize: AdSize {
        largePortraitAnchoredAdaptiveBanner(width: max(320, width))
    }

    var body: some View {
        BannerViewContainer(adSize: adSize, adUnitID: AdMobConfiguration.bannerAdUnitID)
            .frame(maxWidth: .infinity)
            .frame(height: adSize.size.height)
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
        Task { @MainActor in
            banner.rootViewController = UIApplication.shared.adMobTopViewController()
            guard await AdMobStartup.prepareForAdRequests(from: banner.rootViewController) else { return }
            banner.load(Request())
        }
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.adMobTopViewController()
    }

    func makeCoordinator() -> BannerCoordinator {
        BannerCoordinator()
    }
}

private final class BannerCoordinator: NSObject, BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        #if DEBUG
        print("AdMob banner loaded.")
        #endif
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("AdMob banner failed to load: \(error.localizedDescription)")
        #endif
    }
}

@MainActor
private enum AdMobStartup {
    private static var didConfigureMobileAds = false
    private static var didStartMobileAds = false

    static func prepareForAdRequests(from viewController: UIViewController?) async -> Bool {
        configureMobileAdsIfNeeded()

        if !AdMobConfiguration.usesTestAds {
            await gatherConsent(from: viewController)
            guard ConsentInformation.shared.canRequestAds else {
                #if DEBUG
                print("AdMob cannot request ads yet: consent is not available.")
                #endif
                return false
            }

            await TrackingAuthorization.requestIfNeeded()
        }

        if !didStartMobileAds {
            await MobileAds.shared.start()
            didStartMobileAds = true
        }

        return true
    }

    private static func configureMobileAdsIfNeeded() {
        guard !didConfigureMobileAds else { return }
        MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
        didConfigureMobileAds = true
    }

    private static func gatherConsent(from viewController: UIViewController?) async {
        let parameters = RequestParameters()

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: viewController)
            AdMobConsentState.shared.refresh()
        } catch {
            AdMobConsentState.shared.refresh()
            #if DEBUG
            print("AdMob consent flow error: \(error.localizedDescription)")
            #endif
        }
    }
}

private extension UIApplication {
    func adMobTopViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return adMobTopViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = base as? UITabBarController {
            return adMobTopViewController(base: tabBarController.selectedViewController)
        }

        if let presentedViewController = base?.presentedViewController {
            return adMobTopViewController(base: presentedViewController)
        }

        return base
    }
}
