import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: GameViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @State private var isPaywallPresented = false
    @State private var isSettingsPresented = false

    private var showAd: Bool { !subscriptionStore.isPremium }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        StatusBar(
                            score: viewModel.state.score,
                            bestScore: viewModel.state.bestScore,
                            moves: viewModel.state.moves,
                            isPremium: subscriptionStore.isPremium,
                            openSettings: { isSettingsPresented = true }
                        )
                            .padding(.top, 4)

                        BoardView(viewModel: viewModel)
                            .frame(width: min(proxy.size.width - 22, proxy.size.height * 0.56))
                            .aspectRatio(1, contentMode: .fit)
                            .layoutPriority(2)

                        VStack(spacing: 8) {
                            PulseGauge(pulse: viewModel.state.pulse)
                            SurgeGauge(surge: viewModel.state.surge, chain: viewModel.state.chain)
                        }
                        .padding(.top, 4)

                        EventStrip(
                            lastClear: viewModel.state.lastClear,
                            lastOverdrive: viewModel.state.lastOverdrive,
                            lastPulseEvent: viewModel.state.lastPulseEvent
                        )

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 11)

                    if showAd {
                        Divider()
                            .background(Color.white.opacity(0.08))

                        AdMobBannerView(width: proxy.size.width)
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.02, green: 0.02, blue: 0.03))
                    }
                }
                .padding(.bottom, showAd ? proxy.safeAreaInsets.bottom : 0)

                if viewModel.isSnoozed {
                    SnoozeCurtain(wake: viewModel.wakeFromSnooze)
                        .transition(.opacity)
                }

                if viewModel.isAgentPaused {
                    AgentPauseOverlay(
                        backToWork: viewModel.snoozeFromAgentPause,
                        procrastinate: viewModel.dismissAgentPause
                    )
                    .transition(.opacity.combined(with: .scale))
                }

                if viewModel.state.isGameOver {
                    GameOverView(
                        score: viewModel.state.score,
                        bestScore: viewModel.state.bestScore,
                        moves: viewModel.state.moves,
                        leaderboard: viewModel.state.leaderboard,
                        restart: viewModel.restart
                    )
                }

                if isSettingsPresented {
                    SettingsView(
                        viewModel: viewModel,
                        subscriptionStore: subscriptionStore,
                        dismiss: { isSettingsPresented = false },
                        openPaywall: { isPaywallPresented = true }
                    )
                    .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(swipeGesture)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: viewModel.isAgentPaused)
            .animation(.easeInOut(duration: 0.22), value: viewModel.isSnoozed)
            .animation(.easeInOut(duration: 0.25), value: isSettingsPresented)
            .fullScreenCover(isPresented: $isPaywallPresented) {
                PaywallView(subscriptionStore: subscriptionStore, dismiss: { isPaywallPresented = false })
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard max(abs(width), abs(height)) > 18 else { return }

                if abs(width) > abs(height) {
                    viewModel.swipe(width > 0 ? .right : .left)
                } else {
                    viewModel.swipe(height > 0 ? .down : .up)
                }
            }
    }
}

// MARK: - StatusBar

struct StatusBar: View {
    let score: Int
    let bestScore: Int
    let moves: Int
    let isPremium: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text("SHIFT BLAST")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.nightPurple)
                        .tracking(3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if isPremium {
                        Text("PRO")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.shiftYellow, in: Capsule())
                    }
                }
                Text("\(score)")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .shadow(color: Color.nightPurpleMid.opacity(0.25), radius: 12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text("SCORE")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.nightPurpleDim)
                    .tracking(3)
            }

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                Text("#\(moves)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.nightPurpleDim)
                    .monospacedDigit()
                    .lineLimit(1)

                VStack(alignment: .trailing, spacing: 1) {
                    Text("BEST")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.nightPurpleDim)
                        .tracking(2)
                        .lineLimit(1)
                    Text("\(bestScore)")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Color.nightPurpleMid)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Button(action: openSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.nightPurple.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.nightPurple.opacity(0.08))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
        }
    }
}

// MARK: - PulseGauge

private struct PulseGauge: View {
    let pulse: Int

    private var progress: Double {
        Double(min(100, max(0, pulse))) / 100
    }

