import Foundation
import SwiftUI
import OSLog

private let log = Logger(subsystem: "com.davide.shiftblast.relay", category: "Coordinator")

/// Drives session-file detection (turn start/finish parsed from the agent's
/// transcript, with a silence-window fallback) and centralises state for the
/// menubar UI. On each detected turn end it writes the iCloud sentinel the iOS
/// app watches.
@MainActor
final class RelayCoordinator: ObservableObject {
    @Published private(set) var lastSignal: Date?
    @Published private(set) var lastReason: String?
    @Published private(set) var grantedSlugs: Set<String> = []
    @Published private(set) var sentinelStatus: String = "pronto"
    @Published private(set) var iCloudReady: Bool = false
    @Published var loginItemEnabled: Bool = false

    private let bookmarkStore = BookmarkStore()
    private var sessionWatcher: SessionFileWatcher?
    private var lastSignalTime: Date = .distantPast
    private let throttle: TimeInterval = 2.0

    func start() {
        log.notice("🚀 ShiftBlast Relay avviato — sentinella: \(SentinelWriter.sentinelURL()?.path ?? "n/d", privacy: .public)")
        loginItemEnabled = LoginItemManager.isEnabled
        refreshGrantedSlugs()
        refreshICloudStatus()

        rebuildSessionWatcher()
    }

    /// Re-checks whether the real iCloud container is reachable. Surfaced in the
    /// menu so the user can tell "relay running" from "relay can actually reach
    /// iCloud" — the latter is what the iOS app depends on.
    func refreshICloudStatus() {
        iCloudReady = SentinelWriter.isICloudReady
    }

    /// Writes a sentinel immediately, bypassing the throttle, so the user can
    /// verify the relay → iCloud → iOS link with a single click without waiting
    /// for a real agent turn.
    func sendTestSignal() {
        refreshICloudStatus()
        lastSignalTime = .distantPast
        signal(reason: "test manuale dal menu")
    }

    func stop() {
        sessionWatcher?.stop()
        sessionWatcher = nil
    }

    func grantBookmark(slug: String, url: URL) {
        do {
            try bookmarkStore.save(slug: slug, url: url)
            refreshGrantedSlugs()
            rebuildSessionWatcher()
        } catch {
            sentinelStatus = "errore bookmark: \(error.localizedDescription)"
        }
    }

    func revokeBookmark(slug: String) {
        bookmarkStore.remove(slug: slug)
        refreshGrantedSlugs()
        rebuildSessionWatcher()
    }

    func setLoginItemEnabled(_ enabled: Bool) {
        LoginItemManager.setEnabled(enabled)
        loginItemEnabled = LoginItemManager.isEnabled
    }

    func suggestedSlugs() -> [(slug: String, displayName: String, defaultPath: URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return AgentNames.sessionDirectoryCandidates.map { rel in
            let url = home.appendingPathComponent(rel)
            return (slug: rel, displayName: rel, defaultPath: url)
        }
    }

    private func rebuildSessionWatcher() {
        sessionWatcher?.stop()
        let resolved = bookmarkStore.resolveAll()
        guard !resolved.isEmpty else {
            sessionWatcher = nil
            sentinelStatus = "autorizza ~/.codex/sessions"
            return
        }
        sentinelStatus = "monitor attivo su \(resolved.count) cartelle"
        let watcher = SessionFileWatcher(
            onTurnStarted: { [weak self] url in
                self?.agentTurnStarted(url: url)
            },
            onTurnFinished: { [weak self] url in
                self?.signal(reason: "risposta conclusa in \(url.lastPathComponent)")
            }
        )
        watcher.watch(resolved)
        sessionWatcher = watcher
    }

    private func refreshGrantedSlugs() {
        grantedSlugs = Set(bookmarkStore.entries.map(\.slug))
    }

    private func agentTurnStarted(url: URL) {
        lastReason = "risposta in corso in \(url.lastPathComponent)"
        sentinelStatus = "agente attivo"
    }

    private func signal(reason: String) {
        let now = Date()
        if now.timeIntervalSince(lastSignalTime) < throttle {
            log.debug("⏱️ throttle: ignorato signal '\(reason, privacy: .public)' (ultimo \(now.timeIntervalSince(self.lastSignalTime), privacy: .public)s fa)")
            return
        }
        lastSignalTime = now

        do {
            try SentinelWriter.touch(reason: reason)
            lastSignal = now
            lastReason = reason
            iCloudReady = SentinelWriter.isICloudReady
            sentinelStatus = iCloudReady
                ? "ultimo invio: \(formatted(now))"
                : "inviato \(formatted(now)) — ⚠️ iCloud non pronto, l'app potrebbe non riceverlo"
            log.notice("📡 SENTINELLA scritta — motivo: \(reason, privacy: .public)")
        } catch {
            sentinelStatus = "errore: \(error.localizedDescription)"
            log.error("❌ scrittura sentinella fallita: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
