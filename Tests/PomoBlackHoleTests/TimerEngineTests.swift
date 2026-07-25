import XCTest
@testable import PomoBlackHole

final class TimerEngineTests: XCTestCase {
    func testFocusProgressPauseAndResume() {
        let start = Date(timeIntervalSince1970: 1_000)
        var engine = TimerEngine(configuration: .init(
            focusMinutes: 1,
            shortBreakMinutes: 1,
            longBreakMinutes: 2,
            roundsBeforeLongBreak: 2
        ))
        engine.start(at: start)
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.progress(at: start.addingTimeInterval(30)), 0.5, accuracy: 0.001)

        engine.pause(at: start.addingTimeInterval(30))
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertEqual(engine.remaining(at: start.addingTimeInterval(300)), 30, accuracy: 0.001)

        engine.resume(at: start.addingTimeInterval(300))
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.remaining(at: start.addingTimeInterval(315)), 15, accuracy: 0.001)
    }

    func testCompletionAdvancesToBreak() {
        let start = Date(timeIntervalSince1970: 1_000)
        var engine = TimerEngine(configuration: .init(
            focusMinutes: 1,
            shortBreakMinutes: 1,
            longBreakMinutes: 2,
            roundsBeforeLongBreak: 2
        ))
        engine.start(at: start)
        XCTAssertTrue(engine.tick(at: start.addingTimeInterval(60)))
        XCTAssertEqual(engine.phase, .completing)
        engine.finishCompletion(at: start.addingTimeInterval(62))
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.completedFocusRounds, 1)
    }

    func testLongBreakAfterConfiguredRounds() {
        let start = Date(timeIntervalSince1970: 1_000)
        var engine = TimerEngine(configuration: .init(
            focusMinutes: 1,
            shortBreakMinutes: 1,
            longBreakMinutes: 2,
            roundsBeforeLongBreak: 2
        ))
        engine.start(at: start)
        engine.skip(at: start)
        engine.skip(at: start)
        engine.skip(at: start)
        XCTAssertEqual(engine.phase, .longBreak)
        XCTAssertEqual(engine.completedFocusRounds, 2)
    }

    func testResetClearsSession() {
        var engine = TimerEngine()
        engine.start()
        engine.pause()
        engine.reset()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.completedFocusRounds, 0)
        XCTAssertEqual(engine.remaining(), 0)
    }
}
