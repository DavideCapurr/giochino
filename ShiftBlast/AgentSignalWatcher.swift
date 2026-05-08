import Foundation
import OSLog

private let log = Logger(subsystem: "com.davide.shiftblast", category: "AgentSignalWatcher")

/// Watches the shared sentinel file in the app's iCloud ubiquity container and
/// fires `onSignal` on the main actor whenever its mtime advances. Producer is
/// the macOS ShiftBlast Relay app.
///
/// Combines `NSMetadataQuery` (for ubiquitous-aware updates) with a 0.75s
/// polling fallback (covers cases where iCloud has not yet downloaded the
/// item).
final class AgentSignalWatcher {
    static let sentinelName = "agent-stop.flag"

    private let onSignal: @MainActor (Date) -> Void
    private var query: NSMetadataQuery?
    private var pollingTimer: Timer?
    private var lastChangeDate: Date?
    private var didTakeInitialSnapshot = false
    private var startedAt: Date?
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
        startedAt = Date()

        if let docs = AgentBridgeICloud.containerDocumentsURL() {
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            log.notice("👁️ AgentSignalWatcher avviato — sentinella: \(docs.appendingPathComponent(Self.sentinelName).path, privacy: .public)")
        } else {
            log.notice("⚠️ AgentSignalWatcher senza container iCloud disponibile")
        }

        pollSentinel(isInitial: true)
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            self?.pollSentinel(isInitial: false)
        }

        guard Self.isAvailable else { return }

        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, Self.sentinelName)
        q.valueListAttributes = [NSMetadataItemFSContentChangeDateKey, NSMetadataItemURLKey]

        let nc = NotificationCenter.default
        observers.append(nc.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main
        ) { [weak self] _ in
            self?.handle(query: q, isInitial: true)
        })
        observers.append(nc.addObserver(
            forName: .NSMetadataQueryDidUpdate, object: q, queue: .main
        ) { [weak self] _ in
            self?.handle(query: q, isInitial: false)
        })

        query = q
        q.start()
    }

    func stop() {
        query?.stop()
        pollingTimer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        query = nil
        pollingTimer = nil
        didTakeInitialSnapshot = false
        startedAt = nil
    }

    deinit { stop() }

    private func handle(query: NSMetadataQuery, isInitial: Bool) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        let mdate = (query.results.first as? NSMetadataItem)?
            .value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
        defer { lastChangeDate = mdate }

        if isInitial { return }
        guard let mdate, mdate != lastChangeDate else { return }

        emitSignalIfNeeded(changeDate: mdate)
    }

    private func pollSentinel(isInitial: Bool) {
        guard let url = Self.sentinelURL() else { return }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let mdate = attrs?[.modificationDate] as? Date

        if isInitial || !didTakeInitialSnapshot {
            lastChangeDate = mdate
            didTakeInitialSnapshot = true
            return
        }

        guard let mdate else { return }
        emitSignalIfNeeded(changeDate: mdate)
    }

    private func emitSignalIfNeeded(changeDate: Date) {
        guard changeDate != lastChangeDate else { return }
        lastChangeDate = changeDate
        if let startedAt, changeDate <= startedAt {
            log.notice("📷 sentinella precedente all'avvio ignorata — changeDate: \(changeDate.formatted(), privacy: .public)")
            return
        }
        log.notice("📡 sentinella rilevata — changeDate: \(changeDate.formatted(), privacy: .public)")
        let cb = onSignal
        MainActor.assumeIsolated { cb(changeDate) }
    }
}
