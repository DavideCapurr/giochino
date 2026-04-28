import Foundation

struct MoveOutcome: Equatable {
    var clearedLines: [ClearedLine]
    var clearedBlockIDs: Set<UUID>
    var scoreDelta: Int
    var spawnedCount: Int
    var didGameOver: Bool
}

enum GameEngine {
    static let defaultBoardSize = 8
    static let initialBlockRange = 10..<15
    static let slideDuration: TimeInterval = 0.24

    static func newGame(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000_000), bestScore: Int = 0) -> GameState {
        var state = GameState(boardSize: defaultBoardSize, bestScore: bestScore, rng: SeededGenerator(seed: seed))
        let count = state.rng.nextInt(in: initialBlockRange)
        _ = spawnBlocks(count: count, in: &state, allowGameOver: false)
        return state
    }

    static func startMove(_ direction: SwipeDirection, in state: inout GameState, now: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Bool {
        guard !state.isGameOver, state.activeMove == nil else { return false }
        let original = Dictionary(uniqueKeysWithValues: state.blocks.map { ($0.id, $0.position) })
        let targets = compressedPositions(for: state.blocks, boardSize: state.boardSize, direction: direction)
        let steps = state.blocks.compactMap { block -> SlideStep? in
            guard let target = targets[block.id], let from = original[block.id] else { return nil }
            return SlideStep(blockID: block.id, from: from, to: target)
        }

        for index in state.blocks.indices {
            if let target = targets[state.blocks[index].id] {
                state.blocks[index].position = target
            }
        }

        state.highlightedLines = []
        state.clearingBlockIDs = []
        state.activeMove = ActiveMove(direction: direction, steps: steps, startedAt: now, duration: slideDuration, savedProgress: nil)
        return true
    }

    @discardableResult
    static func finishActiveMove(in state: inout GameState) -> MoveOutcome {
        state.activeMove = nil
        let clearResult = clearCompletedLines(in: &state)
        let spawnCount = state.rng.nextBool(probability: 0.5) ? 2 : 3
        let spawned = spawnBlocks(count: spawnCount, in: &state, allowGameOver: true)
        state.bestScore = max(state.bestScore, state.score)

        return MoveOutcome(
            clearedLines: clearResult.lines,
            clearedBlockIDs: clearResult.blockIDs,
            scoreDelta: clearResult.scoreDelta,
            spawnedCount: spawned,
            didGameOver: state.isGameOver
        )
    }

    static func emptyCells(in state: GameState) -> [GridPoint] {
        let occupied = Set(state.blocks.map(\.position))
        return (0..<state.boardSize).flatMap { row in
            (0..<state.boardSize).compactMap { column in
                let point = GridPoint(row: row, column: column)
                return occupied.contains(point) ? nil : point
            }
        }
    }

    @discardableResult
    static func spawnBlocks(count: Int, in state: inout GameState, allowGameOver: Bool) -> Int {
        var empty = emptyCells(in: state)
        guard empty.count >= count else {
            if allowGameOver {
                state.isGameOver = true
            }
            return 0
        }

        var spawned = 0
        for _ in 0..<count {
            let cellIndex = state.rng.nextInt(in: 0..<empty.count)
            let cell = empty.remove(at: cellIndex)
            let tone = BlockTone.allCases[state.rng.nextInt(in: 0..<BlockTone.allCases.count)]
            state.blocks.append(GameBlock(position: cell, tone: tone))
            spawned += 1
        }
        return spawned
    }

    static func clearCompletedLines(in state: inout GameState) -> (lines: [ClearedLine], blockIDs: Set<UUID>, scoreDelta: Int) {
        let rows = (0..<state.boardSize).filter { row in
            state.blocks.filter { $0.position.row == row }.count == state.boardSize
        }
        let columns = (0..<state.boardSize).filter { column in
            state.blocks.filter { $0.position.column == column }.count == state.boardSize
        }

        let lines = rows.map(ClearedLine.row) + columns.map(ClearedLine.column)
        guard !lines.isEmpty else {
            state.highlightedLines = []
            state.clearingBlockIDs = []
            return ([], [], 0)
        }

        let clearedIDs = Set(state.blocks.compactMap { block -> UUID? in
            if rows.contains(block.position.row) || columns.contains(block.position.column) {
                return block.id
            }
            return nil
        })

        state.blocks.removeAll { clearedIDs.contains($0.id) }
        state.highlightedLines = lines
        state.clearingBlockIDs = clearedIDs

        let base = lines.count * 100
        let combo = max(0, lines.count - 1) * 50
        let delta = base + combo
        state.score += delta
        return (lines, clearedIDs, delta)
    }

    private static func compressedPositions(for blocks: [GameBlock], boardSize: Int, direction: SwipeDirection) -> [UUID: GridPoint] {
        var result: [UUID: GridPoint] = [:]

        switch direction {
        case .left, .right:
            for row in 0..<boardSize {
                var rowBlocks = blocks.filter { $0.position.row == row }
                rowBlocks.sort {
                    direction == .left
                    ? $0.position.column < $1.position.column
                    : $0.position.column > $1.position.column
                }
                for (offset, block) in rowBlocks.enumerated() {
                    let column = direction == .left ? offset : boardSize - 1 - offset
                    result[block.id] = GridPoint(row: row, column: column)
                }
            }
        case .up, .down:
            for column in 0..<boardSize {
                var columnBlocks = blocks.filter { $0.position.column == column }
                columnBlocks.sort {
                    direction == .up
                    ? $0.position.row < $1.position.row
                    : $0.position.row > $1.position.row
                }
                for (offset, block) in columnBlocks.enumerated() {
                    let row = direction == .up ? offset : boardSize - 1 - offset
                    result[block.id] = GridPoint(row: row, column: column)
                }
            }
        }

        return result
    }
}
