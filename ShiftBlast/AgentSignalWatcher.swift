import Foundation
import OSLog

private let log = Logger(subsystem: "com.davide.shiftblast", category: "AgentSignalWatcher")

/// Pure decision logic for the sentinel watcher.
///
/// The watcher observes the same sentinel file through two independent sources:
/// `NSMetadataQuery` (which reports iCloud's content-change date) and a local
/// polling fallback (which reports the file's modification date). Those two
/// clocks rarely agree to the second, and — crucially — neither agrees with the
/// iOS device's wall clock, because the file is produced by a *different*
/// machine (the Mac relay). Comparing a change date against local wall time is
/// therefore unsafe: if the Mac clock trails the iPhone clock by even a few
/// seconds, every genuine signal looks "older than launch" and is dropped.
///
/// This tracker sidesteps that entirely. It never looks at wall time. The first
/// observation from each source merely establishes a baseline (so a sentinel
/// that already existed before launch can't trigger), and afterwards any change
/// date we have not already acted on fires exactly once. A shared high-water
/// mark dedupes the two sources reporting the same underlying write with
/// slightly different timestamps and ignores out-of-order updates.
struct SentinelChangeTracker {
    enum Source: Hashable { case metadata, polling }

    private var lastSeen: [Source: Date] = [:]
    private var baselinedSources: Set<Source> = []
    private var lastFired: Date?

    /// Records an observation and returns `true` when it represents a new change
    /// that should fire the signal. `date` may be `nil` when the file does not
    /// (yet) exist; that still counts as a baseline so a file *appearing* after
    /// launch is correctly treated as a fresh signal.
    mutating func observe(_ date: Date?, from source: Source) -> Bool {
        let isFirstObservation = !baselinedSources.contains(source)
        baselinedSources.insert(source)
        defer { if let date { lastSeen[source] = date } }

        // The first observation from each source only establishes a baseline.
        if isFirstObservation { return false }

        // The file is missing now; nothing to fire on.
        guard let date else { return false }

        // Same value we already saw from this source — not a new write.
        guard date != lastSeen[source] else { return false }

        // Fire only for the newest change we have ever acted on. This dedupes
        // the two sources describing one write with differing timestamps and
        // discards an older content-change date arriving out of order.
        if let lastFired, date <= lastFired { return false }
        lastFired = date
        return true
    }
}

/// Watches the shared sentinel file in the app's iCloud ubiquity container and
/// fires `onSignal` on the main actor whenever its content changes. Producer is
/// the macOS ShiftBlast Relay app.
///
/// Combines `NSMetadataQuery` (for ubiquitous-aware updates) with a 0.75s
/// polling fallback (covers cases where iCloud has not yet downloaded the
/// item). Both feed a single `SentinelChangeTracker`, which guarantees a real
/// signal is never swallowed by clock skew between the Mac relay and this
/// device, and that one write fires the game pause at most once.
final class AgentSignalWatcher {
    static let sentinelName = "agent-stop.flag"

    private let onSignal: @MainActor (Date) -> Void
    private var query: NSMetadataQuery?
    private var pollingTimer: Timer?
    private var tracker = SentinelChangeTracker()
    private var observers: [NSObjectProtocol] = []

    init(onSignal: @escaping @MainActor (Date) -> Void) {
        self.onSignal = onSignal
    }

    static var isAvailable: Bool {
        AgentBridgeICloud.isAvailable
    }

    static func sentinelURL() -> URL? {
        AgentBridgeICloud.containerDocumentsURL()?.appendingPathComponent(sentinelName)
    }

    func start() {
        guard query == nil, pollingTimer == nil else { return }
        tracker = SentinelChangeTracker()

        if let docs = AgentBridgeICloud.containerDocumentsURL() {
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            log.notice("👁️ AgentSignalWatcher avviato — sentinella: \(docs.appendingPathComponent(Self.sentinelName).path, privacy: .public)")
        } else {
            log.notice("⚠️ AgentSignalWatcher senza container iCloud disponibile")
        }

        pollSentinel()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.pollSentinel()
        }

        startMetadataQueryIfPossible()
    }

    /// Starts the ubiquitous metadata query once iCloud is reachable. Safe to
    /// call repeatedly: it no-ops once a query is running. The polling loop
    /// retries it, so a cold launch where iCloud isn't yet provisioned still
    /// gets the push-style query as soon as the container appears.
    private func startMetadataQueryIfPossible() {
        guard query == nil, Self.isAvailable else { return }

        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, Self.sentinelName)
        q.valueListAttributes = [NSMetadataItemFSContentChangeDateKey, NSMetadataItemURLKey]

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main
        ) { [weak self] _ in
            self?.handle(query: q)
        })
        observers.append(nc.addObserver(
            forName: .NSMetadataQueryDidUpdate, object: q, queue: .main
        ) { [weak self] _ in
            self?.handle(query: q)
        })

        query = q
        q.start()
        log.notice("🔎 NSMetadataQuery avviata su container iCloud")
    }

    func stop() {
        query?.stop()
        pollingTimer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        query = nil
        pollingTimer = nil
        tracker = SentinelChangeTracker()
    }

    deinit { stop() }

    private func handle(query: NSMetadataQuery) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        let mdate = (query.results.first as? NSMetadataItem)?
            .value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date

        if tracker.observe(mdate, from: .metadata), let mdate {
            fire(changeDate: mdate)
        }
    }

    private func pollSentinel() {
        // Retry the push-style query if iCloud only became reachable after launch.
        startMetadataQueryIfPossible()

        guard let url = Self.sentinelURL() else { return }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let mdate = attrs?[.modificationDate] as? Date

        if tracker.observe(mdate, from: .polling), let mdate {
            fire(changeDate: mdate)
        }
    }

    private func fire(changeDate: Date) {
        log.notice("📡 sentinella rilevata — changeDate: \(changeDate.formatted(), privacy: .public)")
        let cb = onSignal
        MainActor.assumeIsolated { cb(changeDate) }
    }
}
