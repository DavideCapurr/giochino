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
    var chain: Int
    var surgeGained: Int
    var yield: Double

    init(lineCount: Int, scoreDelta: Int, bonus: Int, chain: Int, surgeGained: Int, yield: Double = 1) {
        self.lineCount = lineCount
        self.scoreDelta = scoreDelta
        self.bonus = bonus
        self.chain = chain
        self.surgeGained = surgeGained
        self.yield = yield
    }

    enum CodingKeys: String, CodingKey {
        case lineCount
        case scoreDelta
        case bonus
        case chain
        case surgeGained
        case yield
        // legacy
        case streak
        case flowGained
        case pointMultiplier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lineCount = try container.decodeIfPresent(Int.self, forKey: .lineCount) ?? 0
        scoreDelta = try container.decodeIfPresent(Int.self, forKey: .scoreDelta) ?? 0
        bonus = try container.decodeIfPresent(Int.self, forKey: .bonus) ?? 0
        chain = try container.decodeIfPresent(Int.self, forKey: .chain)
            ?? container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        surgeGained = try container.decodeIfPresent(Int.self, forKey: .surgeGained)
            ?? container.decodeIfPresent(Int.self, forKey: .flowGained) ?? 0
        yield = try container.decodeIfPresent(Double.self, forKey: .yield)
            ?? container.decodeIfPresent(Double.self, forKey: .pointMultiplier) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lineCount, forKey: .lineCount)
        try container.encode(scoreDelta, forKey: .scoreDelta)
        try container.encode(bonus, forKey: .bonus)
        try container.encode(chain, forKey: .chain)
        try container.encode(surgeGained, forKey: .surgeGained)
        try container.encode(yield, forKey: .yield)
    }
}

struct OverdriveSummary: Codable, Hashable, Equatable {
    var clearedCount: Int
    var line: ClearedLine
    var scoreDelta: Int
}

struct PulseEvent: Codable, Hashable, Equatable {
    enum Kind: String, Codable {
        case deadSwipe
        case clear

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw {
            case "deadSwipe", "emptySwipe": self = .deadSwipe
            case "clear": self = .clear
            default: self = .deadSwipe
            }
        }
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
    var tally: Int
    var tier: Int
    var lastClear: ClearSummary?
    var lastOverdrive: OverdriveSummary?
    var lastPulseEvent: PulseEvent?
    var pulse: Int
    var surge: Int
    var chain: Int
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
        tally: Int = 0,
        tier: Int = 1,
        lastClear: ClearSummary? = nil,
        lastOverdrive: OverdriveSummary? = nil,
        lastPulseEvent: PulseEvent? = nil,
        pulse: Int = 100,
        surge: Int = 0,
        chain: Int = 0,
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
        self.tally = tally
        self.tier = tier
        self.lastClear = lastClear
        self.lastOverdrive = lastOverdrive
        self.lastPulseEvent = lastPulseEvent
        self.pulse = pulse
        self.surge = surge
        self.chain = chain
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
        case tally
        case tier
        case lastClear
        case lastOverdrive
        case lastPulseEvent
        case pulse
        case surge
        case chain
        case leaderboard
        case rng
        case isGameOver
        case activeMove
        case highlightedLines
        case clearingBlockIDs
        case spawningBlockIDs
        // legacy
        case victories
        case level
        case lastCoreBurst
        case lastSignalEvent
        case signal
        case flowEnergy
        case streak
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boardSize = try container.decodeIfPresent(Int.self, forKey: .boardSize) ?? 8
        blocks = try container.decodeIfPresent([GameBlock].self, forKey: .blocks) ?? []
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        bestScore = try container.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        moves = try container.decodeIfPresent(Int.self, forKey: .moves) ?? 0
        tally = try container.decodeIfPresent(Int.self, forKey: .tally)
            ?? container.decodeIfPresent(Int.self, forKey: .victories) ?? 0
        tier = try container.decodeIfPresent(Int.self, forKey: .tier)
            ?? container.decodeIfPresent(Int.self, forKey: .level) ?? 1
        lastClear = try container.decodeIfPresent(ClearSummary.self, forKey: .lastClear)
        lastOverdrive = try container.decodeIfPresent(OverdriveSummary.self, forKey: .lastOverdrive)
            ?? container.decodeIfPresent(OverdriveSummary.self, forKey: .lastCoreBurst)
        lastPulseEvent = try container.decodeIfPresent(PulseEvent.self, forKey: .lastPulseEvent)
            ?? container.decodeIfPresent(PulseEvent.self, forKey: .lastSignalEvent)
        pulse = try container.decodeIfPresent(Int.self, forKey: .pulse)
            ?? container.decodeIfPresent(Int.self, forKey: .signal) ?? 100
        surge = try container.decodeIfPresent(Int.self, forKey: .surge)
            ?? container.decodeIfPresent(Int.self, forKey: .flowEnergy) ?? 0
        chain = try container.decodeIfPresent(Int.self, forKey: .chain)
            ?? container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        leaderboard = try container.decodeIfPresent([LeaderboardEntry].self, forKey: .leaderboard) ?? []
        rng = try container.decodeIfPresent(SeededGenerator.self, forKey: .rng) ?? SeededGenerator()
        isGameOver = try container.decodeIfPresent(Bool.self, forKey: .isGameOver) ?? false
        activeMove = try container.decodeIfPresent(ActiveMove.self, forKey: .activeMove)
        highlightedLines = try container.decodeIfPresent([ClearedLine].self, forKey: .highlightedLines) ?? []
        clearingBlockIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .clearingBlockIDs) ?? []
        spawningBlockIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .spawningBlockIDs) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(boardSize, forKey: .boardSize)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(score, forKey: .score)
        try container.encode(bestScore, forKey: .bestScore)
        try container.encode(moves, forKey: .moves)
        try container.encode(tally, forKey: .tally)
        try container.encode(tier, forKey: .tier)
        try container.encodeIfPresent(lastClear, forKey: .lastClear)
        try container.encodeIfPresent(lastOverdrive, forKey: .lastOverdrive)
        try container.encodeIfPresent(lastPulseEvent, forKey: .lastPulseEvent)
        try container.encode(pulse, forKey: .pulse)
        try container.encode(surge, forKey: .surge)
        try container.encode(chain, forKey: .chain)
        try container.encode(leaderboard, forKey: .leaderboard)
        try container.encode(rng, forKey: .rng)
        try container.encode(isGameOver, forKey: .isGameOver)
        try container.encodeIfPresent(activeMove, forKey: .activeMove)
        try container.encode(highlightedLines, forKey: .highlightedLines)
        try container.encode(clearingBlockIDs, forKey: .clearingBlockIDs)
        try container.encode(spawningBlockIDs, forKey: .spawningBlockIDs)
    }
}
