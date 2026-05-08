import XCTest
@testable import ShiftBlast

final class AgentBridgeTests: XCTestCase {

    func testSentinelNameIsStableAndShared() {
        XCTAssertEqual(AgentSignalWatcher.sentinelName, "agent-stop.flag")
    }

    func testICloudIdentifiersAreDerivedFromBundle() {
        XCTAssertEqual(AgentBridgeICloud.appBundleIdentifier, "com.davide.shiftblast")
        XCTAssertEqual(AgentBridgeICloud.iCloudContainerIdentifier, "iCloud.com.davide.shiftblast")
    }

    #if os(macOS)
    func testMacFallbackPathMatchesBundleID() {
        let url = AgentBridgeICloud.macPhysicalContainerDocumentsURL()
        XCTAssertTrue(url.path.contains("Mobile Documents/iCloud~com~davide~shiftblast/Documents"))
    }
    #endif
}
