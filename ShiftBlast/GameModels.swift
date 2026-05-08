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

struct LeaderboardEntry: Identifiable, Codable, Hashable, Equatable {
    var id: UUID
    var score: Int
    var moves: Int
    var blocksLeft: Int
    var playedAt: Date

    init(id: UUID = UUID(), score: Int, moves: Int, blocksLeft: Int, playedAt: Date = Date()) {
        self.id = id
        self.score = score
        self.moves = moves
        self.blocksLeft = blocksLeft
        self.playedAt = playedAt
    }
}

struct ClearSummary: Codable, Hashable, Equatable {
    var lineCount: Int
    var scoreDelta: Int
    var bonus: Int
    var streak: Int
    var flowGained: Int
    var pointMultiplier: Double

    init(lineCount: Int, scoreDelta: Int, bonus: Int, streak: Int, flowGained: Int, pointMultiplier: Double = 1) {
        self.lineCount = lineCount
        self.scoreDelta = scoreDelta
        self.bonus = bonus
        self.streak = streak
        self.flowGained = flowGained
        self.pointMultiplier = pointMultiplier
    }

    enum CodingKeys: String, CodingKey {
        case lineCount
        case scoreDelta
        case bonus
        case streak
        case flowGained
        case pointMultiplier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineCount = try container.decodeIfPresent(Int.self, forKey: .lineCount) ?? 0
        scoreDelta = try container.decodeIfPresent(Int.self, forKey: .scoreDelta) ?? 0
        bonus = try container.decodeIfPresent(Int.self, forKey: .bonus) ?? 0
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        flowGained = try container.decodeIfPresent(Int.self, forKey: .flowGained) ?? 0
        pointMultiplier = try container.decodeIfPresent(Double.self, forKey: .pointMultiplier) ?? 1
    }
}

struct CoreBurstSummary: Codable, Hashable, Equatable {
    var clearedCount: Int
    var line: ClearedLine
    var scoreDelta: Int
}

struct SignalEvent: Codable, Hashable, Equatable {
    enum Kind: String, Codable {
        case emptySwipe
        case clear
    }

    var kind: Kind
    var delta: Int
    var value: Int
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
    var moves: Int
    var victories: Int
    var level: Int
    var lastClear: ClearSummary?
    var lastCoreBurst: CoreBurstSummary?
    var lastSignalEvent: SignalEvent?
    var signal: Int
    var flowEnergy: Int
    var streak: Int
    var streakMovesRemaining: Int
    var leaderboard: [LeaderboardEntry]
    var rng: SeededGenerator
    var isGameOver: Bool
    var activeMove: ActiveMove?
    var highlightedLines: [ClearedLine]
    var clearingBlockIDs: Set<UUID>
    var spawningBlockIDs: Set<UUID>

    init(
        boardSize: Int = 8,
        blocks: [GameBlock] = [],
        score: Int = 0,
        bestScore: Int = 0,
        moves: Int = 0,
        victories: Int = 0,
        level: Int = 1,
        lastClear: ClearSummary? = nil,
        lastCoreBurst: CoreBurstSummary? = nil,
        lastSignalEvent: SignalEvent? = nil,
        signal: Int = 100,
        flowEnergy: Int = 0,
        streak: Int = 0,
        streakMovesRemaining: Int = 0,
        leaderboard: [LeaderboardEntry] = [],
        rng: SeededGenerator = SeededGenerator(),
        isGameOver: Bool = false,
        activeMove: ActiveMove? = nil,
        highlightedLines: [ClearedLine] = [],
        clearingBlockIDs: Set<UUID> = [],
        spawningBlockIDs: Set<UUID> = []
    ) {
        self.boardSize = boardSize
        self.blocks = blocks
        self.score = score
        self.bestScore = bestScore
        self.moves = moves
        self.victories = victories
        self.level = level
        self.lastClear = lastClear
        self.lastCoreBurst = lastCoreBurst
        self.lastSignalEvent = lastSignalEvent
        self.signal = signal
        self.flowEnergy = flowEnergy
        self.streak = streak
        self.streakMovesRemaining = streakMovesRemaining
        self.leaderboard = leaderboard
        self.rng = rng
        self.isGameOver = isGameOver
        self.activeMove = activeMove
        self.highlightedLines = highlightedLines
        self.clearingBlockIDs = clearingBlockIDs
        self.spawningBlockIDs = spawningBlockIDs
    }

    enum CodingKeys: String, CodingKey {
        case boardSize
        case blocks
        case score
        case bestScore
        case moves
        case victories
        case level
        case lastClear
        case lastCoreBurst
        case lastSignalEvent
        case signal
        case flowEnergy
        case streak
        case streakMovesRemaining
        case leaderboard
        case rng
        case isGameOver
        case activeMove
        case highlightedLines
        case clearingBlockIDs
        case spawningBlockIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boardSize = try container.decodeIfPresent(Int.self, forKey: .boardSize) ?? 8
        blocks = try container.decodeIfPresent([GameBlock].self, forKey: .blocks) ?? []
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        moves = try container.decodeIfPresent(Int.self, forKey: .moves) ?? 0
        victories = try container.decodeIfPresent(Int.self, forKey: .victories) ?? 0
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        lastClear = try container.decodeIfPresent(ClearSummary.self, forKey: .lastClear)
        lastCoreBurst = try container.decodeIfPresent(CoreBurstSummary.self, forKey: .lastCoreBurst)
        lastSignalEvent = try container.decodeIfPresent(SignalEvent.self, forKey: .lastSignalEvent)
        signal = try container.decodeIfPresent(Int.self, forKey: .signal) ?? 100
        flowEnergy = try container.decodeIfPresent(Int.self, forKey: .flowEnergy) ?? 0
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        streakMovesRemaining = try container.decodeIfPresent(Int.self, forKey: .streakMovesRemaining) ?? 0
        leaderboard = try container.decodeIfPresent([LeaderboardEntry].self, forKey: .leaderboard) ?? []
        rng = try container.decodeIfPresent(SeededGenerator.self, forKey: .rng) ?? SeededGenerator()
        isGameOver = try container.decodeIfPresent(Bool.self, forKey: .isGameOver) ?? false
        activeMove = try container.decodeIfPresent(ActiveMove.self, forKey: .activeMove)
        highlightedLines = try container.decodeIfPresent([ClearedLine].self, forKey: .highlightedLines) ?? []
        clearingBlockIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .clearingBlockIDs) ?? []
        spawningBlockIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .spawningBlockIDs) ?? []
    }
}
