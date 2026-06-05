import Foundation
import CoreServices
import OSLog

private let log = Logger(subsystem: "com.davide.shiftblast.relay", category: "SessionFileWatcher")

/// Watches one or more directories via FSEvents. Each filesystem change resets
/// a single shared debounce timer; if no further events occur within
/// `silenceWindow`, `onTurnFinished` fires once.
///
/// The directories must be paths the relay has security-scoped access to —
/// usually granted via `BookmarkStore` during onboarding.
@MainActor
final class SessionFileWatcher {
    private let silenceWindow: TimeInterval
    private let onTurnStarted: @MainActor (URL) -> Void
    private let onTurnFinished: @MainActor (URL) -> Void
    private var stream: FSEventStreamRef?
    private var resolved: [BookmarkStore.Resolved] = []
    private var debounceTimer: Timer?
    private var pollingTimer: Timer?
    private var lastTriggerURL: URL?
    private var lastObservedWrite: FileWriteSnapshot?
    private var lastFinishedAt: Date?
    private var lastFinishedURL: URL?
    private var lastFinishWasEvent = false
    private var isTurnActive = false
    private var activeTurnID: String?
    private var completedTurnIDs: Set<String> = []
    private var fileOffsets: [String: UInt64] = [:]
    private var pendingLines: [String: String] = [:]
    private let queue = DispatchQueue(label: "shiftblast.relay.fsevents")

    /// Hard caps that bound memory when parsing untrusted session files. A
    /// corrupt or maliciously-inflated transcript can't exhaust memory: oversized
    /// appends and unterminated lines are skipped (treated as plain activity, so
    /// the silence fallback still detects the turn end).
    private let maxAppendChunkBytes: UInt64 = 8 * 1024 * 1024   // 8 MB per read
    private let maxPendingLineBytes = 1 * 1024 * 1024           // 1 MB partial line

    init(
        silenceWindow: TimeInterval = 15.0,
        onTurnStarted: @escaping @MainActor (URL) -> Void,
        onTurnFinished: @escaping @MainActor (URL) -> Void
    ) {
        self.silenceWindow = silenceWindow
        self.onTurnStarted = onTurnStarted
        self.onTurnFinished = onTurnFinished
    }

    func watch(_ entries: [BookmarkStore.Resolved]) {
        stop()
        guard !entries.isEmpty else { return }

        let uniquePaths = Array(Set(entries.map(\.url.path))).sorted()
        let paths = uniquePaths as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<SessionFileWatcher>.fromOpaque(info).takeUnretainedValue()

            let pathsArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String]
            let firstPath = pathsArray?.first
            _ = numEvents

