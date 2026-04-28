import Foundation
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    private let store = GameStore()
    private let feedback = FeedbackPlayer()
    private var completionTask: Task<Void, Never>?

    @Published
    var state: GameState

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
    }

    func swipe(_ direction: SwipeDirection) {
        guard GameEngine.startMove(direction, in: &state) else { return }
        feedback.impact()
        store.save(state)
        scheduleMoveCompletion(after: state.activeMove?.duration ?? GameEngine.slideDuration)
    }

    func restart() {
        completionTask?.cancel()
        state = GameEngine.newGame(bestScore: state.bestScore)
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
        let outcome = GameEngine.finishActiveMove(in: &state)
        if !outcome.clearedLines.isEmpty {
            feedback.clear()
            clearHighlightsAfterDelay()
        }
        store.save(state)
    }

    private func clearHighlightsAfterDelay() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            await MainActor.run {
                self?.state.highlightedLines = []
                self?.state.clearingBlockIDs = []
                if let state = self?.state {
                    self?.store.save(state)
                }
            }
        }
    }
}
