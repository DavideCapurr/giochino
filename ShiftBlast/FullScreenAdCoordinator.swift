import Foundation
import UIKit
import GoogleMobileAds
import OSLog

private let log = Logger(subsystem: "com.davide.shiftblast", category: "FullScreenAds")

/// Coordinates the high-eCPM full-screen ad formats — rewarded ("continue" / revive)
/// and interstitial (shown between games for free players). These earn far more than the
/// banner, so they're the main revenue drivers for the game.
///
/// Ad unit IDs live in `AdUnits`. In DEBUG the official Google test units are always used.
/// In release builds the production units must be filled in (see `AdUnits.production*`);
/// until then the corresponding format is simply skipped (policy-safe — never ships test
/// ads to the App Store), while the banner continues to run.
@MainActor
final class FullScreenAdCoordinator: NSObject, ObservableObject {
    static let shared = FullScreenAdCoordinator()

    enum AdUnits {
        // Google's official test units — safe to use during development.
        static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"
        static let testRewarded = "ca-app-pub-3940256099942544/1712485313"

        // TODO: Create an Interstitial and a Rewarded ad unit in the AdMob console
        // (publisher account ca-app-pub-2326857958249865, the same one that owns the
        // banner unit) and paste their IDs here. Leaving them empty disables the format
        // in release builds instead of serving test ads.
        static let productionInterstitial = ""
        static let productionRewarded = ""
    }

    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var isLoadingInterstitial = false
    private var isLoadingRewarded = false

    private var rewardContinuation: CheckedContinuation<Bool, Never>?
    private var didEarnReward = false

    /// Games finished since the last interstitial — used to pace interstitials so they
    /// don't appear on every single game over.
    private var gamesSinceInterstitial = 0

    private var interstitialUnitID: String? {
        #if DEBUG
        return AdUnits.testInterstitial
        #else
        return AdUnits.productionInterstitial.isEmpty ? nil : AdUnits.productionInterstitial
        #endif
    }

    private var rewardedUnitID: String? {
        #if DEBUG
        return AdUnits.testRewarded
        #else
        return AdUnits.productionRewarded.isEmpty ? nil : AdUnits.productionRewarded
        #endif
    }

    /// True when a rewarded "continue" ad can plausibly be offered for this build.
    var isRewardedConfigured: Bool { rewardedUnitID != nil }

    // MARK: - Rewarded "continue"

    /// Presents a rewarded ad and returns whether the user earned the reward (watched it
    /// through). Loads on demand if no ad is cached. Returns `false` if ads can't be shown.
    func showRewardedContinue() async -> Bool {
        guard rewardedUnitID != nil else { return false }
        guard let viewController = UIApplication.shared.adMobTopViewController() else { return false }
        guard await AdMobStartup.prepareForAdRequests(from: viewController) else { return false }

        if rewarded == nil {
            await loadRewarded()
        }
        guard let ad = rewarded else { return false }

        didEarnReward = false
        let earned = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            self.rewardContinuation = continuation
            ad.present(from: viewController) { [weak self] in
                self?.didEarnReward = true
            }
        }
        return earned
    }

    // MARK: - Interstitial

    /// Call when a run ends. Every `frequency` games a free player is shown an interstitial.
    /// No-op for players who have removed ads.
    func registerGameOverAndMaybeShowInterstitial(removesAds: Bool, frequency: Int = 3) async {
        guard !removesAds else { return }
        gamesSinceInterstitial += 1
        guard gamesSinceInterstitial >= frequency else {
            // Warm up the next interstitial so it's ready when its turn comes.
            await loadInterstitial()
            return
        }
        gamesSinceInterstitial = 0
        await showInterstitial()
    }

    private func showInterstitial() async {
        guard interstitialUnitID != nil else { return }
        guard let viewController = UIApplication.shared.adMobTopViewController() else { return }
        guard await AdMobStartup.prepareForAdRequests(from: viewController) else { return }

        if interstitial == nil {
            await loadInterstitial()
        }
        guard let ad = interstitial else { return }
        ad.present(from: viewController)
    }

    // MARK: - Loading

    /// Pre-loads both formats. Best-effort: silently no-ops if the SDK isn't ready yet.
    func warmUp() {
        Task {
            await loadRewarded()
            await loadInterstitial()
        }
    }

    private func loadInterstitial() async {
        guard !isLoadingInterstitial, interstitial == nil, let unitID = interstitialUnitID else { return }
        isLoadingInterstitial = true
        defer { isLoadingInterstitial = false }
        do {
            let ad = try await InterstitialAd.load(with: unitID, request: Request())
            ad.fullScreenContentDelegate = self
            interstitial = ad
        } catch {
            log.error("Interstitial failed to load: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadRewarded() async {
        guard !isLoadingRewarded, rewarded == nil, let unitID = rewardedUnitID else { return }
        isLoadingRewarded = true
        defer { isLoadingRewarded = false }
        do {
            let ad = try await RewardedAd.load(with: unitID, request: Request())
            ad.fullScreenContentDelegate = self
            rewarded = ad
        } catch {
            log.error("Rewarded failed to load: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func resumeReward(_ earned: Bool) {
        rewardContinuation?.resume(returning: earned)
        rewardContinuation = nil
    }
}

// MARK: - FullScreenContentDelegate

extension FullScreenAdCoordinator: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if ad === rewarded {
            rewarded = nil
            resumeReward(didEarnReward)
            Task { await loadRewarded() }
        } else if ad === interstitial {
            interstitial = nil
            Task { await loadInterstitial() }
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        log.error("Full-screen ad failed to present: \(error.localizedDescription, privacy: .public)")
        if ad === rewarded {
            rewarded = nil
            resumeReward(false)
            Task { await loadRewarded() }
        } else if ad === interstitial {
            interstitial = nil
            Task { await loadInterstitial() }
        }
    }
}
