import XCTest
@testable import ShiftBlast

@MainActor
final class GameViewModelTests: XCTestCase {

    func testHandleAgentReadySignalSetsPausedAndFreezesMove() {
        let vm = GameViewModel()
        vm.swipe(.left)
        vm.handleAgentReadySignal()

        XCTAssertTrue(vm.isAgentPaused)
        if vm.state.activeMove != nil {
            XCTAssertNotNil(vm.state.activeMove?.savedProgress,
                            "Active move must be frozen with savedProgress")
        }
    }

    func testSwipeIsBlockedWhileAgentPaused() {
        let vm = GameViewModel()
        let scoreBefore = vm.state.score
        let movesBefore = vm.state.moves
        vm.handleAgentReadySignal()

        vm.swipe(.left)

        XCTAssertEqual(vm.state.score, scoreBefore, "Swipe must not score while paused")
        XCTAssertEqual(vm.state.moves, movesBefore, "Swipe must not advance moves while paused")
    }

    func testDismissAgentPauseClearsFlag() {
        let vm = GameViewModel()
        vm.handleAgentReadySignal()
        XCTAssertTrue(vm.isAgentPaused)

        vm.dismissAgentPause()

        XCTAssertFalse(vm.isAgentPaused)
        XCTAssertNil(vm.state.activeMove?.savedProgress)
    }

    func testHandleAgentReadyIsIdempotent() {
        let vm = GameViewModel()
        vm.handleAgentReadySignal()
        vm.handleAgentReadySignal()

        XCTAssertTrue(vm.isAgentPaused)
    }
}
