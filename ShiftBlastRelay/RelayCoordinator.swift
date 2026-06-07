import Foundation
import SwiftUI
import OSLog
import Darwin

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
        Self.raiseOpenFileLimit()
        loginItemEnabled = LoginItemManager.isEnabled
        refreshGrantedSlugs()
        refreshICloudStatus()

        rebuildSessionWatcher()
    }

    /// Raises the process's open-file soft limit and returns what actually took
    /// effect. A menu-bar app often launches with a soft limit as low as 256;
    /// watching a large tree like `~/.claude/projects` (enumeration + transient
    /// handles) exhausts it and makes every file op — including the sentinel
    /// write — fail with "Too many open files".
    ///
    /// The earlier version gave up whenever `min(rlim_max, 8192)` wasn't strictly
    /// above the current soft limit, and treated a single failed `setrlimit` as
    /// fatal — so a Mac that reported a low `rlim_max` or rejected the 8192
    /// request kept silently running at 256, which is exactly the "EMFILE even at
    /// startup" symptom. This version steps the target down until a request
    /// sticks, then re-reads the kernel to report the value really in force, so we
    /// always claim the most headroom the system will grant.
    @discardableResult
    private static func raiseOpenFileLimit() -> rlim_t {
        var limits = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &limits) == 0 else { return 0 }

        let desired: rlim_t = 8192
        if limits.rlim_cur < desired {
            // Try the largest target first, then back off. macOS caps the table
            // at OPEN_MAX (10240) and some configs reject the "unlimited" hard
            // value, so a fixed 8192 request can fail outright — stepping down
            // guarantees we still raise the limit as far as the kernel allows.
            for target in [desired, rlim_t(4096), rlim_t(2048), rlim_t(1024)]
            where target > limits.rlim_cur {
                var attempt = limits
                attempt.rlim_cur = target
                // Lift the hard cap alongside the soft one when it would block us;
                // harmless when the kernel keeps it where it is.
                if attempt.rlim_max < target { attempt.rlim_max = target }
                if setrlimit(RLIMIT_NOFILE, &attempt) == 0 { break }
            }
        }

        // Re-read so we report the value the kernel granted, not the one we asked
        // for — the gap between the two is the whole diagnosis if EMFILE persists.
        var now = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &now) == 0 else { return 0 }
        if now.rlim_cur >= 1024 {
            log.notice("📈 limite file descriptor: \(now.rlim_cur, privacy: .public)")
        } else {
            log.error("⚠️ limite file descriptor ancora basso (\(now.rlim_cur, privacy: .public), errno \(errno, privacy: .public)) — rischio EMFILE")
        }
        return now.rlim_cur
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
            try writeSentinelWithRetry(reason: reason)
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

    /// Writes the sentinel, and if the first attempt fails specifically because
    /// the process is out of file descriptors, raises the limit again and retries
    /// once. This self-heals the "Too many open files" failure that the user could
    /// otherwise only clear by relaunching the relay.
    private func writeSentinelWithRetry(reason: String) throws {
        do {
            try SentinelWriter.touch(reason: reason)
        } catch {
            guard Self.isTooManyOpenFiles(error) else { throw error }
            log.error("♻️ EMFILE in scrittura sentinella — rialzo il limite e riprovo")
            Self.raiseOpenFileLimit()
            try SentinelWriter.touch(reason: reason)
        }
    }

    /// True when `error` is the POSIX `EMFILE` ("Too many open files"), whether it
    /// surfaces as a bare POSIX error or wrapped inside a Cocoa error.
    private static func isTooManyOpenFiles(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(EMFILE) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSPOSIXErrorDomain, underlying.code == Int(EMFILE) {
            return true
        }
        return nsError.localizedDescription.contains("Too many open files")
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
