import Foundation

struct MoveOutcome: Equatable {
    var clearedLines: [ClearedLine]
    var clearedBlockIDs: Set<UUID>
    var scoreDelta: Int
    var spawnedBlockIDs: Set<UUID>
    var didGameOver: Bool
}

enum GameEngine {
    static let defaultBoardSize = 8
    static let initialEmptyCellRange = 22..<34
    static let slideDuration: TimeInterval = 0.24
    static let scorePerLine = 400
    static let overdriveThreshold = 90
    static let maxPulse = 100

    static func newGame(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000_000), bestScore: Int = 0, leaderboard: [LeaderboardEntry] = []) -> GameState {
        var state = GameState(boardSize: defaultBoardSize, bestScore: bestScore, leaderboard: leaderboard, rng: SeededGenerator(seed: seed))
        let emptyCellCount = state.rng.nextInt(in: initialEmptyCellRange)
        seedDenseBoard(in: &state, emptyCellCount: emptyCellCount)
        state.spawningBlockIDs = []
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
        let movingSteps = steps.filter { $0.from != $0.to }
        guard !movingSteps.isEmpty else { return false }

        for index in state.blocks.indices {
            if let target = targets[state.blocks[index].id] {
                state.blocks[index].position = target
            }
        }

        state.highlightedLines = []
        state.clearingBlockIDs = []
        state.spawningBlockIDs = []
        state.lastClear = nil
        state.lastOverdrive = nil
        state.lastPulseEvent = nil
        state.moves += 1
        state.tier = tier(forScore: state.score, moves: state.moves)
        state.activeMove = ActiveMove(direction: direction, steps: movingSteps, startedAt: now, duration: slideDuration, savedProgress: nil)
        return true
    }

    static func recordFinishedRun(in state: inout GameState, now: Date = Date()) {
        guard state.isGameOver, state.score > 0 else { return }
        let entry = LeaderboardEntry(score: state.score, moves: state.moves, blocksLeft: state.blocks.count, playedAt: now)
        state.leaderboard.append(entry)
        state.leaderboard.sort {
            if $0.score == $1.score {
                return $0.moves < $1.moves
            }
            return $0.score > $1.score
        }
        state.leaderboard = Array(state.leaderboard.prefix(5))
        state.bestScore = max(state.bestScore, state.leaderboard.first?.score ?? state.score)
    }

    /// Brings a finished run back to life: clears breathing room on the board, refills the
    /// pulse and resets the volatile move state so the player can keep going. Used by the
    /// "continue" flow (rewarded ad for free players, free perk for ad-removed players).
    static func revive(in state: inout GameState, targetEmptyCells: Int = 30) {
        guard state.isGameOver else { return }

        state.isGameOver = false
        state.activeMove = nil
        state.clearingBlockIDs = []
        state.highlightedLines = []
        state.spawningBlockIDs = []
        state.lastClear = nil
        state.lastOverdrive = nil
        state.lastPulseEvent = nil
        state.chain = 0
        state.surge = 0
        state.pulse = maxPulse

        let totalCells = state.boardSize * state.boardSize
        let desiredEmpty = min(totalCells - 1, max(state.boardSize, targetEmptyCells))

        // Clear the densest lines until the board has enough room to play again.
        while emptyCells(in: state).count < desiredEmpty, !state.blocks.isEmpty {
            guard let line = densestLine(in: state) else { break }
            switch line {
            case .row(let row):
                state.blocks.removeAll { $0.position.row == row }
            case .column(let column):
                state.blocks.removeAll { $0.position.column == column }
            }
        }
    }

    @discardableResult
    static func finishActiveMove(in state: inout GameState) -> MoveOutcome {
        state.activeMove = nil
        let clearResult = clearCompletedLines(in: &state)
        triggerOverdriveIfReady(in: &state)
        state.bestScore = max(state.bestScore, state.score)

        return MoveOutcome(
            clearedLines: clearResult.lines,
            clearedBlockIDs: state.clearingBlockIDs,
            scoreDelta: clearResult.scoreDelta,
            spawnedBlockIDs: [],
            didGameOver: state.isGameOver
        )
    }

    @discardableResult
    static func spawnAfterMove(in state: inout GameState) -> MoveOutcome {
        removeClearedBlocks(in: &state)
        guard !state.isGameOver else {
            return MoveOutcome(
                clearedLines: [],
                clearedBlockIDs: [],
                scoreDelta: 0,
                spawnedBlockIDs: [],
                didGameOver: true
            )
        }
        let emptyCount = emptyCells(in: state).count
        guard emptyCount > 0 else {
            state.isGameOver = true
            return MoveOutcome(
                clearedLines: [],
                clearedBlockIDs: [],
                scoreDelta: 0,
                spawnedBlockIDs: [],
                didGameOver: true
            )
        }
        let spawnCount = incomingBlockCount(
            forXP: yield(forTally: state.tally),
            emptyCellCount: emptyCount,
            rng: &state.rng
        )
        let spawnedIDs = spawnBlocks(count: spawnCount, in: &state, allowGameOver: true)
        state.bestScore = max(state.bestScore, state.score)

        return MoveOutcome(
            clearedLines: [],
            clearedBlockIDs: [],
            scoreDelta: 0,
            spawnedBlockIDs: spawnedIDs,
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
    static func spawnBlocks(count: Int, in state: inout GameState, allowGameOver: Bool) -> Set<UUID> {
        var empty = emptyCells(in: state)
        guard empty.count >= count else {
            if allowGameOver {
                state.isGameOver = true
            }
            state.spawningBlockIDs = []
            return []
        }

        var spawnedIDs = Set<UUID>()
        for _ in 0..<count {
            let cellIndex = spawnCellIndex(from: empty, existingBlocks: state.blocks, boardSize: state.boardSize, rng: &state.rng)
            let cell = empty.remove(at: cellIndex)
            let tone = BlockTone.allCases[state.rng.nextInt(in: 0..<BlockTone.allCases.count)]
            let block = GameBlock(position: cell, tone: tone)
            state.blocks.append(block)
            spawnedIDs.insert(block.id)
        }
        state.spawningBlockIDs = spawnedIDs
        return spawnedIDs
    }

    private static func spawnCellIndex(from emptyCells: [GridPoint], existingBlocks: [GameBlock], boardSize: Int, rng: inout SeededGenerator) -> Int {
        let occupied = Set(existingBlocks.map(\.position))
        let safeIndexes = emptyCells.indices.filter { index in
            !wouldCompleteLine(at: emptyCells[index], occupied: occupied, boardSize: boardSize)
        }

        guard !safeIndexes.isEmpty else {
            return rng.nextInt(in: 0..<emptyCells.count)
        }

        return safeIndexes[rng.nextInt(in: 0..<safeIndexes.count)]
    }

    private static func wouldCompleteLine(at point: GridPoint, occupied: Set<GridPoint>, boardSize: Int) -> Bool {
        let rowWouldFill = (0..<boardSize).allSatisfy { column in
            column == point.column || occupied.contains(GridPoint(row: point.row, column: column))
        }
        let columnWouldFill = (0..<boardSize).allSatisfy { row in
            row == point.row || occupied.contains(GridPoint(row: row, column: point.column))
        }
        return rowWouldFill || columnWouldFill
    }

    static func seedDenseBoard(in state: inout GameState, emptyCellCount requestedEmptyCellCount: Int) {
        let size = state.boardSize
        let totalCells = size * size
        let targetEmptyCellCount = min(totalCells - 1, max(size, requestedEmptyCellCount))
        var emptyCells = Set<GridPoint>()
        let thinRow = state.rng.nextInt(in: 0..<size)
        let thinColumn = state.rng.nextInt(in: 0..<size)
        let thinRowBlockColumn = randomIndex(excluding: thinColumn, size: size, rng: &state.rng)
        let thinColumnBlockRow = randomIndex(excluding: thinRow, size: size, rng: &state.rng)

        for column in 0..<size where column != thinRowBlockColumn {
            emptyCells.insert(GridPoint(row: thinRow, column: column))
        }

        for row in 0..<size where row != thinColumnBlockRow {
            emptyCells.insert(GridPoint(row: row, column: thinColumn))
        }

        for row in 0..<size {
            emptyCells.insert(GridPoint(row: row, column: state.rng.nextInt(in: 0..<size)))
        }

        for column in 0..<size where !emptyCells.contains(where: { $0.column == column }) {
            emptyCells.insert(GridPoint(row: state.rng.nextInt(in: 0..<size), column: column))
        }

        while emptyCells.count < targetEmptyCellCount {
            emptyCells.insert(GridPoint(row: state.rng.nextInt(in: 0..<size), column: state.rng.nextInt(in: 0..<size)))
        }

        var blocks: [GameBlock] = []
        blocks.reserveCapacity(totalCells - emptyCells.count)
        for row in 0..<size {
            for column in 0..<size {
                let point = GridPoint(row: row, column: column)
                guard !emptyCells.contains(point) else { continue }
                let tone = BlockTone.allCases[state.rng.nextInt(in: 0..<BlockTone.allCases.count)]
                blocks.append(GameBlock(position: point, tone: tone))
            }
        }
        state.blocks = blocks
    }

    private static func randomIndex(excluding excludedIndex: Int, size: Int, rng: inout SeededGenerator) -> Int {
        guard size > 1 else { return 0 }
        var index = rng.nextInt(in: 0..<(size - 1))
        if index >= excludedIndex {
            index += 1
        }
        return index
    }

    static func tier(forScore score: Int, moves: Int) -> Int {
        let scoreTier = score / 500
        let moveTier = moves / 18
        return max(1, 1 + max(scoreTier, moveTier))
    }

    static func incomingBlockPreview(forTier tier: Int) -> String {
        switch tier {
        case 1:
            return "2"
        case 2:
            return "2-3"
        case 3:
            return "3-4"
        case 4:
            return "4"
        default:
            return tier.isMultiple(of: 3) ? "4-5" : "4"
        }
    }

    static func incomingBlockPreview(forXP xp: Double) -> String {
        let range = incomingBlockRange(forXP: xp)
        if range.lowerBound == range.upperBound {
            return "\(range.upperBound)"
        }
        return "\(range.lowerBound)-\(range.upperBound)"
    }

    static func incomingBlockPreview(forXP xp: Double, emptyCellCount: Int) -> String {
        guard emptyCellCount > 0 else { return "0" }

        let baseRange = incomingBlockRange(forXP: xp)

        let pressureCap: Int
        switch emptyCellCount {
        case 1...5:
            pressureCap = 1
        case 6...12:
            pressureCap = 2
        case 13...18:
            pressureCap = 3
        case 19...24:
            pressureCap = 3
        default:
            pressureCap = 4
        }

        let refillFloor = refillSpawnFloor(forEmptyCellCount: emptyCellCount)
        let lower = min(emptyCellCount, max(refillFloor, min(baseRange.lowerBound, pressureCap)))
        let upper = min(emptyCellCount, max(lower, min(max(baseRange.upperBound, refillFloor), pressureCap)))
        if lower == upper {
            return "\(upper)"
        }
        return "\(lower)-\(upper)"
    }

    static func yield(forTally tally: Int) -> Double {
        1 + sqrt(Double(max(0, tally))) * 0.1
    }

    static func formattedYield(_ yield: Double) -> String {
        String(format: "%.2fx", yield)
    }

    static func difficultyCoefficient(forScore score: Int, moves: Int, tally: Int) -> Double {
        1 + Double(max(0, moves)) * 0.0028 + Double(max(0, tally)) * 0.022 + Double(max(0, score)) / 14_000
    }

    static func pulseDrain(forDifficulty difficulty: Double, rng: inout SeededGenerator) -> Int {
        let base = min(12, 3 + Int((max(1, difficulty) - 1) * 1.1))
        let jitter = difficulty < 1.05 ? 0 : rng.nextInt(in: -3..<6)
        return max(1, base + jitter)
    }

    static func pulseGain(forLineCount lineCount: Int, chain: Int = 0, difficulty: Double = 1) -> Int {
        let base: Int
        switch lineCount {
        case 0: return 0
        case 1: base = 6
        case 2: base = 12
        default: base = 20
        }
        let raw = base + min(10, max(0, chain) * 2)
        let decay = max(0.55, 1.0 - (difficulty - 1) * 0.04)
        return max(3, Int((Double(raw) * decay).rounded()))
    }

    static func chainBonus(forChain chain: Int, difficulty: Double) -> Int {
        let perChain = max(30, 90 - Int((difficulty - 1) * 8))
        return max(0, chain - 1) * perChain
    }

    static func incomingBlockCount(forTier tier: Int, rng: inout SeededGenerator) -> Int {
        switch tier {
        case 1:
            return 2
        case 2:
            return rng.nextBool(probability: 0.7) ? 2 : 3
        case 3:
            return rng.nextBool(probability: 0.45) ? 4 : 3
        case 4:
            return 4
        default:
            let extraProbability = min(0.45, 0.1 + Double(tier - 5) * 0.03)
            return rng.nextBool(probability: extraProbability) ? 5 : 4
        }
    }

    static func incomingBlockCount(forXP xp: Double, rng: inout SeededGenerator) -> Int {
        switch xp {
        case ..<1.15:
            let roll = rng.nextInt(in: 0..<10)
            if roll < 2 { return 3 }
            if roll < 7 { return 2 }
            return 1
        case ..<1.35:
            return rng.nextBool(probability: 0.35) ? 1 : 2
        case ..<1.7:
            return rng.nextBool(probability: 0.55) ? 1 : 2
        default:
            return rng.nextBool(probability: 0.85) ? 1 : 2
        }
    }

    static func incomingBlockCount(forXP xp: Double, emptyCellCount: Int, rng: inout SeededGenerator) -> Int {
        guard emptyCellCount > 0 else { return 0 }

        let baseCount = incomingBlockCount(forXP: xp, rng: &rng)
        let pressureCap: Int
        switch emptyCellCount {
        case 1...5:
            pressureCap = 1
        case 6...12:
            pressureCap = 2
        case 13...18:
            pressureCap = 3
        case 19...24:
            pressureCap = 3
        default:
            pressureCap = 4
        }

        let refillFloor = refillSpawnFloor(forEmptyCellCount: emptyCellCount)
        return min(emptyCellCount, max(refillFloor, min(baseCount, pressureCap)))
    }

    static func refillSpawnFloor(forEmptyCellCount emptyCellCount: Int) -> Int {
        switch emptyCellCount {
        case 29...:
            return 4
        case 25...28:
            return 3
        case 19...24:
            return 2
        case 13...18:
            return 2
        default:
            return 1
        }
    }

    static func removeClearedBlocks(in state: inout GameState) {
        guard !state.clearingBlockIDs.isEmpty else { return }
        let clearingIDs = state.clearingBlockIDs
        state.blocks.removeAll { clearingIDs.contains($0.id) }
        state.clearingBlockIDs = []
        state.highlightedLines = []
    }

    static func clearCompletedLines(in state: inout GameState) -> (lines: [ClearedLine], blockIDs: Set<UUID>, scoreDelta: Int) {
        let size = state.boardSize
        var rowCounts = [Int](repeating: 0, count: size)
        var columnCounts = [Int](repeating: 0, count: size)
        for block in state.blocks {
            rowCounts[block.position.row] += 1
            columnCounts[block.position.column] += 1
        }
        let rows = (0..<size).filter { rowCounts[$0] == size }
        let columns = (0..<size).filter { columnCounts[$0] == size }

        let lines = rows.map(ClearedLine.row) + columns.map(ClearedLine.column)
        guard !lines.isEmpty else {
            state.highlightedLines = []
            state.clearingBlockIDs = []
            state.lastClear = nil
            state.chain = 0
            let difficulty = difficultyCoefficient(forScore: state.score, moves: state.moves, tally: state.tally)
            var drain = pulseDrain(forDifficulty: difficulty, rng: &state.rng)
            if state.pulse <= 25 {
                drain = min(drain, max(1, state.pulse / 2))
            }
            state.pulse = max(0, state.pulse - drain)
            state.lastPulseEvent = PulseEvent(kind: .deadSwipe, delta: -drain, value: state.pulse)
            if state.pulse == 0 {
                state.isGameOver = true
            }
            return ([], [], 0)
        }

        let clearedIDs = Set(state.blocks.compactMap { block -> UUID? in
            if rows.contains(block.position.row) || columns.contains(block.position.column) {
                return block.id
            }
            return nil
        })

        state.highlightedLines = lines
        state.clearingBlockIDs = clearedIDs

        state.chain += 1

        let difficulty = difficultyCoefficient(forScore: state.score, moves: state.moves, tally: state.tally)
        let base = lines.count * scorePerLine
        let combo = simultaneousClearBonus(forLineCount: lines.count)
        let chBonus = chainBonus(forChain: state.chain, difficulty: difficulty)
        let rawDelta = base + combo + chBonus
        state.tally += lines.count
        let yieldValue = yield(forTally: state.tally)
        let delta = Int((Double(rawDelta) * yieldValue).rounded())
        let surgeGain = surgeGain(forLineCount: lines.count, simultaneousBonus: combo, chain: state.chain)
        let pGain = pulseGain(forLineCount: lines.count, chain: state.chain, difficulty: difficulty)
        state.score += delta
        state.surge += surgeGain
        state.pulse = min(maxPulse, state.pulse + pGain)
        state.lastPulseEvent = PulseEvent(kind: .clear, delta: pGain, value: state.pulse)
        state.tier = tier(forScore: state.score, moves: state.moves)
        state.lastClear = ClearSummary(
            lineCount: lines.count,
            scoreDelta: delta,
            bonus: combo + chBonus,
            chain: state.chain,
            surgeGained: surgeGain,
            yield: yieldValue
        )
        return (lines, clearedIDs, delta)
    }

    static func simultaneousClearBonus(forLineCount lineCount: Int) -> Int {
        guard lineCount > 1 else { return 0 }
        return (lineCount - 1) * 500 + max(0, lineCount - 2) * 250
    }

    static func surgeGain(forLineCount lineCount: Int, simultaneousBonus: Int, chain: Int) -> Int {
        32 * lineCount + simultaneousBonus / 18 + min(30, max(0, chain - 1) * 5)
    }

    @discardableResult
    static func triggerOverdriveIfReady(in state: inout GameState) -> OverdriveSummary? {
        guard state.surge >= overdriveThreshold else { return nil }
        let alreadyClearing = state.clearingBlockIDs
        guard let target = densestLine(in: state, excluding: alreadyClearing) else { return nil }

        let targetIDs = Set(state.blocks.compactMap { block -> UUID? in
            if alreadyClearing.contains(block.id) { return nil }
            switch target {
            case .row(let row):
                return block.position.row == row ? block.id : nil
            case .column(let column):
                return block.position.column == column ? block.id : nil
            }
        })
        let blockCount = targetIDs.count
        guard blockCount > 0 else { return nil }

        state.surge -= overdriveThreshold
        let chainMultiplier = 1.0 + Double(max(0, state.chain - 1)) * 0.5
        let yieldValue = yield(forTally: state.tally)
        let delta = Int((Double(75 * blockCount) * chainMultiplier * yieldValue).rounded())
        state.score += delta
        state.pulse = min(maxPulse, state.pulse + 8)
        state.tier = tier(forScore: state.score, moves: state.moves)

        state.clearingBlockIDs.formUnion(targetIDs)
        let summary = OverdriveSummary(clearedCount: blockCount, line: target, scoreDelta: delta)
        state.lastOverdrive = summary
        return summary
    }

    private static func incomingBlockRange(forXP xp: Double) -> ClosedRange<Int> {
        switch xp {
        case ..<1.15:
            return 2...3
        case ..<1.35:
            return 2...2
        case ..<1.7:
            return 1...2
        default:
            return 1...1
        }
    }

    private static func densestLine(in state: GameState, excluding excluded: Set<UUID> = []) -> ClearedLine? {
        let size = state.boardSize
        var rowCounts = [Int](repeating: 0, count: size)
        var columnCounts = [Int](repeating: 0, count: size)
        for block in state.blocks where !excluded.contains(block.id) {
            rowCounts[block.position.row] += 1
            columnCounts[block.position.column] += 1
        }
        var best: (line: ClearedLine, count: Int)?
        for row in 0..<size where rowCounts[row] > (best?.count ?? 0) {
            best = (.row(row), rowCounts[row])
        }
        for column in 0..<size where columnCounts[column] > (best?.count ?? 0) {
            best = (.column(column), columnCounts[column])
        }
        return best?.line
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