            Task { @MainActor in
                watcher.handleSessionWrite(firstPath: firstPath)
            }
        }

        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
        stream = s
        resolved = entries
        initializeFileOffsets()
        lastObservedWrite = latestWriteSnapshot()
        startPollingFallback()
        log.notice("👁️ FSEvents avviato su \(uniquePaths.count, privacy: .public) cartelle: \(uniquePaths.joined(separator: ", "), privacy: .public)")
        log.notice("🔎 polling sessioni avviato: ultimo file \(self.lastObservedWrite?.url.lastPathComponent ?? "nessuno", privacy: .public)")
    }

    func stop() {
        if let s = stream {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
        }
        stream = nil
        debounceTimer?.invalidate()
        debounceTimer = nil
        pollingTimer?.invalidate()
        pollingTimer = nil
        for entry in resolved {
            entry.stopAccessing()
        }
        resolved = []
        lastTriggerURL = nil
        lastObservedWrite = nil
        lastFinishedAt = nil
        lastFinishedURL = nil
        lastFinishWasEvent = false
        isTurnActive = false
        activeTurnID = nil
        completedTurnIDs = []
        fileOffsets = [:]
        pendingLines = [:]
    }

    deinit {
        if let s = stream {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
        }
        debounceTimer?.invalidate()
        pollingTimer?.invalidate()
        for entry in resolved {
            entry.stopAccessing()
        }
    }


    private struct FileWriteSnapshot {
        let url: URL
        let modificationDate: Date
    }

    private struct ParsedSessionAppend {
        var sawActivity = false
        var didFinish = false
    }

    private func startPollingFallback() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollLatestWrite() }
        }
    }

    private func pollLatestWrite() {
        guard let latest = latestWriteSnapshot() else { return }
        defer { lastObservedWrite = latest }

        guard let previous = lastObservedWrite else { return }
        guard latest.modificationDate > previous.modificationDate else { return }

        log.notice("✏️ polling: scrittura Codex rilevata in \(latest.url.lastPathComponent, privacy: .public)")
        handleSessionWrite(firstPath: latest.url.path)
    }

    private func handleSessionWrite(firstPath: String?) {
        if let firstPath {
            let url = URL(fileURLWithPath: firstPath)
            if shouldTrack(url: url) {
                let parsed = processSessionAppend(at: url)
                if parsed.didFinish { return }
            }
        }

        handleEvent(firstPath: firstPath)
    }

    private func initializeFileOffsets() {
        fileOffsets = [:]
        pendingLines = [:]
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]

        for entry in resolved {
            guard let enumerator = FileManager.default.enumerator(
                at: entry.url,
                includingPropertiesForKeys: keys,
                options: [],
                errorHandler: nil
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard shouldTrack(url: url) else { continue }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                guard values.isRegularFile == true, let size = values.fileSize else { continue }
                fileOffsets[url.path] = UInt64(size)
            }
        }
    }

    private func processSessionAppend(at url: URL) -> ParsedSessionAppend {
        guard url.pathExtension == "jsonl" else {
            return ParsedSessionAppend(sawActivity: true, didFinish: false)
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer {
                try? handle.close()
            }

            let currentOffset = try handle.seekToEnd()
            let previousOffset = fileOffsets[url.path] ?? currentOffset
            guard currentOffset >= previousOffset else {
                fileOffsets[url.path] = currentOffset
                pendingLines[url.path] = nil
                return ParsedSessionAppend()
            }
            guard currentOffset > previousOffset else {
                return ParsedSessionAppend()
            }

            // Bound the single-pass read: an inflated/corrupt file can't make us
            // load an unbounded blob into memory. Fast-forward and let the
            // silence fallback handle the turn end.
            if currentOffset - previousOffset > maxAppendChunkBytes {
                fileOffsets[url.path] = currentOffset
                pendingLines[url.path] = nil
                return ParsedSessionAppend(sawActivity: true, didFinish: false)
            }

            try handle.seek(toOffset: previousOffset)
            let data = try handle.readToEnd() ?? Data()
            fileOffsets[url.path] = currentOffset

            let chunk = (pendingLines[url.path] ?? "") + String(decoding: data, as: UTF8.self)
            var lines = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if chunk.hasSuffix("\n") {
                pendingLines[url.path] = nil
            } else {
                let tail = lines.popLast()
                // Drop an unterminated line that grows past the cap so a file
                // with no newlines can't inflate the pending buffer unbounded.
                if let tail, tail.utf8.count <= maxPendingLineBytes {
                    pendingLines[url.path] = tail
                } else {
                    pendingLines[url.path] = nil
                }
            }

            var parsed = ParsedSessionAppend()
            for line in lines {
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let lineResult = processSessionLine(line, fileURL: url)
                parsed.sawActivity = parsed.sawActivity || lineResult.sawActivity
                parsed.didFinish = parsed.didFinish || lineResult.didFinish
            }
            return parsed
        } catch {
            log.debug("JSONL non leggibile per parsing eventi: \(url.path, privacy: .public)")
            return ParsedSessionAppend(sawActivity: true, didFinish: false)
        }
    }

    private func processSessionLine(_ line: String, fileURL: URL) -> ParsedSessionAppend {
        guard
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ParsedSessionAppend()
        }

        let topLevelType = object["type"] as? String
        let payload = object["payload"] as? [String: Any]
        let payloadType = payload?["type"] as? String
        let turnID = payload?["turn_id"] as? String

        if topLevelType == "event_msg", payloadType == "task_started" {
            activeTurnID = turnID
            startTurn(from: fileURL)
            return ParsedSessionAppend(sawActivity: true, didFinish: false)
        }

        if topLevelType == "event_msg", payloadType == "task_complete" || payloadType == "turn_aborted" {
            if let turnID, completedTurnIDs.contains(turnID) {
                return ParsedSessionAppend()
            }
            if let turnID {
                completedTurnIDs.insert(turnID)
            }
            finishTurn(from: fileURL, reason: payloadType ?? "turn ended")
            return ParsedSessionAppend(sawActivity: false, didFinish: true)
        }

        if isCodexActivity(topLevelType: topLevelType, payloadType: payloadType) {
            return ParsedSessionAppend(sawActivity: true, didFinish: false)
        }

        return ParsedSessionAppend()
    }

    private func isCodexActivity(topLevelType: String?, payloadType: String?) -> Bool {
        if topLevelType == "response_item" {
            return true
        }

        guard topLevelType == "event_msg", let payloadType else { return false }
        return [
            "agent_message",
            "exec_approval_request",
            "exec_command_begin",
            "exec_command_end",
            "patch_apply_begin",
            "patch_apply_end",
            "token_count"
        ].contains(payloadType)
    }

    private func latestWriteSnapshot() -> FileWriteSnapshot? {
        var latest: FileWriteSnapshot?
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]

        for entry in resolved {
            guard let enumerator = FileManager.default.enumerator(
                at: entry.url,
                includingPropertiesForKeys: keys,
                options: [],
                errorHandler: nil
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard shouldTrack(url: url) else { continue }
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
                guard values.isRegularFile == true, let modificationDate = values.contentModificationDate else { continue }
                if latest == nil || modificationDate > latest!.modificationDate {
                    latest = FileWriteSnapshot(url: url, modificationDate: modificationDate)
                }
            }
        }

        return latest
    }

    private func shouldTrack(url: URL) -> Bool {
        let name = url.lastPathComponent
        guard name.hasSuffix(".jsonl") || name.hasSuffix(".sqlite-wal") || name.hasSuffix(".sqlite") else {
            return false
        }
        // Defense in depth: only ever read files that genuinely live inside a
        // granted root. This rejects a symlink planted in the watched folder
        // that resolves to a path outside the authorized tree.
        return isUnderGrantedRoot(url)
    }

    /// True when `url`, after fully resolving symlinks, still sits inside one of
    /// the security-scoped roots the user authorized.
    private func isUnderGrantedRoot(_ url: URL) -> Bool {
        let resolvedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        for entry in resolved {
            let rootPath = entry.url.resolvingSymlinksInPath().standardizedFileURL.path
            if resolvedPath == rootPath || resolvedPath.hasPrefix(rootPath + "/") {
                return true
            }
        }
        return false
    }

    private func handleEvent(firstPath: String?) {
        if let firstPath {
            lastTriggerURL = matchedRoot(for: firstPath) ?? lastTriggerURL
            log.debug("✏️ scrittura rilevata: \(firstPath, privacy: .public)")
        }
        let url = lastTriggerURL ?? resolved.first?.url
        // Mark a turn as started unless these are trailing writes flushed right
        // after an event-based finish. We still (re)arm the silence timer below,
        // so a genuinely new turn is detected even within that window.
        if !isTurnActive, let url, !isIgnoringLateWrite(for: url) {
            isTurnActive = true
            log.notice("▶️ risposta agente rilevata in \(url.lastPathComponent, privacy: .public)")
            onTurnStarted(url)
        }
        debounceTimer?.invalidate()
        let window = silenceWindow
        debounceTimer = Timer.scheduledTimer(withTimeInterval: window, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fireSilence() }
        }
    }

    private func startTurn(from fileURL: URL) {
        let url = matchedRoot(for: fileURL.path) ?? lastTriggerURL ?? resolved.first?.url
        guard let url else { return }
        lastTriggerURL = url
        guard !isTurnActive else { return }
        if isIgnoringLateWrite(for: url) { return }
        isTurnActive = true
        log.notice("▶️ task_started Codex in \(fileURL.lastPathComponent, privacy: .public)")
        onTurnStarted(url)
    }

    /// True only while we're inside the window that swallows trailing writes
    /// flushed right after an **event-based** finish (e.g. Codex emitting
    /// `token_count` after `task_complete`). A silence-based finish leaves no
    /// trailing writes, so we never suppress after one — that's what lets
    /// back-to-back turns of silence-only agents still be detected.
    private func isIgnoringLateWrite(for url: URL) -> Bool {
        guard lastFinishWasEvent, let lastFinishedAt, let lastFinishedURL else { return false }
        let isSameRoot = url.path == lastFinishedURL.path
        return isSameRoot && Date().timeIntervalSince(lastFinishedAt) < 20
    }

    private func finishTurn(from fileURL: URL, reason: String) {
        let url = matchedRoot(for: fileURL.path) ?? lastTriggerURL ?? resolved.first?.url
        guard let url else { return }

        debounceTimer?.invalidate()
        debounceTimer = nil
        isTurnActive = false
        activeTurnID = nil
        lastTriggerURL = url
        lastFinishedAt = Date()
        lastFinishedURL = url
        lastFinishWasEvent = true
        log.notice("✅ evento Codex \(reason, privacy: .public) in \(fileURL.lastPathComponent, privacy: .public) → fine risposta")
        onTurnFinished(url)
    }

    private func fireSilence() {
        let url = lastTriggerURL ?? resolved.first?.url
        guard let url else { return }
        // Silence following trailing writes after an event-based finish is not a
        // new turn — drop it instead of emitting a duplicate signal.
        if isIgnoringLateWrite(for: url) {
            isTurnActive = false
            return
        }
        isTurnActive = false
        activeTurnID = nil
        lastFinishedAt = Date()
        lastFinishedURL = url
        lastFinishWasEvent = false
        log.notice("🤫 silenzio di \(self.silenceWindow, privacy: .public)s in \(url.lastPathComponent, privacy: .public) → fine risposta")
        onTurnFinished(url)
    }

    private func matchedRoot(for eventPath: String) -> URL? {
        for entry in resolved where eventPath.hasPrefix(entry.url.path) {
            return entry.url
        }
        return nil
    }
}
