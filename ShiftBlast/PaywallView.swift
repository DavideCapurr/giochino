import StoreKit
import SwiftUI

struct PaywallView: View {
    @ObservedObject var subscriptionStore: SubscriptionStore
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Color.shiftYellow)
                        .shadow(color: Color.shiftYellow.opacity(0.55), radius: 18)

                    Text("SHIFT BLAST PREMIUM")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Unlock agent assistant and remove ads.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Label("Agent completion overlay", systemImage: "checkmark.seal.fill")
                    Label("No AdMob banner while subscribed", systemImage: "rectangle.slash.fill")
                    Label("Game stays free for everyone", systemImage: "gamecontroller.fill")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)

                if case .failed(let message) = subscriptionStore.state {
                    Text(message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.shiftPink)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button {
                        Task { await subscriptionStore.purchasePremium() }
                    } label: {
                        HStack(spacing: 8) {
                            if subscriptionStore.state == .purchasing {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "crown.fill")
                            }
                            Text(primaryButtonTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.black)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(isPrimaryActionDisabled)

                    HStack(spacing: 16) {
                        Button("Restore") {
                            Task { await subscriptionStore.restorePurchases() }
                        }
                        .disabled(subscriptionStore.state == .restoring)

                        Button("Not now", action: dismiss)
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 0.035, green: 0.038, blue: 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
            .padding(24)
            .onChange(of: subscriptionStore.isPremium) { _, isPremium in
                if isPremium {
                    dismiss()
                }
            }
        }
    }

    private var primaryButtonTitle: String {
        switch subscriptionStore.state {
        case .loading:
            return "Loading..."
        case .purchasing:
            return "Subscribing..."
        default:
            return "Subscribe \(subscriptionStore.premiumDisplayPrice)"
        }
    }

    private var isPrimaryActionDisabled: Bool {
        subscriptionStore.state == .loading || subscriptionStore.state == .purchasing || subscriptionStore.premiumProduct == nil
    }
}
