import SwiftUI
import UserNotifications

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
                .tint(Color.shiftCyan)
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
                    } else {
                        // Clear any lingering notification badge (e.g. a friend-overtake alert)
                        // now that the player is back in the app.
                        Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
                        if !viewModel.isAgentPaused {
                            viewModel.resumeInterruptedMoveIfNeeded()
                            Task { await gameCenter.refreshAll() }
                        }
                    }
                }
        }
    }
}
