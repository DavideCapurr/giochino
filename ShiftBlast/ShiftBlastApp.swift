import SwiftUI

@main
struct ShiftBlastApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = GameViewModel()
    @StateObject private var subscriptionStore = SubscriptionStore()
    @StateObject private var gameCenter = GameCenterService()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environmentObject(subscriptionStore)
                .environmentObject(gameCenter)
                .task {
                    await subscriptionStore.configure()
                    // Sync explicitly after entitlements resolve: onChange only
                    // fires on a transition, so this guarantees the agent watcher
                    // starts for a user who is already premium at launch.
                    viewModel.isAgentEnabled = subscriptionStore.isPremium
                    gameCenter.authenticate()
                    viewModel.bindGameCenter(gameCenter)
                }
                .onChange(of: subscriptionStore.isPremium) { _, premium in
                    viewModel.isAgentEnabled = premium
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        viewModel.persistForInterruption()
                    } else if !viewModel.isAgentPaused {
                        viewModel.resumeInterruptedMoveIfNeeded()
                        Task { await gameCenter.refreshAll() }
                    }
                }
        }
    }
}
