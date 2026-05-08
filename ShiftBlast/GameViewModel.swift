import Foundation
import OSLog
import SwiftUI

private let log = Logger(subsystem: "com.davide.shiftblast", category: "GameViewModel")

@MainActor
final class GameViewModel: ObservableObject {
    private let store = GameStore()
    private let feedback = FeedbackPlayer()
    private var completionTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var spawnMarkerTask: Task<Void, Never>?
    private var recordNoticeTask: Task<Void, Never>?
    private var isResolvingMove = false
    private var agentWatcher: AgentSignalWatcher?
    private weak var gameCenter: GameCenterService?
    private var runStartingBestScore = 0
    private var announcedRecordMilestones: Set<String> = []

    @Published
    var state: GameState

    @Published
    var isAgentPaused: Bool = false

    @Published
    var isSnoozed: Bool = false

    @Published
    var isMuted: Bool = false

    @Published
    var recordNotice: RecordNotice?

    @Published var isAgentEnabled: Bool = false {
        didSet { updateAgentWatcher() }
    }

    init() {
        if let saved = store.load() {
            state = saved
        } else {
            state = GameEngine.newGame()
            store.save(state)
        }
        runStartingBestScore = state.bestScore
        resumeInterruptedMoveIfNeeded()
    }

    deinit {
        completionTask?.cancel()
        cleanupTask?.cancel()
        spawnMarkerTask?.cancel()
        recordNoticeTask?.cancel()
        agentWatcher?.stop()
    }

    func swipe(_ direction: SwipeDirection) {
        guard !isAgentPaused, !isSnoozed, !state.isGameOver else { return }
        feedback.impact()
        guard !isResolvingMove else { return }
        guard GameEngine.startMove(direction, in: &state) else { return }
        store.save(state)
        scheduleMoveCompletion(after: state.activeMove?.duration ?? GameEngine.slideDuration)
    }

    func restart() {
        completionTask?.cancel()
        cleanupTask?.cancel()
        spawnMarkerTask?.cancel()
        isResolvingMove = false
        runStartingBestScore = state.bestScore
        announcedRecordMilestones = []
        recordNotice = nil
        state = GameEngine.newGame(bestScore: state.bestScore, leaderboard: state.leaderboard)
        store.save(state)
    }

    func persistForInterruption() {
        freezeActiveMoveIfNeeded()
        store.save(state)
    }

    func resumeInterruptedMoveIfNeeded() {
        guard let activeMove = state.activeMove else { return }
        let frozenProgress = activeMove.savedProgress ?? progress(for: activeMove, at: Date())
        var resumedMove = activeMove
        resumedMove.savedProgress = nil
        resumedMove.startedAt = Date().timeIntervalSinceReferenceDate - frozenProgress * activeMove.duration
        state.activeMove = resumedMove
        store.save(state)

        let remaining = max(0.03, activeMove.duration * (1 - frozenProgress))
        scheduleMoveCompletion(after: remaining)
    }

    func handleAgentReadySignal() {
        guard !isAgentPaused else { return }
        freezeActiveMoveIfNeeded()
        store.save(state)
        isAgentPaused = true
        log.notice("⏸️ game paused by agent watcher")
    }

    func dismissAgentPause() {
        guard isAgentPaused else { return }
        isAgentPaused = false
        isSnoozed = false
        resumeInterruptedMoveIfNeeded()
    }

    func snoozeFromAgentPause() {
        isAgentPaused = false
        isSnoozed = true
        store.save(state)
    }

    func wakeFromSnooze() {
        guard isSnoozed else { return }
        isSnoozed = false
        resumeInterruptedMoveIfNeeded()
    }

    func bindGameCenter(_ service: GameCenterService) {
        gameCenter = service
    }

    func toggleMute() {
        isMuted.toggle()
        feedback.isMuted = isMuted
    }

    private func updateAgentWatcher() {
        if isAgentEnabled {
            guard agentWatcher == nil else { return }
            let watcher = AgentSignalWatcher { [weak self] _ in
                self?.handleAgentReadySignal()
            }
            agentWatcher = watcher
            watcher.start()
        } else {
            agentWatcher?.stop()
            agentWatcher = nil
        }
    }

    func displayPosition(for block: GameBlock, now: Date) -> CGPoint? {
        guard
            let activeMove = state.activeMove,
            let step = activeMove.steps.first(where: { $0.blockID == block.id })
        else {
            return nil
        }

        let progress = activeMove.savedProgress ?? progress(for: activeMove, at: now)
        let eased = 1 - pow(1 - progress, 3)
        let row = Double(step.from.row) + Double(step.to.row - step.from.row) * eased
        let column = Double(step.from.column) + Double(step.to.column - step.from.column) * eased
        return CGPoint(x: column, y: row)
    }

    private func freezeActiveMoveIfNeeded() {
        guard var activeMove = state.activeMove else { return }
        activeMove.savedProgress = progress(for: activeMove, at: Date())
        state.activeMove = activeMove
        completionTask?.cancel()
    }

