import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var gameCenter: GameCenterService
    let dismiss: () -> Void

    @State private var tab: Tab = .personal

    enum Tab: String, CaseIterable {
        case personal
        case global

        var label: String {
            switch self {
            case .personal: return "PERSONAL"
            case .global: return "GLOBAL"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 14)

                tabBar
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 12) {
                        switch tab {
                        case .personal:
                            PersonalContent(
                                gameCenter: gameCenter,
                                bestScore: viewModel.state.bestScore,
                                localEntries: viewModel.state.leaderboard
                            )
                        case .global:
                            GlobalContent(gameCenter: gameCenter)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                }
                .refreshable {
                    await gameCenter.refreshAll()
                }
            }
        }
        .task { await gameCenter.refreshAll() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: dismiss) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close leaderboard")

            VStack(alignment: .leading, spacing: 2) {
                Text("LEADERBOARD")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(2)
                Text("Shift Blast")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, tint): (String, Color) = {
            switch gameCenter.authState {
            case .authenticated: return ("LIVE", .shiftLime)
            case .authenticating, .idle: return ("SIGN IN…", .shiftYellow)
            case .unavailable: return ("OFFLINE", .shiftPink)
            }
        }()
        HStack(spacing: 5) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .shadow(color: tint.opacity(0.6), radius: 5)
            Text(text)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.3), lineWidth: 1))
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button {
                    tab = item
                } label: {
                    Text(item.label)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(item == tab ? .black : .white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            item == tab
                            ? AnyShapeStyle(LinearGradient(colors: [Color.shiftCyan, Color.shiftLime], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.05)),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(item == tab ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Personal

private struct PersonalContent: View {
    @ObservedObject var gameCenter: GameCenterService
    let bestScore: Int
    let localEntries: [LeaderboardEntry]

    var body: some View {
        VStack(spacing: 12) {
            HeroBestCard(gameCenter: gameCenter, bestScore: bestScore)

            if localEntries.isEmpty {
                EmptyCard(
                    icon: "tray",
                    title: "No runs yet",
                    subtitle: "Finish a game to see it here"
                )
            } else {
                SectionHeader(title: "RECENT RUNS", trailing: "TOP \(min(localEntries.count, 5))")

                VStack(spacing: 6) {
                    ForEach(Array(localEntries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                        LocalRow(rank: index + 1, entry: entry)
                    }
                }
            }
        }
    }
}

private struct HeroBestCard: View {
    @ObservedObject var gameCenter: GameCenterService
    let bestScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rosette")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.shiftYellow)
                Text("GAME CENTER BEST")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)
                Spacer()
                if let rank = gameCenter.personalRank {
                    Text("#\(rank) GLOBAL")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.shiftCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.shiftCyan.opacity(0.12), in: Capsule())
                        .monospacedDigit()
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(displayedBest)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("LOCAL BEST")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.38))
                        .tracking(1)
                    Text("\(bestScore)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .monospacedDigit()
                }
            }

            if gameCenter.personalBest == nil {
                AuthFootnote(state: gameCenter.authState, fallbackBest: bestScore)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.shiftYellow.opacity(0.18), Color.shiftViolet.opacity(0.1)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.shiftYellow.opacity(0.28), lineWidth: 1)
        )
    }

    private var displayedBest: Int {
        gameCenter.personalBest ?? bestScore
    }
}

private struct AuthFootnote: View {
    let state: GameCenterAuthState
    let fallbackBest: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.5))
    }

    private var icon: String {
        switch state {
        case .authenticated: return "person.fill.questionmark"
        case .authenticating, .idle: return "arrow.triangle.2.circlepath"
        case .unavailable: return "exclamationmark.triangle.fill"
        }
    }

    private var text: String {
        switch state {
        case .authenticated:
            return fallbackBest > 0 ? "No Game Center entry yet — submit a run" : "Play a run to publish your first score"
        case .authenticating, .idle:
            return "Signing in to Game Center…"
        case .unavailable(let reason):
            return reason
        }
    }
}

private struct LocalRow: View {
    let rank: Int
    let entry: LeaderboardEntry

    private var tint: Color {
        switch rank {
        case 1: return .shiftYellow
        case 2: return .shiftCyan
        case 3: return .shiftPink
        default: return .white.opacity(0.55)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(entry.score)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .monospacedDigit()
                Text(entry.playedAt, style: .date)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(entry.moves) MOVES")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .monospacedDigit()
                Text("\(entry.blocksLeft) LEFT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.32))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Global

private struct GlobalContent: View {
    @ObservedObject var gameCenter: GameCenterService

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "TOP 10 ALL-TIME", trailing: gameCenter.isLoadingGlobal ? "LOADING…" : "")

            if gameCenter.globalTop.isEmpty {
                EmptyCard(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(gameCenter.globalTop) { entry in
                        GlobalRow(entry: entry)
                    }
                }

                if let rank = gameCenter.personalRank,
                   !gameCenter.globalTop.contains(where: \.isLocalPlayer) {
                    YouRow(rank: rank, score: gameCenter.personalBest ?? 0)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var emptyIcon: String {
        switch gameCenter.authState {
        case .authenticated: return "trophy"
        case .authenticating, .idle: return "arrow.triangle.2.circlepath"
        case .unavailable: return "wifi.slash"
        }
    }

    private var emptyTitle: String {
        switch gameCenter.authState {
        case .authenticated: return "No scores yet"
        case .authenticating, .idle: return "Signing in…"
        case .unavailable: return "Game Center unavailable"
        }
    }

    private var emptySubtitle: String {
        switch gameCenter.authState {
        case .authenticated: return "Be the first to publish a run"
        case .authenticating, .idle: return "Checking Game Center authentication"
        case .unavailable(let reason): return reason
        }
    }
}

private struct GlobalRow: View {
    let entry: GlobalLeaderboardEntry

    private var rankTint: Color {
        if entry.isLocalPlayer { return .shiftCyan }
        switch entry.rank {
        case 1: return .shiftYellow
        case 2: return .shiftPink
        case 3: return .shiftViolet
        default: return .white.opacity(0.55)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(rankTint)
                .frame(width: 36, alignment: .leading)
                .monospacedDigit()

            Text(entry.displayName)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(entry.isLocalPlayer ? 1 : 0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if entry.isLocalPlayer {
                Text("YOU")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.shiftCyan, in: Capsule())
            }

            Spacer()

            Text("\(entry.score)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(entry.isLocalPlayer ? 1 : 0.9))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            entry.isLocalPlayer ? Color.shiftCyan.opacity(0.14) : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(entry.isLocalPlayer ? Color.shiftCyan.opacity(0.45) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct YouRow: View {
    let rank: Int
    let score: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.shiftCyan)
                .frame(width: 36, alignment: .leading)
                .monospacedDigit()

            Text("YOU")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.shiftCyan)

            Spacer()

            Text("\(score)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.shiftCyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.shiftCyan.opacity(0.45), lineWidth: 1)
        )
    }
}

// MARK: - Shared bits

private struct SectionHeader: View {
    let title: String
    let trailing: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.5)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.32))
                    .tracking(1)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct EmptyCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text(subtitle)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
