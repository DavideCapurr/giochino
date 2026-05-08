import Foundation
import SwiftUI
import OSLog

private let log = Logger(subsystem: "com.davide.shiftblast.relay", category: "Coordinator")

/// Wires together the two detection layers (process exit + session-file
/// silence) and centralises state for the menubar UI.
@MainActor
final class RelayCoordinator: ObservableObject {
    @Published private(set) var lastSignal: Date?
    @Published private(set) var lastReason: String?
    @Published private(set) var grantedSlugs: Set<String> = []
    @Published private(set) var sentinelStatus: String = "pronto"
    @Published var loginItemEnabled: Bool = false

    private let bookmarkStore = BookmarkStore()
    private var sessionWatcher: SessionFileWatcher?
    private var lastSignalTime: Date = .distantPast
    private let throttle: TimeInterval = 2.0

    func start() {
        log.notice("🚀 ShiftBlast Relay avviato — sentinella: \(SentinelWriter.sentinelURL()?.path ?? "n/d", privacy: .public)")
        loginItemEnabled = LoginItemManager.isEnabled
        refreshGrantedSlugs()

        rebuildSessionWatcher()
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
            sentinelStatus = "ultimo invio: \(formatted(now))"
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
