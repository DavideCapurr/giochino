import Foundation
import GameKit
import OSLog
import SwiftUI
import UIKit

private let log = Logger(subsystem: "com.davide.shiftblast", category: "GameCenter")

enum GameCenterAuthState: Equatable {
    case idle
    case authenticating
    case authenticated
    case unavailable(String)
}

struct GlobalLeaderboardEntry: Identifiable, Hashable {
    let id: String
    let rank: Int
    let displayName: String
    let score: Int
    let isLocalPlayer: Bool
}

@MainActor
final class GameCenterService: ObservableObject {
    static let leaderboardID = "shiftblast.score.classic"

    @Published private(set) var authState: GameCenterAuthState = .idle
    @Published private(set) var personalBest: Int?
    @Published private(set) var personalRank: Int?
    @Published private(set) var globalTop: [GlobalLeaderboardEntry] = []
    @Published private(set) var lastError: String?
    @Published var isLoadingGlobal = false

    private var pendingSubmissions: [Int] = []

    func authenticate(force: Bool = false) {
        if !force {
            guard authState != .authenticated, authState != .authenticating else { return }
        }
        authState = .authenticating

        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    self.present(viewController)
                    return
                }
                if let error {
                    self.authState = .unavailable(Self.friendlyMessage(for: error))
                    self.lastError = error.localizedDescription
                    log.error("GameKit auth failed: \(error.localizedDescription)")
                    return
                }
                if GKLocalPlayer.local.isAuthenticated {
                    self.authState = .authenticated
                    self.lastError = nil
                    await self.flushPendingSubmissions()
                    await self.refreshAll()
                } else {
                    self.authState = .unavailable("Sign in to Game Center in iOS Settings")
                }
            }
        }
    }

    func retryAuthentication() {
        authenticate(force: true)
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        let lowered = nsError.localizedDescription.lowercased()
        if lowered.contains("not been authenticated") || lowered.contains("not authenticated") {
            return "Sign in to Game Center in iOS Settings"
        }
        if lowered.contains("network") || lowered.contains("internet") || lowered.contains("offline") {
            return "No connection to Game Center"
        }
        if lowered.contains("cancel") {
            return "Sign-in cancelled"
        }
        return nsError.localizedDescription
    }

    func submit(score: Int) async {
        guard score > 0 else { return }
        guard authState == .authenticated, GKLocalPlayer.local.isAuthenticated else {
            pendingSubmissions.append(score)
            return
        }

        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [Self.leaderboardID]
            )
            await refreshAll()
        } catch {
            lastError = error.localizedDescription
            log.error("GameKit submit failed: \(error.localizedDescription)")
            pendingSubmissions.append(score)
        }
    }

    func refreshAll() async {
        guard GKLocalPlayer.local.isAuthenticated else {
            if case .authenticated = authState {
                authState = .unavailable("Sign in to Game Center in iOS Settings")
            }
            return
        }
        isLoadingGlobal = true
        defer { isLoadingGlobal = false }

        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID])
            guard let board = boards.first else { return }

            let result = try await board.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 10))
            let topEntries = result.1
            let localEntry = result.0

            globalTop = topEntries.map { entry in
                GlobalLeaderboardEntry(
                    id: entry.player.gamePlayerID,
                    rank: entry.rank,
                    displayName: entry.player.displayName,
                    score: entry.score,
                    isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
                )
            }

            if let localEntry {
                personalBest = localEntry.score
                personalRank = localEntry.rank
            } else {
                personalBest = nil
                personalRank = nil
            }
        } catch {
            lastError = error.localizedDescription
            log.error("GameKit refresh failed: \(error.localizedDescription)")
        }
    }

    private func flushPendingSubmissions() async {
        guard !pendingSubmissions.isEmpty else { return }
        let scores = pendingSubmissions
        pendingSubmissions.removeAll()
        for score in scores {
            await submit(score: score)
        }
    }

    private func present(_ viewController: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            log.error("No root view controller to present GameKit auth UI")
            authState = .unavailable("UI not ready")
            return
        }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(viewController, animated: true)
    }
}
