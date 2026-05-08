import SwiftUI

@main
struct ShiftBlastApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = GameViewModel()
    @StateObject private var subscriptionStore = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environmentObject(subscriptionStore)
                .task {
                    await subscriptionStore.configure()
                }
                .onChange(of: subscriptionStore.isPremium) { _, premium in
                    viewModel.isAgentEnabled = premium
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        viewModel.persistForInterruption()
                    } else if !viewModel.isAgentPaused {
                        viewModel.resumeInterruptedMoveIfNeeded()
                    }
                }
        }
    }
}