    private func progress(for activeMove: ActiveMove, at date: Date) -> Double {
        guard activeMove.duration > 0 else { return 1 }
        let elapsed = date.timeIntervalSinceReferenceDate - activeMove.startedAt
        return min(1, max(0, elapsed / activeMove.duration))
    }

    private func scheduleMoveCompletion(after delay: TimeInterval) {
        completionTask?.cancel()
        completionTask = Task { [weak self] in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            self?.completeMove()
        }
    }

    private func completeMove() {
        guard state.activeMove != nil else { return }
        isResolvingMove = true
        let previousScore = state.score
        let outcome = GameEngine.finishActiveMove(in: &state)
        evaluateRecordNotice(previousScore: previousScore)
        if !outcome.clearedLines.isEmpty {
            feedback.clear()
            spawnAfterDelay(0.16)
        } else {
            spawnAfterDelay(0.06)
        }
        store.save(state)
    }

    private func spawnAfterDelay(_ delay: TimeInterval) {
        cleanupTask?.cancel()
        cleanupTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }
                let previousScore = self.state.score
                _ = GameEngine.spawnAfterMove(in: &self.state)
                self.evaluateRecordNotice(previousScore: previousScore)
                if self.state.isGameOver {
                    GameEngine.recordFinishedRun(in: &self.state)
                    let finalScore = self.state.score
                    if let gameCenter = self.gameCenter {
                        Task { await gameCenter.submit(score: finalScore) }
                    }
                }
                self.isResolvingMove = false
                self.store.save(self.state)
                self.clearSpawnMarkersAfterDelay()
            }
        }
    }

    private func evaluateRecordNotice(previousScore: Int) {
        let currentScore = state.score
        guard currentScore > previousScore else { return }

        let targets = recordTargets()
        for target in targets where target.score > 0 {
            if previousScore < target.score, currentScore >= target.score {
                announceRecordNotice(
                    key: "\(target.id):passed",
                    notice: RecordNotice(
                        kind: .passed,
                        title: target.passedTitle,
                        detail: "\(currentScore) / \(target.score)"
                    )
                )
                return
            }

            let nearScore = max(1, Int((Double(target.score) * 0.9).rounded(.down)))
            if previousScore < nearScore, currentScore >= nearScore, currentScore < target.score {
                announceRecordNotice(
                    key: "\(target.id):near",
                    notice: RecordNotice(
                        kind: .near,
                        title: target.nearTitle,
                        detail: "\(target.score - currentScore) TO GO"
                    )
                )
                return
            }
        }
    }

    private func announceRecordNotice(key: String, notice: RecordNotice) {
        guard announcedRecordMilestones.insert(key).inserted else { return }
        recordNoticeTask?.cancel()
        recordNotice = notice
        recordNoticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            await MainActor.run {
                guard self?.recordNotice?.id == notice.id else { return }
                self?.recordNotice = nil
            }
        }
    }

    private func recordTargets() -> [RecordTarget] {
        var targets: [RecordTarget] = []
        let bestAtRunStart = max(runStartingBestScore, state.leaderboard.map(\.score).max() ?? 0)
        if bestAtRunStart > 0 {
            targets.append(
                RecordTarget(
                    id: "local-best",
                    score: bestAtRunStart + 1,
                    nearTitle: "LOCAL BEST IN RANGE",
                    passedTitle: "NEW LOCAL BEST"
                )
            )
        }

        if let gameCenterBest = gameCenter?.personalBest, gameCenterBest > bestAtRunStart {
            targets.append(
                RecordTarget(
                    id: "game-center-best",
                    score: gameCenterBest + 1,
                    nearTitle: "GAME CENTER BEST IN RANGE",
                    passedTitle: "NEW GAME CENTER BEST"
                )
            )
        }

        if let rivals = gameCenter?.globalTop {
            targets.append(
                contentsOf: rivals
                    .filter { !$0.isLocalPlayer && $0.score > 0 }
                    .map { rival in
                        RecordTarget(
                            id: "global-\(rival.id)-\(rival.rank)",
                            score: rival.score + 1,
                            nearTitle: "RIVAL #\(rival.rank) IN RANGE",
                            passedTitle: "PASSED \(rival.displayName.uppercased())"
                        )
                    }
                )
        }

        if let friends = gameCenter?.friendsTop {
            targets.append(
                contentsOf: friends
                    .filter { !$0.isLocalPlayer && $0.score > 0 }
                    .map { friend in
                        RecordTarget(
                            id: "friend-\(friend.id)-\(friend.rank)",
                            score: friend.score + 1,
                            nearTitle: "FRIEND #\(friend.rank) IN RANGE",
                            passedTitle: "PASSED \(friend.displayName.uppercased())"
                        )
                    }
                )
        }

        return targets.sorted { $0.score < $1.score }
    }

    private struct RecordTarget {
        var id: String
        var score: Int
        var nearTitle: String
        var passedTitle: String
    }

    private func clearSpawnMarkersAfterDelay() {
        spawnMarkerTask?.cancel()
        spawnMarkerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            await MainActor.run {
                guard let self else { return }
                self.state.spawningBlockIDs = []
                self.store.save(self.state)
            }
        }
    }
}
