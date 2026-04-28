import SwiftUI

struct BoardView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let size = viewModel.state.boardSize
                let gap: CGFloat = 6
                let cell = (proxy.size.width - gap * CGFloat(size + 1)) / CGFloat(size)

                ZStack(alignment: .topLeading) {
                    BoardGrid(size: size, gap: gap, cell: cell)

                    ForEach(viewModel.state.blocks) { block in
                        let isSpawning = viewModel.state.spawningBlockIDs.contains(block.id)
                        let isClearing = viewModel.state.clearingBlockIDs.contains(block.id)
                        BlockView(block: block, isClearing: isClearing, isSpawning: isSpawning, now: timeline.date)
                            .frame(width: cell, height: cell)
                            .opacity(opacity(forClearing: isClearing, spawning: isSpawning, now: timeline.date))
                            .scaleEffect(scale(forClearing: isClearing, spawning: isSpawning, now: timeline.date))
                            .position(position(for: block, now: timeline.date, gap: gap, cell: cell))
                            .animation(.spring(response: 0.24, dampingFraction: 0.8), value: block.position)
                            .animation(.easeOut(duration: 0.2), value: isClearing)
                            .animation(.spring(response: 0.32, dampingFraction: 0.68), value: isSpawning)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.width)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                        )
                )
            }
        }
    }

    private func position(for block: GameBlock, now: Date, gap: CGFloat, cell: CGFloat) -> CGPoint {
        let display = viewModel.displayPosition(for: block, now: now)
        let column = display?.x ?? CGFloat(block.position.column)
        let row = display?.y ?? CGFloat(block.position.row)
        return CGPoint(
            x: gap + cell / 2 + column * (cell + gap),
            y: gap + cell / 2 + row * (cell + gap)
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

    var body: some View {
        ForEach(0..<size, id: \.self) { row in
            ForEach(0..<size, id: \.self) { column in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.028))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.035), lineWidth: 1)
                    )
                    .frame(width: cell, height: cell)
                    .position(
                        x: gap + cell / 2 + CGFloat(column) * (cell + gap),
                        y: gap + cell / 2 + CGFloat(row) * (cell + gap)
                    )
            }
        }
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

        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        baseColor.opacity(isSpawning ? 0.92 : 1),
                        baseColor.opacity(isClearing ? 0.72 : 0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.white.opacity(isClearing ? 0.9 : 0.34), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white.opacity(isClearing ? 0.48 : 0.16))
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
            .shadow(color: baseColor.opacity(isClearing ? 0.95 : 0.46 + spawnPulse * 0.16), radius: isClearing ? 20 : 10)
            .shadow(color: baseColor.opacity(isClearing ? 0.6 : 0.2), radius: isClearing ? 34 : 20)
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
    static let shiftCyan = Color(red: 0.15, green: 0.94, blue: 1.0)
    static let shiftPink = Color(red: 1.0, green: 0.18, blue: 0.62)
    static let shiftLime = Color(red: 0.47, green: 1.0, blue: 0.25)
    static let shiftYellow = Color(red: 1.0, green: 0.9, blue: 0.2)
    static let shiftOrange = Color(red: 1.0, green: 0.45, blue: 0.16)
    static let shiftViolet = Color(red: 0.64, green: 0.38, blue: 1.0)
}
