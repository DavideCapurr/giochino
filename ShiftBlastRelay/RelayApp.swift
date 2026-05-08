import SwiftUI

@main
struct ShiftBlastRelayApp: App {
    @StateObject private var coordinator = RelayCoordinator()

    var body: some Scene {
        MenuBarExtra("ShiftBlast Relay", systemImage: "bolt.circle.fill") {
            RelayMenuView(coordinator: coordinator)
                .onAppear {
                    coordinator.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
