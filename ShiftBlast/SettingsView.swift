import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var subscriptionStore: SubscriptionStore
    let dismiss: () -> Void
    let openPaywall: () -> Void

    @EnvironmentObject var gameCenter: GameCenterService
    @Environment(\.openURL) private var openURL
    @StateObject private var adMobConsent = AdMobConsentState.shared
    @State private var showRestartConfirm = false
    @State private var isLeaderboardPresented = false

    var body: some View {
<<<<<<< ours
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.84)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                panel
                    .frame(maxWidth: 400)
                    .frame(maxHeight: proxy.size.height - 44)
=======
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Spacer()
                panelContent
                    .padding(18)
                    .frame(maxWidth: 380)
                    .glassPanel(cornerRadius: 22, tint: .shiftCyan)
                    .padding(.horizontal, 16)
                Spacer()
>>>>>>> theirs
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .transition(.opacity)
        .task {
            await gameCenter.refreshNotificationSettings()
        }
        .fullScreenCover(isPresented: $isLeaderboardPresented) {
            LeaderboardView(
                viewModel: viewModel,
                gameCenter: gameCenter,
                dismiss: { isLeaderboardPresented = false }
            )
        }
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    statsStrip
                    premiumSection
                    gameCenterGroup
                    agentGroup
                    systemGroup
                    aboutGroup
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 18)
            }
        }
        .background(
            Color(red: 0.05, green: 0.053, blue: 0.066),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
        .padding(.horizontal, 16)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.shiftCyan)
                .frame(width: 34, height: 34)
                .background(Color.shiftCyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("SETTINGS")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1)
                Text("ShiftBlast")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.nightPurple)
            }

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.07), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close settings")
        }
        .padding(16)
    }

    // MARK: - Stats

    private var statsStrip: some View {
        HStack(spacing: 8) {
            StatTile(label: "SCORE", value: viewModel.state.score.formatted(), tint: .white)
            StatTile(label: "BEST", value: viewModel.state.bestScore.formatted(), tint: .shiftYellow)
            StatTile(label: "MOVES", value: viewModel.state.moves.formatted(), tint: .nightPurple)
        }
    }

    // MARK: - Premium

    @ViewBuilder
    private var premiumSection: some View {
        if subscriptionStore.isPremium {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.shiftYellow)
                    .frame(width: 34, height: 34)
                    .background(Color.shiftYellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("PREMIUM")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Active · AI alerts unlocked")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 4)

                Button {
                    openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                } label: {
                    ghostChip("MANAGE")
                }
            }
            .padding(14)
            .background(Color.shiftYellow.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.shiftYellow.opacity(0.22), lineWidth: 1)
            )
        } else {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    openPaywall()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("UNLOCK PREMIUM")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                        Text(subscriptionStore.hasRemoveAds ? "Unlock AI agent alerts" : "Remove ads · AI agent alerts")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.6))
                    }

                    Spacer(minLength: 4)

                    Text("UPGRADE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.18), in: Capsule())
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [Color.shiftYellow, Color(red: 1.0, green: 0.62, blue: 0.04)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .shadow(color: Color.shiftYellow.opacity(0.28), radius: 14, y: 5)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Game Center

    private var gameCenterGroup: some View {
        SettingsGroup(label: "GAME CENTER") {
            SettingsRow(
                icon: "trophy.fill",
                iconTint: .shiftYellow,
                title: "Leaderboard",
                subtitle: leaderboardSubtitle
            ) {
                Button {
                    isLeaderboardPresented = true
                } label: {
                    solidChip("OPEN", tint: .shiftYellow)
                }
            }

            rowHairline

            SettingsRow(
                icon: gameCenter.friendAlertsEnabled ? "bell.badge.fill" : "bell.slash.fill",
                iconTint: gameCenter.friendAlertsEnabled ? .shiftYellow : .white.opacity(0.28),
                title: "Friend Alerts",
                subtitle: friendAlertsSubtitle
            ) {
                if gameCenter.friendAlertsAuthorizationStatus == .denied {
                    Button {
                        gameCenter.openSystemSettings()
                    } label: {
                        ghostChip("SETTINGS")
                    }
                } else {
                    Toggle("", isOn: Binding(
                        get: { gameCenter.friendAlertsEnabled },
                        set: { enabled in
                            Task { await gameCenter.setFriendAlertsEnabled(enabled) }
                        }
                    ))
                    .tint(Color.shiftCyan)
                    .labelsHidden()
                }
            }
        }
    }

    private var leaderboardSubtitle: String {
        switch gameCenter.authState {
        case .authenticated:
            if let rank = gameCenter.personalRank {
                return "Your rank: #\(rank) global"
            }
            return "Personal & global · Game Center"
        case .authenticating, .idle:
            return "Signing in to Game Center…"
        case .unavailable:
            return "Personal · Game Center offline"
        }
    }

    private var friendAlertsSubtitle: String {
        if gameCenter.friendAlertsAuthorizationStatus == .denied {
            return "Blocked in iOS Settings"
        }
        return gameCenter.friendAlertsEnabled ? "On · friend leaderboard changes" : "Off · opt in to enable"
    }

    // MARK: - Agent

    private var agentGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI AGENT")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(1.5)
                .padding(.leading, 4)

<<<<<<< ours
            VStack(spacing: 0) {
=======
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
                            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.6))
                    }
                }
            } else {
>>>>>>> theirs
                SettingsRow(
                    icon: "cpu",
                    iconTint: aiConnectionTint,
                    title: "Agent Connection",
                    subtitle: aiStatusText
                ) {
                    Circle()
                        .fill(aiConnectionTint)
                        .frame(width: 8, height: 8)
                        .shadow(color: aiConnectionTint.opacity(0.6), radius: 6)
                }
            }
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            if !subscriptionStore.isPremium {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Premium required for AI connection")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.3))
                .padding(.leading, 4)
            }
        }
    }

    private var aiConnectionTint: Color {
        guard subscriptionStore.isPremium else { return Color.white.opacity(0.2) }
        return AgentSignalWatcher.isAvailable ? .shiftLime : .shiftPink
    }

    private var aiStatusText: String {
        guard subscriptionStore.isPremium else { return "Locked" }
        let base = AgentSignalWatcher.isAvailable ? "iCloud bridge connected" : "iCloud not available"
        guard let last = viewModel.lastAgentSignalAt else { return base }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "\(base) · last signal \(formatter.string(from: last))"
    }

    // MARK: - System (sound + restart)

    private var systemGroup: some View {
        SettingsGroup(label: "GAME") {
            SettingsRow(
                icon: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                iconTint: viewModel.isMuted ? .shiftPink : .nightPurple,
                title: "Sound",
                subtitle: viewModel.isMuted ? "Off" : "On"
            ) {
                Toggle("", isOn: Binding(
                    get: { !viewModel.isMuted },
                    set: { _ in viewModel.toggleMute() }
                ))
                .tint(Color.shiftCyan)
                .labelsHidden()
            }

            rowHairline

            SettingsRow(
                icon: "arrow.clockwise",
                iconTint: .shiftCyan,
                title: "Restart Game",
                subtitle: "Start a fresh run"
            ) {
                Button {
                    showRestartConfirm = true
                } label: {
                    Text("RESTART")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.shiftPink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
<<<<<<< ours
                        .background(Color.shiftPink.opacity(0.14), in: Capsule())
=======
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.shiftPink.opacity(0.45), lineWidth: 0.7))
>>>>>>> theirs
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
        }
    }

    // MARK: - About / legal

    private var aboutGroup: some View {
        SettingsGroup(label: "ABOUT") {
            SettingsRow(
                icon: "lock.shield.fill",
                iconTint: .shiftCyan,
                title: "Privacy Policy",
                subtitle: "How your data is handled"
            ) {
                Button {
                    openURL(LegalLinks.privacyURL)
                } label: {
                    ghostChip("OPEN")
                }
            }

            rowHairline

            SettingsRow(
                icon: "doc.text.fill",
                iconTint: .nightPurple,
                title: "Terms of Use",
                subtitle: "Subscription terms & EULA"
            ) {
                Button {
                    openURL(LegalLinks.termsURL)
                } label: {
                    ghostChip("OPEN")
                }
            }

            if adMobConsent.isPrivacyOptionsRequired {
                rowHairline

                SettingsRow(
                    icon: "hand.raised.fill",
                    iconTint: .shiftYellow,
                    title: "Privacy Choices",
                    subtitle: "Manage ad consent"
                ) {
                    Button {
                        Task { await adMobConsent.presentPrivacyOptions() }
                    } label: {
                        ghostChip("MANAGE")
                    }
                }
            }
        }
    }

    // MARK: - Shared building blocks

    private var rowHairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 56)
    }

    private func ghostChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.6))
    }

    private func solidChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
    }
}

// MARK: - StatTile

private struct StatTile: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - SettingsGroup

private struct SettingsGroup<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(1.5)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
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
                .frame(width: 30, height: 30)
                .background(iconTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
