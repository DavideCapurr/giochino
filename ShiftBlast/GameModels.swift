import Foundation

struct GridPoint: Codable, Hashable, Equatable {
    var row: Int
    var column: Int
}

enum SwipeDirection: String, Codable, CaseIterable {
    case up
    case down
    case left
    case right
}

enum BlockTone: String, Codable, CaseIterable {
    case cyan
    case pink
    case lime
    case yellow
    case orange
    case violet
}

struct GameBlock: Identifiable, Codable, Hashable, Equatable {
    var id: UUID
    var position: GridPoint
    var tone: BlockTone

    init(id: UUID = UUID(), position: GridPoint, tone: BlockTone) {
        self.id = id
        self.position = position
        self.tone = tone
    }
}

struct SlideStep: Codable, Hashable, Equatable {
    var blockID: UUID
    var from: GridPoint
    var to: GridPoint
}

enum ClearedLine: Codable, Hashable, Equatable {
    case row(Int)
    case column(Int)
}

struct ActiveMove: Codable, Hashable, Equatable {
    var direction: SwipeDirection
    var steps: [SlideStep]
    var startedAt: TimeInterval
    var duration: TimeInterval
    var savedProgress: Double?
}

struct GameState: Codable, Equatable {
    var boardSize: Int
    var blocks: [GameBlock]
    var score: Int
    var bestScore: Int
    var rng: SeededGenerator
    var isGameOver: Bool
    var activeMove: ActiveMove?
    var highlightedLines: [ClearedLine]
    var clearingBlockIDs: Set<UUID>

    init(
        boardSize: Int = 8,
        blocks: [GameBlock] = [],
        score: Int = 0,
        bestScore: Int = 0,
        rng: SeededGenerator = SeededGenerator(),
        isGameOver: Bool = false,
        activeMove: ActiveMove? = nil,
        highlightedLines: [ClearedLine] = [],
        clearingBlockIDs: Set<UUID> = []
    ) {
        self.boardSize = boardSize
        self.blocks = blocks
        self.score = score
        self.bestScore = bestScore
        self.rng = rng
        self.isGameOver = isGameOver
        self.activeMove = activeMove
        self.highlightedLines = highlightedLines
        self.clearingBlockIDs = clearingBlockIDs
    }
}
