import Foundation

/// Writes the iCloud sentinel file that the iOS app polls. A coordinated write
/// updates the file's mtime; that change is what `AgentSignalWatcher` reacts
/// to in the iOS target.
enum SentinelWriter {
    static let sentinelName = "agent-stop.flag"
    static let containerIdentifier = "iCloud.com.davide.shiftblast"

    enum WriteError: Error {
        case containerUnavailable
    }

    static func sentinelURL() -> URL? {
        guard let docs = containerDocumentsURL() else { return nil }
        return docs.appendingPathComponent(sentinelName)
    }

    /// True only when the real iCloud ubiquity container is provisioned and
    /// reachable. When this is false the sentinel cannot actually sync to the
    /// iOS app, so the relay surfaces it instead of silently writing to a
    /// physical path the sandbox can't propagate.
    static var isICloudReady: Bool {
        ubiquityDocumentsURL() != nil
    }

    static func touch(reason: String) throws {
        guard let url = sentinelURL() else { throw WriteError.containerUnavailable }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let payload: [String: String] = [
            "sentAt": ISO8601DateFormatter().string(from: Date()),
            "reason": reason
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(
            writingItemAt: url, options: .forReplacing, error: &coordError
        ) { coordURL in
            do {
                try data.write(to: coordURL, options: [.atomic])
            } catch {
                writeError = error
            }
        }
        if let writeError { throw writeError }
        if let coordError { throw coordError }
    }

    static func containerDocumentsURL() -> URL? {
        if let ubiquity = ubiquityDocumentsURL() {
            return ubiquity
        }
        return macPhysicalContainerDocumentsURL()
    }

    private static func ubiquityDocumentsURL() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    private static func macPhysicalContainerDocumentsURL() -> URL? {
        let folderName = containerIdentifier.replacingOccurrences(of: ".", with: "~")
        let candidate = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
        return candidate
    }
}
