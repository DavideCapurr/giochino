import StoreKit
import SwiftUI

struct PaywallView: View {
    @ObservedObject var subscriptionStore: SubscriptionStore
    let dismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                featureList
                errorBanner
                subscriptionCard
                actionButtons
                lifetimeOption
                removeAdsOption
                legalDisclosure
                legalLinks
            }
            .padding(24)
        }
        .background(Color(red: 0.035, green: 0.038, blue: 0.05).ignoresSafeArea())
        .onAppear { subscriptionStore.clearError() }
        .onChange(of: subscriptionStore.removesAds) { _, removesAds in
            if removesAds { dismiss() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(Color.shiftYellow)
                .shadow(color: Color.shiftYellow.opacity(0.55), radius: 18)

            Text("SHIFT BLAST PREMIUM")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "cpu", tint: .shiftLime, text: "AI agent alert — get pinged when Claude Code finishes")
            FeatureRow(icon: "bolt.fill", tint: .shiftYellow, text: "Stay in flow while your agent works")
            FeatureRow(icon: "rectangle.slash.fill", tint: .shiftCyan, text: "Remove all ads")
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Error

    @ViewBuilder
    private var errorBanner: some View {
        if case .failed(let message) = subscriptionStore.state {
            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.shiftPink)
                .multilineTextAlignment(.center)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.shiftPink.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        VStack(spacing: 6) {
            if let product = subscriptionStore.premiumProduct {
                Text(product.displayPrice)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("per month")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                Text(subscriptionStore.isEligibleForIntroOffer
                     ? "3-day free trial for new subscribers, then auto-renews monthly. Cancel anytime."
                     : "Auto-renews monthly. Cancel anytime.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            } else if subscriptionStore.didFinishLoadingProducts {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Could not load subscription")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Button("Retry") {
                    Task { await subscriptionStore.configure() }
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.shiftCyan)
                .padding(.top, 4)
            } else {
                ProgressView()
                    .tint(.white)
                Text("Loading subscription...")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Color.shiftYellow.opacity(0.08), Color.shiftCyan.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.shiftYellow.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await subscriptionStore.purchasePremium() }
            } label: {
                HStack(spacing: 8) {
                    if subscriptionStore.state == .purchasing {
                        ProgressView().tint(.black)
                    }
                    Text(primaryButtonTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.black)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(isPrimaryActionDisabled)

            Button {
                Task { await subscriptionStore.restorePurchases() }
            } label: {
                HStack(spacing: 6) {
                    if subscriptionStore.state == .restoring {
                        ProgressView().tint(.white)
                    }
                    Text(subscriptionStore.state == .restoring ? "Restoring..." : "Restore Purchases")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(.white.opacity(0.78))
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(subscriptionStore.state == .restoring)

            Button("Not now", action: dismiss)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 4)
        }
    }

    // MARK: - Lifetime Premium (one-time)

    @ViewBuilder
    private var lifetimeOption: some View {
        if let lifetimeProduct = subscriptionStore.premiumLifetimeProduct {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    Text("OR PAY ONCE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                }

                Button {
                    Task { await subscriptionStore.purchasePremiumLifetime() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "infinity")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Color.shiftYellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lifetime Premium")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Everything, forever · no subscription")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer(minLength: 8)
                        Text(lifetimeProduct.displayPrice)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.shiftYellow.opacity(0.16), Color.shiftLime.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.shiftYellow.opacity(0.4), lineWidth: 1)
                    )
                }
                .disabled(subscriptionStore.state == .purchasing)
            }
        }
    }

    // MARK: - Remove Ads (one-time)

    @ViewBuilder
    private var removeAdsOption: some View {
        if let removeAdsProduct = subscriptionStore.removeAdsProduct {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                    Text("OR")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                }

                Button {
                    Task { await subscriptionStore.purchaseRemoveAds() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.slash.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.shiftCyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remove Ads")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("One-time · no subscription")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer(minLength: 8)
                        Text(removeAdsProduct.displayPrice)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.shiftCyan.opacity(0.25), lineWidth: 1)
                    )
                }
                .disabled(subscriptionStore.state == .purchasing)
            }
        }
    }

    // MARK: - Legal Disclosure

    private var legalDisclosure: some View {
        Text("Eligible new subscribers receive a 3-day free trial. Payment will be charged to your Apple ID account at confirmation of purchase or when the trial ends. The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase.")
            .font(.system(size: 10, weight: .regular))
            .foregroundStyle(.white.opacity(0.3))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Legal Links

    private var legalLinks: some View {
        HStack(spacing: 4) {
            Link("Terms of Use", destination: PaywallConstants.termsURL)
            Text("·").foregroundStyle(.white.opacity(0.25))
            Link("Privacy Policy", destination: PaywallConstants.privacyURL)
            Text("·").foregroundStyle(.white.opacity(0.25))
            Button("Manage Subscription") {
                openURL(PaywallConstants.manageSubscriptionURL)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.4))
    }

    // MARK: - Helpers

    private var primaryButtonTitle: String {
        switch subscriptionStore.state {
        case .loading:
            return "Loading..."
        case .purchasing:
            return "Subscribing..."
        default:
            if subscriptionStore.premiumProduct != nil {
                return subscriptionStore.isEligibleForIntroOffer ? "Start Free Trial" : "Subscribe"
            }
            return "Subscribe"
        }
    }

    private var isPrimaryActionDisabled: Bool {
        subscriptionStore.state == .loading
            || subscriptionStore.state == .purchasing
            || subscriptionStore.premiumProduct == nil
    }
}

// MARK: - FeatureRow

private struct FeatureRow: View {
    let icon: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Constants

enum PaywallConstants {
    static let termsURL = LegalLinks.termsURL
    static let privacyURL = LegalLinks.privacyURL
    static let manageSubscriptionURL = LegalLinks.manageSubscriptionURL
}
