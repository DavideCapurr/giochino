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
                    LineHighlights(lines: viewModel.state.highlightedLines, size: size, gap: gap, cell: cell)

                    ForEach(viewModel.state.blocks) { block in
                        BlockView(block: block)
                            .frame(width: cell, height: cell)
                            .opacity(viewModel.state.clearingBlockIDs.contains(block.id) ? 0 : 1)
                            .scaleEffect(viewModel.state.clearingBlockIDs.contains(block.id) ? 1.45 : 1)
                            .position(position(for: block, now: timeline.date, gap: gap, cell: cell))
                            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: block.position)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.width)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.11), lineWidth: 1)
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
}

private struct BoardGrid: View {
    let size: Int
    let gap: CGFloat
    let cell: CGFloat

    var body: some View {
        ForEach(0..<size, id: \.self) { row in
            ForEach(0..<size, id: \.self) { column in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.035))
                    .frame(width: cell, height: cell)
                    .position(
                        x: gap + cell / 2 + CGFloat(column) * (cell + gap),
                        y: gap + cell / 2 + CGFloat(row) * (cell + gap)
                    )
            }
        }
    }
}

private struct LineHighlights: View {
    let lines: [ClearedLine]
    let size: Int
    let gap: CGFloat
    let cell: CGFloat

    var body: some View {
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .shadow(color: .white.opacity(0.8), radius: 18)
                .frame(width: width(for: line), height: height(for: line))
                .position(position(for: line))
                .transition(.opacity)
        }
    }

    private func width(for line: ClearedLine) -> CGFloat {
        switch line {
        case .row:
            return CGFloat(size) * cell + CGFloat(size - 1) * gap
        case .column:
            return cell
        }
    }

    private func height(for line: ClearedLine) -> CGFloat {
        switch line {
        case .row:
            return cell
        case .column:
            return CGFloat(size) * cell + CGFloat(size - 1) * gap
        }
    }

    private func position(for line: ClearedLine) -> CGPoint {
        switch line {
        case .row(let row):
            return CGPoint(
                x: gap + width(for: line) / 2,
                y: gap + cell / 2 + CGFloat(row) * (cell + gap)
            )
        case .column(let column):
            return CGPoint(
                x: gap + cell / 2 + CGFloat(column) * (cell + gap),
                y: gap + height(for: line) / 2
            )
        }
    }
}

private struct BlockView: View {
    let block: GameBlock

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(block.tone.color)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: block.tone.color.opacity(0.72), radius: 12)
            .shadow(color: block.tone.color.opacity(0.38), radius: 26)
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
