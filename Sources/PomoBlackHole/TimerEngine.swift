import Foundation

struct TimerConfiguration: Codable, Equatable, Sendable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var roundsBeforeLongBreak = 4

    var focusDuration: TimeInterval { TimeInterval(max(1, focusMinutes) * 60) }
    var shortBreakDuration: TimeInterval { TimeInterval(max(1, shortBreakMinutes) * 60) }
    var longBreakDuration: TimeInterval { TimeInterval(max(1, longBreakMinutes) * 60) }
}

enum TimerPhase: String, Codable, Sendable {
    case idle, focus, shortBreak, longBreak, paused, completing
}

struct TimerEngine: Codable, Equatable, Sendable {
    var configuration: TimerConfiguration
    private(set) var phase: TimerPhase = .idle
    private(set) var underlyingPhase: TimerPhase = .focus
    private(set) var completedFocusRounds = 0
    private(set) var startedAt: Date?
    private(set) var endsAt: Date?
    private(set) var pausedRemaining: TimeInterval?

    init(configuration: TimerConfiguration = .init()) {
        self.configuration = configuration
    }

    var isRunning: Bool {
        phase == .focus || phase == .shortBreak || phase == .longBreak
    }

    mutating func start(at date: Date = Date()) {
        let target: TimerPhase = phase == .idle ? .focus : underlyingPhase
        begin(target, at: date)
    }

    mutating func pause(at date: Date = Date()) {
        guard isRunning else { return }
        pausedRemaining = remaining(at: date)
        underlyingPhase = phase
        phase = .paused
        endsAt = nil
    }

    mutating func resume(at date: Date = Date()) {
        guard phase == .paused else { return }
        let remainingDuration = max(0, pausedRemaining ?? duration(for: underlyingPhase))
        phase = underlyingPhase
        startedAt = date.addingTimeInterval(-(duration(for: underlyingPhase) - remainingDuration))
        endsAt = date.addingTimeInterval(remainingDuration)
        pausedRemaining = nil
    }

    mutating func reset() {
        phase = .idle
        underlyingPhase = .focus
        completedFocusRounds = 0
        startedAt = nil
        endsAt = nil
        pausedRemaining = nil
    }

    mutating func skip(at date: Date = Date()) {
        guard phase != .idle else { return }
        advance(from: phase == .paused ? underlyingPhase : phase, at: date)
    }

    @discardableResult
    mutating func tick(at date: Date = Date()) -> Bool {
        guard isRunning, remaining(at: date) <= 0 else { return false }
        phase = .completing
        return true
    }

    mutating func finishCompletion(at date: Date = Date()) {
        guard phase == .completing else { return }
        advance(from: underlyingPhase, at: date)
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        if phase == .paused { return max(0, pausedRemaining ?? 0) }
        guard let endsAt else { return 0 }
        return max(0, endsAt.timeIntervalSince(date))
    }

    func progress(at date: Date = Date()) -> Double {
        let trackedPhase = phase == .paused || phase == .completing ? underlyingPhase : phase
        guard trackedPhase != .idle else { return 0 }
        let total = duration(for: trackedPhase)
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(at: date) / total))
    }

    func duration(for phase: TimerPhase) -> TimeInterval {
        switch phase {
        case .focus: configuration.focusDuration
        case .shortBreak: configuration.shortBreakDuration
        case .longBreak: configuration.longBreakDuration
        default: 0
        }
    }

    private mutating func begin(_ newPhase: TimerPhase, at date: Date) {
        phase = newPhase
        underlyingPhase = newPhase
        startedAt = date
        endsAt = date.addingTimeInterval(duration(for: newPhase))
        pausedRemaining = nil
    }

    private mutating func advance(from completed: TimerPhase, at date: Date) {
        if completed == .focus {
            completedFocusRounds += 1
            let isLong = completedFocusRounds % max(1, configuration.roundsBeforeLongBreak) == 0
            begin(isLong ? .longBreak : .shortBreak, at: date)
        } else {
            begin(.focus, at: date)
        }
    }
}
