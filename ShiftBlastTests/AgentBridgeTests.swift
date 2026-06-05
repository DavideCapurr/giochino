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

    // MARK: - SentinelChangeTracker

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    func testFirstObservationPerSourceIsBaselineAndDoesNotFire() {
        var tracker = SentinelChangeTracker()
        XCTAssertFalse(tracker.observe(t0, from: .polling))
        XCTAssertFalse(tracker.observe(t0, from: .metadata))
    }

    func testNewChangeFiresOncePerSource() {
        var tracker = SentinelChangeTracker()
        _ = tracker.observe(t0, from: .polling)               // baseline
        XCTAssertTrue(tracker.observe(t0 + 1, from: .polling)) // new write fires
        XCTAssertFalse(tracker.observe(t0 + 1, from: .polling))// repeat does not
    }

    func testFileAppearingAfterLaunchFires() {
        // Sentinel absent at launch: both sources baseline on nil, then the
        // relay's first write makes the file appear and must fire.
        var tracker = SentinelChangeTracker()
        XCTAssertFalse(tracker.observe(nil, from: .polling))
        XCTAssertFalse(tracker.observe(nil, from: .metadata))
        XCTAssertTrue(tracker.observe(t0, from: .polling))
    }

    func testPreExistingSentinelNeverFiresWithoutNewWrite() {
        var tracker = SentinelChangeTracker()
        XCTAssertFalse(tracker.observe(t0, from: .polling))
        XCTAssertFalse(tracker.observe(t0, from: .metadata))
        // Both sources keep reporting the same pre-launch value.
        XCTAssertFalse(tracker.observe(t0, from: .polling))
        XCTAssertFalse(tracker.observe(t0, from: .metadata))
    }

    func testClockSkewDoesNotSwallowSignals() {
        // The Mac relay's clock trails this device's wall clock: the change
        // date is well in the "past". The tracker must still fire because it
        // never compares against wall time.
        var tracker = SentinelChangeTracker()
        let ancient = Date(timeIntervalSinceReferenceDate: 0) // far before "now"
        XCTAssertFalse(tracker.observe(ancient, from: .polling))     // baseline
        XCTAssertTrue(tracker.observe(ancient + 1, from: .polling))  // still fires
    }

    func testTwoSourcesReportingSameWriteDoNotDoubleFireForOlderDate() {
        var tracker = SentinelChangeTracker()
        _ = tracker.observe(t0, from: .polling)   // baseline polling
        _ = tracker.observe(t0, from: .metadata)  // baseline metadata

        // Metadata reports the new write first with the higher of the two dates.
        XCTAssertTrue(tracker.observe(t0 + 5, from: .metadata))
        // Polling then reports the same write with a slightly older timestamp;
        // it must not fire again.
        XCTAssertFalse(tracker.observe(t0 + 3, from: .polling))
    }

    func testOutOfOrderMetadataUpdateIsIgnored() {
        var tracker = SentinelChangeTracker()
        _ = tracker.observe(t0, from: .metadata)        // baseline
        XCTAssertTrue(tracker.observe(t0 + 10, from: .metadata))
        // A stale update with an earlier change date arrives late.
        XCTAssertFalse(tracker.observe(t0 + 4, from: .metadata))
        // A genuinely newer change still fires.
        XCTAssertTrue(tracker.observe(t0 + 11, from: .metadata))
    }

    func testNilAfterBaselineDoesNotFire() {
        var tracker = SentinelChangeTracker()
        _ = tracker.observe(t0, from: .polling)
        XCTAssertFalse(tracker.observe(nil, from: .polling))
    }
}
