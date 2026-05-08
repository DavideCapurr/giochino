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
                    await gameCenter.requestNotificationPermissionIfNeeded()
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
