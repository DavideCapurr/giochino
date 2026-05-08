import Foundation
import AppTrackingTransparency

enum TrackingAuthorization {
    static func requestIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    static var isResolved: Bool {
        ATTrackingManager.trackingAuthorizationStatus != .notDetermined
    }
}
