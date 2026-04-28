import SwiftUI

@main
struct ShiftBlastApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        viewModel.persistForInterruption()
                    } else {
                        viewModel.resumeInterruptedMoveIfNeeded()
                    }
                }
        }
    }
}
