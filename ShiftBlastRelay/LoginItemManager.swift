import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` to expose a Login Item toggle. App Store-safe:
/// the user sees the entry in System Settings → Login Items and can revoke it
/// at any time.
@MainActor
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            // Surface failure silently — UI re-reads `isEnabled` to reflect state.
        }
    }
}
