import Foundation

/// iCloud-backed channel between the macOS relay (writer) and the iOS game
/// (reader). The relay touches a single sentinel file in the app's ubiquity
/// container; the game watches its mtime via `AgentSignalWatcher`.
enum AgentBridgeICloud {
    static let appBundleIdentifier = "com.davide.shiftblast"
    static let iCloudContainerIdentifier = "iCloud.\(appBundleIdentifier)"

    static var isAvailable: Bool {
        containerDocumentsURL() != nil
    }

    static func containerDocumentsURL() -> URL? {
        if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier)?
            .appendingPathComponent("Documents", isDirectory: true)
        {
            return ubiquityURL
        }

        #if targetEnvironment(simulator)
        if let fallbackURL = simulatorHostContainerDocumentsURL() {
            return fallbackURL
        }
        #endif

        #if os(macOS)
        let fallbackURL = macPhysicalContainerDocumentsURL()
        let fm = FileManager.default
        if fm.fileExists(atPath: fallbackURL.path) {
            return fallbackURL
        }
        let containerURL = fallbackURL.deletingLastPathComponent()
        if fm.fileExists(atPath: containerURL.path) {
            return fallbackURL
        }
        return nil
        #else
        return nil
        #endif
    }

    #if targetEnvironment(simulator)
    static func simulatorHostContainerDocumentsURL() -> URL? {
        guard
            let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"],
            !hostHome.isEmpty
        else {
            return nil
        }

        let folderName = iCloudContainerIdentifier.replacingOccurrences(of: ".", with: "~")
        return URL(fileURLWithPath: hostHome, isDirectory: true)
            .appendingPathComponent("Library/Mobile Documents", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
    }
    #endif

    #if os(macOS)
    static func macPhysicalContainerDocumentsURL() -> URL {
        let folderName = iCloudContainerIdentifier.replacingOccurrences(of: ".", with: "~")
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
    }
    #endif
}
