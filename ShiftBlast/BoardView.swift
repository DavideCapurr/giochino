import SwiftUI

struct BoardView: View {
    @ObservedObject var viewModel: GameViewModel

    private let gap: CGFloat = 3
    private let boardPadding: CGFloat = 10

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let size = viewModel.state.boardSize
                let totalGap: CGFloat = gap * CGFloat(size - 1)
                let cell: CGFloat = (proxy.size.width - 2 * boardPadding - totalGap) / CGFloat(size)

                ZStack(alignment: .topLeading) {
                    BoardGrid(size: size, gap: gap, cell: cell, padding: boardPadding)

                    ForEach(viewModel.state.blocks) { block in
                        let isSpawning = viewModel.state.spawningBlockIDs.contains(block.id)
                        let isClearing = viewModel.state.clearingBlockIDs.contains(block.id)
                        BlockView(block: block, isClearing: isClearing, isSpawning: isSpawning, now: timeline.date)
                            .frame(width: cell, height: cell)
                            .opacity(opacity(forClearing: isClearing, spawning: isSpawning, now: timeline.date))
                            .scaleEffect(scale(forClearing: isClearing, spawning: isSpawning, now: timeline.date))
                            .position(position(for: block, now: timeline.date, gap: gap, cell: cell, padding: boardPadding))
                            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: block.position)
                            .animation(.easeOut(duration: 0.18), value: isClearing)
                            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSpawning)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.width)
                .background(boardBackground)
            }
        }
    }

    @ViewBuilder private var boardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape
            .fill(Color.nightBoardBg.opacity(0.6))
            .overlay(shape.stroke(Color.nightBoardBorder.opacity(0.5), lineWidth: 1))
            .shadow(color: Color.nightBoardBorder.opacity(0.15), radius: 1)
            .shadow(color: Color(red: 0.03, green: 0.04, blue: 0.14).opacity(0.8), radius: 60, x: 0, y: 20)
    }

    private func position(for block: GameBlock, now: Date, gap: CGFloat, cell: CGFloat, padding: CGFloat) -> CGPoint {
        let display = viewModel.displayPosition(for: block, now: now)
        let column = display?.x ?? CGFloat(block.position.column)
        let row = display?.y ?? CGFloat(block.position.row)
        return CGPoint(
            x: padding + cell / 2 + column * (cell + gap),
            y: padding + cell / 2 + row * (cell + gap)
        )
    }

    private func scale(forClearing isClearing: Bool, spawning isSpawning: Bool, now: Date) -> CGFloat {
        if isClearing { return 0.35 }
        guard isSpawning else { return 1 }
        let pulse = CGFloat((sin(now.timeIntervalSinceReferenceDate * 16) + 1) / 2)
        return 0.92 + pulse * 0.08
    }

    private func opacity(forClearing isClearing: Bool, spawning isSpawning: Bool, now: Date) -> Double {
        if isClearing { return 0 }
        guard isSpawning else { return 1 }
        let pulse = (sin(now.timeIntervalSinceReferenceDate * 16) + 1) / 2
        return 0.82 + pulse * 0.18
    }
}

private struct BoardGrid: View {
    let size: Int
    let gap: CGFloat
    let cell: CGFloat
    let padding: CGFloat

    var body: some View {
        ForEach(0..<size, id: \.self) { row in
            ForEach(0..<size, id: \.self) { column in
                gridCell(row: row, column: column)
            }
        }
    }

    private func gridCell(row: Int, column: Int) -> some View {
        let x: CGFloat = padding + cell / 2 + CGFloat(column) * (cell + gap)
        let y: CGFloat = padding + cell / 2 + CGFloat(row) * (cell + gap)
        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.nightCellBg.opacity(0.8))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.nightCellBorder.opacity(0.4), lineWidth: 1)
            )
            .frame(width: cell, height: cell)
            .position(x: x, y: y)
    }
}

private struct BlockView: View {
    let block: GameBlock
    let isClearing: Bool
    let isSpawning: Bool
    let now: Date

    var body: some View {
        let baseColor = isClearing ? Color.white : block.tone.color
        let spawnPulse = CGFloat((sin(now.timeIntervalSinceReferenceDate * 16) + 1) / 2)
        let primaryGlow = isSpawning ? 0.7 + spawnPulse * 0.25 : 0.18
        let secondaryGlow = isSpawning ? 0.45 : 0.08

        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        baseColor.opacity(isSpawning ? 0.96 : 1),
                        baseColor.opacity(isClearing ? 0.85 : 0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(baseColor.opacity(isClearing ? 0.95 : 0.7), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white.opacity(isClearing ? 0.5 : 0.2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(2)
            }
            .shadow(color: baseColor.opacity(primaryGlow), radius: isSpawning ? 16 : 4)
            .shadow(color: baseColor.opacity(secondaryGlow), radius: isSpawning ? 30 : 9)
    }
}

extension BlockTone {
    var color: Color {
        switch self {
        case .cyan: return .shiftCyan
        case .pink: return .shiftPink
        case .lime: return .shiftLime
        case .yellow: return .shiftYellow
        case .orange: return .shiftOrange
        case .violet: return .shiftViolet
        }
    }
}

extension Color {
    static let shiftCyan = Color(red: 0.0, green: 0.97, blue: 1.0)
    static let shiftPink = Color(red: 1.0, green: 0.08, blue: 0.58)
    static let shiftLime = Color(red: 0.4, green: 1.0, blue: 0.15)
    static let shiftYellow = Color(red: 1.0, green: 0.96, blue: 0.1)
    static let shiftOrange = Color(red: 1.0, green: 0.5, blue: 0.08)
    static let shiftViolet = Color(red: 0.6, green: 0.28, blue: 1.0)

    // Board grid — oklch(0.1 0.04 260) dark indigo
    static let nightBoardBg     = Color(red: 0.06, green: 0.07, blue: 0.11)
    // Board border — oklch(0.25 0.08 270)
    static let nightBoardBorder = Color(red: 0.15, green: 0.16, blue: 0.26)
    // Cell bg — oklch(0.13 0.04 260)
    static let nightCellBg      = Color(red: 0.08, green: 0.08, blue: 0.14)
    // Cell border — oklch(0.2 0.05 260)
    static let nightCellBorder  = Color(red: 0.12, green: 0.12, blue: 0.19)
}
