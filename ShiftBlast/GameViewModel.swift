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
    private var isResolvingMove = false
    private var agentWatcher: AgentSignalWatcher?
    private weak var gameCenter: GameCenterService?

    @Published
    var state: GameState

    @Published
    var isAgentPaused: Bool = false

    @Published
    var isSnoozed: Bool = false

    @Published
    var isMuted: Bool = false

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
        resumeInterruptedMoveIfNeeded()
    }

    deinit {
        completionTask?.cancel()
        cleanupTask?.cancel()
        spawnMarkerTask?.cancel()
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
        let outcome = GameEngine.finishActiveMove(in: &state)
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
                _ = GameEngine.spawnAfterMove(in: &self.state)
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
