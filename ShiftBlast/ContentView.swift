import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.015, green: 0.016, blue: 0.022), Color(red: 0.035, green: 0.038, blue: 0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 22) {
                    HUDView(score: viewModel.state.score, bestScore: viewModel.state.bestScore)
                        .padding(.top, proxy.safeAreaInsets.top + 12)

                    BoardView(viewModel: viewModel)
                        .frame(width: min(proxy.size.width - 28, proxy.size.height - 180))
                        .aspectRatio(1, contentMode: .fit)

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 14)

                if viewModel.state.isGameOver {
                    GameOverView(score: viewModel.state.score, restart: viewModel.restart)
                }
            }
            .contentShape(Rectangle())
            .gesture(swipeGesture)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                guard max(abs(width), abs(height)) > 18 else { return }

                if abs(width) > abs(height) {
                    viewModel.swipe(width > 0 ? .right : .left)
                } else {
                    viewModel.swipe(height > 0 ? .down : .up)
                }
            }
    }
}

private struct HUDView: View {
    let score: Int
    let bestScore: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHIFT BLAST")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                Text("SCORE \(score)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("BEST")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                Text("\(bestScore)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
                    .monospacedDigit()
            }
        }
    }
}

private struct GameOverView: View {
    let score: Int
    let restart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("GAME OVER")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(score)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(Color.shiftCyan)
                    .monospacedDigit()
                Button(action: restart) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 58, height: 58)
                        .foregroundStyle(.black)
                        .background(Color.white, in: Circle())
                }
                .accessibilityLabel("Restart")
            }
            .padding(28)
        }
    }
}
