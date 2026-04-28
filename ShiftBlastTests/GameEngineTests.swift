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
        XCTAssertEqual(result.scoreDelta, 100)
        XCTAssertEqual(state.clearingBlockIDs.count, 8)
        GameEngine.removeClearedBlocks(in: &state)
        XCTAssertTrue(state.blocks.isEmpty)
        XCTAssertEqual(state.score, 100)
    }

    func testClearMultipleLinesAddsComboBonus() {
        var blocks = (0..<8).map { GameBlock(position: GridPoint(row: 0, column: $0), tone: .cyan) }
        blocks += (1..<8).map { GameBlock(position: GridPoint(row: $0, column: 0), tone: .pink) }
        var state = fixture(blocks: blocks)

        let result = GameEngine.clearCompletedLines(in: &state)

        XCTAssertEqual(Set(result.lines), [.row(0), .column(0)])
        XCTAssertEqual(result.scoreDelta, 250)
        GameEngine.removeClearedBlocks(in: &state)
        XCTAssertEqual(state.score, 250)
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
