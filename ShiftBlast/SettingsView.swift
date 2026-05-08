import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var subscriptionStore: SubscriptionStore
    let dismiss: () -> Void
    let openPaywall: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var showRestartConfirm = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Spacer()
                panelContent
                    .padding(18)
                    .frame(maxWidth: 380)
                    .background(
                        Color(red: 0.045, green: 0.048, blue: 0.06),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                Spacer()
            }
        }
        .transition(.opacity)
    }

    private var panelContent: some View {
        VStack(spacing: 16) {
            header
            soundSection
            Divider().background(Color.white.opacity(0.08))
            premiumSection
            Divider().background(Color.white.opacity(0.08))
            aiSection
            Divider().background(Color.white.opacity(0.08))
            gameSection
            closeButton
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("SETTINGS")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .tracking(2)
            Spacer()
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        SettingsRow(
            icon: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            iconTint: viewModel.isMuted ? .shiftPink : .nightPurple,
            title: "SOUND",
            subtitle: viewModel.isMuted ? "Off" : "On"
        ) {
            Toggle("", isOn: Binding(
                get: { !viewModel.isMuted },
                set: { _ in viewModel.toggleMute() }
            ))
            .tint(Color.shiftCyan)
            .labelsHidden()
        }
    }

    // MARK: - Premium

    private var premiumSection: some View {
        VStack(spacing: 10) {
            if subscriptionStore.isPremium {
                SettingsRow(
                    icon: "crown.fill",
                    iconTint: .shiftYellow,
                    title: "PREMIUM",
                    subtitle: "Active"
                ) {
                    Button {
                        openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                    } label: {
                        Text("MANAGE")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                }
            } else {
                SettingsRow(
                    icon: "crown.fill",
                    iconTint: Color.shiftYellow.opacity(0.5),
                    title: "PREMIUM",
                    subtitle: "Remove ads · Unlock AI"
                ) {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            openPaywall()
                        }
                    } label: {
                        Text("UPGRADE")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.shiftYellow, in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - AI Connection

    private var aiSection: some View {
        VStack(spacing: 10) {
            SettingsRow(
                icon: "cpu",
                iconTint: aiConnectionTint,
                title: "AI AGENT",
                subtitle: aiStatusText
            ) {
                Circle()
                    .fill(aiConnectionTint)
                    .frame(width: 8, height: 8)
                    .shadow(color: aiConnectionTint.opacity(0.6), radius: 6)
            }

            if !subscriptionStore.isPremium {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Premium required for AI connection")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var aiConnectionTint: Color {
        guard subscriptionStore.isPremium else { return Color.white.opacity(0.2) }
        return AgentSignalWatcher.isAvailable ? .shiftLime : .shiftPink
    }

    private var aiStatusText: String {
        guard subscriptionStore.isPremium else { return "Locked" }
        if AgentSignalWatcher.isAvailable {
            return "iCloud bridge connected"
        }
        return "iCloud not available"
    }

    // MARK: - Game

    private var gameSection: some View {
        VStack(spacing: 10) {
            SettingsRow(
                icon: "arrow.clockwise",
                iconTint: .shiftCyan,
                title: "RESTART GAME",
                subtitle: "Score: \(viewModel.state.score)"
            ) {
                Button {
                    showRestartConfirm = true
                } label: {
                    Text("RESTART")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.shiftPink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.shiftPink.opacity(0.12), in: Capsule())
                }
                .alert("Restart game?", isPresented: $showRestartConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Restart", role: .destructive) {
                        viewModel.restart()
                        dismiss()
                    }
                } message: {
                    Text("Your current progress will be lost.")
                }
            }

            SettingsRow(
                icon: "number",
                iconTint: .nightPurpleMid,
                title: "MOVES",
                subtitle: "\(viewModel.state.moves)"
            ) {
                EmptyView()
            }

            SettingsRow(
                icon: "trophy.fill",
                iconTint: .shiftYellow,
                title: "BEST SCORE",
                subtitle: "\(viewModel.state.bestScore)"
            ) {
                EmptyView()
            }
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button(action: dismiss) {
            Text("CLOSE")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.top, 4)
    }
}

// MARK: - SettingsRow

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconTint)
                .frame(width: 28, height: 28)
                .background(iconTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(0.5)
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            trailing()
        }
    }
}