    private var tint: Color {
        pulse <= 25 ? .shiftPink : .shiftLime
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PULSE")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                Text("DEAD SWIPES DRAIN IT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Text("\(pulse)%")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint, Color.shiftYellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * progress)
                        .shadow(color: tint.opacity(0.45), radius: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - SurgeGauge

private struct SurgeGauge: View {
    let surge: Int
    let chain: Int

    private var progress: Double {
        Double(min(100, max(0, surge))) / 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SURGE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                Text("→ OVERDRIVE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.32))
                if chain > 1 {
                    Text("CHAIN ×\(chain)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.shiftYellow)
                }
                Spacer(minLength: 6)
                Text("\(surge)%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.shiftViolet, .shiftPink, .shiftYellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * progress)
                        .shadow(color: Color.shiftPink.opacity(0.45), radius: 8)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        )
    }
}

// MARK: - BlastBanner

private struct BlastBanner: View {
    let summary: ClearSummary

    private var title: String {
        switch summary.lineCount {
        case 2: return "DOUBLE BLAST"
        case 3: return "TRIPLE BLAST"
        default: return "\(summary.lineCount)X BLAST"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 10)
            Text("+\(summary.scoreDelta)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.shiftYellow)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("BONUS +\(summary.bonus)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if summary.chain > 1 {
                Text("CHAIN ×\(summary.chain)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.shiftPink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Text(GameEngine.formattedYield(summary.yield))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.shiftCyan)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.shiftPink.opacity(0.26), Color.shiftCyan.opacity(0.16)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - EventStrip

private struct EventStrip: View {
    let lastClear: ClearSummary?
    let lastOverdrive: OverdriveSummary?
    let lastPulseEvent: PulseEvent?

    var body: some View {
        ZStack {
            if let lastOverdrive {
                OverdriveAlert(summary: lastOverdrive)
                    .transition(.scale.combined(with: .opacity))
            } else if let lastClear, lastClear.lineCount > 1 {
                BlastBanner(summary: lastClear)
                    .transition(.scale.combined(with: .opacity))
            } else if let lastPulseEvent {
                PulseAlert(event: lastPulseEvent)
                    .transition(.scale.combined(with: .opacity))
            } else {
                EventHint()
            }
        }
        .frame(height: 46)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: lastClear)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: lastOverdrive)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: lastPulseEvent)
    }
}

// MARK: - PulseAlert

private struct PulseAlert: View {
    let event: PulseEvent

    private var tint: Color {
        event.kind == .deadSwipe ? .shiftPink : .shiftLime
    }

    private var title: String {
        event.kind == .deadSwipe ? "DEAD SWIPE" : "PULSE RESTORED"
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 10)
            Text(event.delta > 0 ? "+\(event.delta)" : "\(event.delta)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text("\(event.value)%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.22), Color.white.opacity(0.04)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - EventHint

private struct EventHint: View {
    var body: some View {
        HStack {
            Text("CHARGE OVERDRIVE")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.24))
            Spacer()
            Text("CLEAR LINES")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.18))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

// MARK: - OverdriveAlert

private struct OverdriveAlert: View {
    let summary: OverdriveSummary

    private var lineName: String {
        switch summary.line {
        case .row(let row): return "ROW \(row + 1)"
        case .column(let column): return "COL \(column + 1)"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("OVERDRIVE")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.shiftYellow)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(lineName)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
            Spacer(minLength: 10)
            Text("\(summary.clearedCount) CLEARED")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("+\(summary.scoreDelta)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.shiftYellow.opacity(0.24), Color.shiftViolet.opacity(0.18)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - StatPill (used only in GameOverView)

private struct StatPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .shadow(color: tint.opacity(0.55), radius: 6)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.18), Color.white.opacity(0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - LeaderboardStrip

private struct LeaderboardStrip: View {
    let entries: [LeaderboardEntry]
    let currentScore: Int

    private var displayEntries: [LeaderboardEntry] {
        if entries.isEmpty {
            return [LeaderboardEntry(score: max(currentScore, 0), moves: 0, blocksLeft: 0)]
        }
        return Array(entries.prefix(3))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("LEADERBOARD")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("TOP 3")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.34))
            }

            VStack(spacing: 6) {
                ForEach(Array(displayEntries.enumerated()), id: \.element.id) { index, entry in
                    RankRow(rank: index + 1, entry: entry, isPlaceholder: entries.isEmpty)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - RankRow

private struct RankRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let isPlaceholder: Bool

    private var tint: Color {
        switch rank {
        case 1: return .shiftYellow
        case 2: return .shiftCyan
        default: return .shiftPink
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("#\(rank)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 28, alignment: .leading)

            Text(isPlaceholder ? "NO RUNS YET" : "\(entry.score)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(isPlaceholder ? 0.42 : 0.9))
                .monospacedDigit()

            Spacer()

            Text(isPlaceholder ? "--" : "\(entry.moves)M")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - GameOverView

private struct GameOverView: View {
    let score: Int
    let bestScore: Int
    let moves: Int
    let leaderboard: [LeaderboardEntry]
    let restart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("GAME OVER")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                Text("\(score)")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(Color.shiftCyan)
                    .monospacedDigit()

                HStack(spacing: 8) {
                    StatPill(title: "BEST", value: "\(bestScore)", tint: .shiftYellow)
                    StatPill(title: "MOVES", value: "\(moves)", tint: .shiftPink)
                }

                LeaderboardStrip(entries: leaderboard, currentScore: score)

                Button(action: restart) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 24, weight: .black))
                        .frame(width: 62, height: 62)
                        .foregroundStyle(.black)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .accessibilityLabel("Restart")
            }
            .padding(18)
            .frame(maxWidth: 360)
            .background(Color(red: 0.035, green: 0.038, blue: 0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 18)
        }
    }
}

// MARK: - AgentPauseOverlay

private struct AgentPauseOverlay: View {
    let backToWork: () -> Void
    let procrastinate: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.shiftLime)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.shiftLime.opacity(0.6), radius: 8)
                    Text("AGENT READY")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.shiftLime)
                        .tracking(0.5)
                }

                VStack(spacing: 6) {
                    Text("Distratto?")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("L'agente AI ha finito.\nIl tuo lavoro ti aspetta.")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                VStack(spacing: 10) {
                    Button(action: backToWork) {
                        VStack(spacing: 2) {
                            Text("TORNO AL LAVORO")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                            Text("La sana scelta")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.black.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.shiftLime, Color.shiftCyan],
                                startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }

                    Button(action: procrastinate) {
                        VStack(spacing: 2) {
                            Text("PROCRASTINO")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(Color.shiftPink)
                            Text("Ancora una mossa")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.shiftPink.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(
                Color(red: 0.035, green: 0.038, blue: 0.05),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.shiftLime.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.shiftLime.opacity(0.18), radius: 24, y: 6)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - SnoozeCurtain

private struct SnoozeCurtain: View {
    let wake: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.86)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.nightPurpleMid)

                Text("Buon lavoro.")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Text("Tap per riprendere quando vuoi.")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .multilineTextAlignment(.center)
            .padding(28)
        }
        .contentShape(Rectangle())
        .onTapGesture { wake() }
    }
}

// MARK: - StarField

private struct StarField: View {
    private static let stars: [StarData] = (0..<80).map { i in
        StarData(
            x: Double((i * 1_000_003 + 123_456) % 100_000) / 100_000,
            y: Double((i * 999_983  + 654_321) % 100_000) / 100_000,
            size: 0.5 + Double((i * 7_919 + 11) % 200) / 100.0,
            speed: 2.0 + Double((i * 6_271 +  7) % 400) / 100.0,
            phase: Double((i * 5_381 +  3) % 628) / 100.0
        )
    }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for star in StarField.stars {
                    let opacity = (sin(t / star.speed + star.phase) + 1) / 2 * 0.45 + 0.05
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: star.x * size.width  - star.size / 2,
                            y: star.y * size.height - star.size / 2,
                            width: star.size, height: star.size
                        )),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private struct StarData {
        let x, y, size, speed, phase: Double
    }
}

// MARK: - Night palette

extension Color {
    // oklch(0.65 0.08 280) — muted blue-violet for labels
    static let nightPurple    = Color(red: 0.52, green: 0.52, blue: 0.70)
    // oklch(0.50 0.06 280) — dimmer muted purple
    static let nightPurpleDim = Color(red: 0.38, green: 0.38, blue: 0.54)
    // oklch(0.60 0.10 280) — mid muted purple for best score
    static let nightPurpleMid = Color(red: 0.47, green: 0.47, blue: 0.65)
}
