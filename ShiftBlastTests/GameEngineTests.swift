import XCTest
@testable import ShiftBlast

final class GameEngineTests: XCTestCase {
    func testSwipeLeftCompactsRows() {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 0, column: 3), tone: .cyan),
            GameBlock(position: GridPoint(row: 0, column: 6), tone: .pink),
            GameBlock(position: GridPoint(row: 2, column: 4), tone: .lime)
        ])

        XCTAssertTrue(GameEngine.startMove(.left, in: &state, now: 0))

        let positions = Set(state.blocks.map(\.position))
        XCTAssertEqual(positions, [
            GridPoint(row: 0, column: 0),
            GridPoint(row: 0, column: 1),
            GridPoint(row: 2, column: 0)
        ])
    }

    func testSwipeDownCompactsColumns() {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 0, column: 1), tone: .cyan),
            GameBlock(position: GridPoint(row: 4, column: 1), tone: .pink),
            GameBlock(position: GridPoint(row: 2, column: 7), tone: .lime)
        ])

        XCTAssertTrue(GameEngine.startMove(.down, in: &state, now: 0))

        let positions = Set(state.blocks.map(\.position))
        XCTAssertEqual(positions, [
            GridPoint(row: 7, column: 1),
            GridPoint(row: 6, column: 1),
            GridPoint(row: 7, column: 7)
        ])
    }

    func testClearCompletedRowScoresAndRemovesBlocks() {
        var state = fixture(blocks: (0..<8).map {
            GameBlock(position: GridPoint(row: 3, column: $0), tone: .cyan)
        })

        let result = GameEngine.clearCompletedLines(in: &state)

        XCTAssertEqual(result.lines, [.row(3)])
        let yield = GameEngine.yield(forTally: 1)
        XCTAssertEqual(result.scoreDelta, Int((300.0 * yield).rounded()))
        XCTAssertEqual(state.clearingBlockIDs.count, 8)
        GameEngine.removeClearedBlocks(in: &state)
        XCTAssertTrue(state.blocks.isEmpty)
        XCTAssertEqual(state.score, result.scoreDelta)
    }

    func testClearMultipleLinesAddsComboBonus() {
        var blocks = (0..<8).map { GameBlock(position: GridPoint(row: 0, column: $0), tone: .cyan) }
        blocks += (1..<8).map { GameBlock(position: GridPoint(row: $0, column: 0), tone: .pink) }
        var state = fixture(blocks: blocks)

        let result = GameEngine.clearCompletedLines(in: &state)

        XCTAssertEqual(Set(result.lines), [.row(0), .column(0)])
        let yield = GameEngine.yield(forTally: 2)
        XCTAssertEqual(result.scoreDelta, Int((1100.0 * yield).rounded()))
        XCTAssertEqual(state.lastClear, ClearSummary(lineCount: 2, scoreDelta: result.scoreDelta, bonus: 500, chain: 1, surgeGained: 91, yield: yield))
        GameEngine.removeClearedBlocks(in: &state)
        XCTAssertEqual(state.score, result.scoreDelta)
    }

    func testTripleClearAddsLargerSimultaneousBonus() {
        var blocks = (0..<8).map { GameBlock(position: GridPoint(row: 0, column: $0), tone: .cyan) }
        blocks += (1..<8).map { GameBlock(position: GridPoint(row: $0, column: 0), tone: .pink) }
        blocks += (1..<8).map { GameBlock(position: GridPoint(row: $0, column: 1), tone: .lime) }
        var state = fixture(blocks: blocks)

        let result = GameEngine.clearCompletedLines(in: &state)

        XCTAssertEqual(Set(result.lines), [.row(0), .column(0), .column(1)])
        let yield = GameEngine.yield(forTally: 3)
        XCTAssertEqual(result.scoreDelta, Int((2150.0 * yield).rounded()))
        XCTAssertEqual(state.lastClear, ClearSummary(lineCount: 3, scoreDelta: result.scoreDelta, bonus: 1250, chain: 1, surgeGained: 165, yield: yield))
    }

    func testYieldIncreasesWithTallyAndIgnoresSurgeDrops() {
        var state = fixture(blocks: (0..<8).map {
            GameBlock(position: GridPoint(row: 2, column: $0), tone: .cyan)
        })
        state.tally = 24
        state.surge = 75

        let result = GameEngine.clearCompletedLines(in: &state)

        let expectedYield = GameEngine.yield(forTally: 25)
        XCTAssertEqual(result.scoreDelta, Int((300.0 * expectedYield).rounded()))
        XCTAssertEqual(state.lastClear?.yield, expectedYield)
        XCTAssertEqual(GameEngine.formattedYield(GameEngine.yield(forTally: state.tally)), "1.50x")
    }

    func testDeadSwipeDrainsPulseAndShowsEvent() {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 0, column: 0), tone: .cyan)
        ])
        state.moves = 1

        let result = GameEngine.clearCompletedLines(in: &state)

        XCTAssertTrue(result.lines.isEmpty)
        XCTAssertEqual(state.pulse, 94)
        XCTAssertEqual(state.lastPulseEvent, PulseEvent(kind: .deadSwipe, delta: -6, value: 94))
        XCTAssertFalse(state.isGameOver)
    }

    func testDeadSwipeAtZeroPulseEndsRun() {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 0, column: 0), tone: .cyan)
        ])
        state.pulse = 1

        _ = GameEngine.clearCompletedLines(in: &state)

        XCTAssertEqual(state.pulse, 0)
        XCTAssertTrue(state.isGameOver)
    }

    func testClearRestoresPulse() {
        var state = fixture(blocks: (0..<8).map {
            GameBlock(position: GridPoint(row: 3, column: $0), tone: .cyan)
        })
        state.pulse = 50

        _ = GameEngine.clearCompletedLines(in: &state)

        XCTAssertEqual(state.pulse, 57)
        XCTAssertEqual(state.lastPulseEvent, PulseEvent(kind: .clear, delta: 7, value: 57))
    }

    func testChainIncrementsOnConsecutiveClearsAndResetsImmediatelyOnDeadSwipe() {
        var state = fixture(blocks: (0..<8).map {
            GameBlock(position: GridPoint(row: 0, column: $0), tone: .cyan)
        })

        _ = GameEngine.clearCompletedLines(in: &state)
        XCTAssertEqual(state.chain, 1)

        GameEngine.removeClearedBlocks(in: &state)
        state.blocks = (0..<8).map { GameBlock(position: GridPoint(row: 1, column: $0), tone: .pink) }
        _ = GameEngine.clearCompletedLines(in: &state)
        XCTAssertEqual(state.chain, 2)

        GameEngine.removeClearedBlocks(in: &state)
        state.blocks = [GameBlock(position: GridPoint(row: 2, column: 0), tone: .lime)]
        _ = GameEngine.clearCompletedLines(in: &state)
        XCTAssertEqual(state.chain, 0, "chain must reset on the very first move that does not clear")
    }

    func testSpawnUsesOnlyEmptyCells() {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 0, column: 0), tone: .cyan)
        ], seed: 12)

        let spawned = GameEngine.spawnBlocks(count: 3, in: &state, allowGameOver: true)

        XCTAssertEqual(spawned.count, 3)
        XCTAssertEqual(Set(state.blocks.map(\.position)).count, state.blocks.count)
        XCTAssertTrue(state.blocks.contains { $0.position == GridPoint(row: 0, column: 0) })
        XCTAssertEqual(state.spawningBlockIDs, spawned)
    }

    func testSpawnAvoidsImmediatelyCompletingLineWhenPossible() {
        var blocks = (0..<7).map {
            GameBlock(position: GridPoint(row: 0, column: $0), tone: .cyan)
        }
        blocks += (0..<7).map {
            GameBlock(position: GridPoint(row: $0, column: 2), tone: .pink)
        }
        var state = fixture(blocks: blocks, seed: 12)

        _ = GameEngine.spawnBlocks(count: 1, in: &state, allowGameOver: true)

        XCTAssertFalse(state.blocks.contains { $0.position == GridPoint(row: 0, column: 7) })
        XCTAssertFalse(state.blocks.contains { $0.position == GridPoint(row: 7, column: 2) })
        XCTAssertTrue(GameEngine.clearCompletedLines(in: &state).lines.isEmpty)
    }

    func testNewGameStartsDenseButWithoutCompletedLines() {
        let state = GameEngine.newGame(seed: 99)

        XCTAssertTrue((22..<28).contains(GameEngine.emptyCells(in: state).count))
        for row in 0..<state.boardSize {
            XCTAssertLessThan(state.blocks.filter { $0.position.row == row }.count, state.boardSize)
        }
        for column in 0..<state.boardSize {
            XCTAssertLessThan(state.blocks.filter { $0.position.column == column }.count, state.boardSize)
        }
    }

    func testNewGameDoesNotAutoClearSeveralLinesOnFirstSwipe() {
        for seed in 90..<110 {
            for direction in SwipeDirection.allCases {
                var state = GameEngine.newGame(seed: UInt64(seed))

                guard GameEngine.startMove(direction, in: &state, now: 0) else {
                    continue
                }

                let outcome = GameEngine.finishActiveMove(in: &state)
                XCTAssertLessThanOrEqual(
                    outcome.clearedLines.count,
                    1,
                    "Seed \(seed) direction \(direction) cleared \(outcome.clearedLines.count) lines on the first swipe"
                )
            }
        }
    }

    func testGameOverWhenThereIsNoRoomForIncomingBlocks() {
        let blocks = (0..<8).flatMap { row in
            (0..<8).compactMap { column in
                row == 7 && column == 7 ? nil : GameBlock(position: GridPoint(row: row, column: column), tone: .cyan)
            }
        }
        var state = fixture(blocks: blocks)

        let spawned = GameEngine.spawnBlocks(count: 2, in: &state, allowGameOver: true)

        XCTAssertTrue(spawned.isEmpty)
        XCTAssertTrue(state.isGameOver)
    }

    func testSwipeThatDoesNotMoveBlocksDoesNotStartMove() {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 0, column: 0), tone: .cyan),
            GameBlock(position: GridPoint(row: 0, column: 1), tone: .pink)
        ])

        XCTAssertFalse(GameEngine.startMove(.left, in: &state, now: 0))
        XCTAssertNil(state.activeMove)
        XCTAssertEqual(state.moves, 0)
    }

    func testValidSwipeIncrementsMoveCount() {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 0, column: 3), tone: .cyan)
        ])

        XCTAssertTrue(GameEngine.startMove(.left, in: &state, now: 0))

        XCTAssertEqual(state.moves, 1)
    }

    func testTierProgressesFromScoreOrMovesWithoutCap() {
        XCTAssertEqual(GameEngine.tier(forScore: 0, moves: 0), 1)
        XCTAssertEqual(GameEngine.tier(forScore: 1_000, moves: 0), 3)
        XCTAssertEqual(GameEngine.tier(forScore: 0, moves: 54), 4)
        XCTAssertEqual(GameEngine.tier(forScore: 12_000, moves: 400), 25)
        XCTAssertEqual(GameEngine.formattedYield(GameEngine.difficultyCoefficient(forScore: 1_200, moves: 30, tally: 12)), "1.87x")
    }

    func testIncomingBlockCountDropsAsXpRises() {
        var rng = SeededGenerator(seed: 4)

        XCTAssertTrue((2...3).contains(GameEngine.incomingBlockCount(forXP: 1.0, rng: &rng)))
        XCTAssertEqual(GameEngine.incomingBlockCount(forXP: 1.25, rng: &rng), 2)
        XCTAssertTrue((1...2).contains(GameEngine.incomingBlockCount(forXP: 1.5, rng: &rng)))
        XCTAssertEqual(GameEngine.incomingBlockCount(forXP: 2.2, rng: &rng), 1)
        XCTAssertEqual(GameEngine.incomingBlockPreview(forXP: 2.2), "1")
        XCTAssertEqual(GameEngine.incomingBlockPreview(forXP: 1.0, emptyCellCount: 3), "1")
        XCTAssertEqual(GameEngine.incomingBlockPreview(forXP: 1.0, emptyCellCount: 20), "2-3")
    }

    func testIncomingBlocksAreCappedWhenBoardIsUnderPressure() {
        var rng = SeededGenerator(seed: 4)

        XCTAssertEqual(GameEngine.incomingBlockCount(forXP: 1.0, emptyCellCount: 3, rng: &rng), 1)
        XCTAssertLessThanOrEqual(GameEngine.incomingBlockCount(forXP: 1.0, emptyCellCount: 8, rng: &rng), 2)
        XCTAssertLessThanOrEqual(GameEngine.incomingBlockCount(forXP: 1.0, emptyCellCount: 20, rng: &rng), 4)
    }

    func testIncomingBlocksRefillSparseBoards() {
        var rng = SeededGenerator(seed: 11)

        XCTAssertEqual(GameEngine.incomingBlockCount(forXP: 2.2, emptyCellCount: 20, rng: &rng), 2)
        XCTAssertEqual(GameEngine.incomingBlockCount(forXP: 2.2, emptyCellCount: 26, rng: &rng), 3)
        XCTAssertEqual(GameEngine.incomingBlockCount(forXP: 2.2, emptyCellCount: 34, rng: &rng), 4)
        XCTAssertEqual(GameEngine.incomingBlockPreview(forXP: 2.2, emptyCellCount: 34), "4")
    }

    func testOverdriveClearsDensestLine() {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 1, column: 0), tone: .cyan),
            GameBlock(position: GridPoint(row: 1, column: 1), tone: .pink),
            GameBlock(position: GridPoint(row: 1, column: 2), tone: .lime),
            GameBlock(position: GridPoint(row: 3, column: 0), tone: .violet)
        ])
        state.surge = 120

        let burst = GameEngine.triggerOverdriveIfReady(in: &state)

        XCTAssertEqual(burst, OverdriveSummary(clearedCount: 3, line: .row(1), scoreDelta: 225))
        XCTAssertEqual(state.surge, 30)
        XCTAssertEqual(state.blocks.count, 1)
        XCTAssertEqual(state.blocks.first?.position, GridPoint(row: 3, column: 0))
        XCTAssertEqual(state.score, 225)
    }

    func testRecordFinishedRunKeepsLeaderboardSorted() {
        var state = fixture(blocks: [], seed: 7)
        state.isGameOver = true
        state.score = 200
        state.moves = 12
        state.leaderboard = [
            LeaderboardEntry(score: 100, moves: 8, blocksLeft: 20),
            LeaderboardEntry(score: 250, moves: 18, blocksLeft: 30)
        ]

        GameEngine.recordFinishedRun(in: &state)

        XCTAssertEqual(state.leaderboard.map(\.score), [250, 200, 100])
        XCTAssertEqual(state.bestScore, 250)
    }

    func testStateRoundTripsThroughCodable() throws {
        var state = fixture(blocks: [
            GameBlock(position: GridPoint(row: 1, column: 2), tone: .violet)
        ], seed: 44)
        XCTAssertTrue(GameEngine.startMove(.right, in: &state, now: 123))

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.activeMove?.startedAt, 123)
    }

    private func fixture(blocks: [GameBlock], seed: UInt64 = 1) -> GameState {
        GameState(boardSize: 8, blocks: blocks, rng: SeededGenerator(seed: seed))
    }
}
