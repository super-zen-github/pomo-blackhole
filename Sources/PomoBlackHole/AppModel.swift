import AppKit
import Combine
import Foundation
import UserNotifications

enum VisualMode: String, Codable, CaseIterable {
    case liveDistortion
    case overlayOnly

    @MainActor
    var title: String {
        self == .liveDistortion ? L.text("Live Desktop Distortion") : L.text("Visual Only")
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var engine: TimerEngine
    @Published var visualMode: VisualMode {
        didSet { defaults.set(visualMode.rawValue, forKey: Keys.visualMode) }
    }
    @Published var appLanguage: AppLanguage {
        didSet {
            L.language = appLanguage
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            onUpdate?()
            objectWillChange.send()
        }
    }
    @Published var isRepositioning = false

    private let defaults = UserDefaults.standard
    private var ticker: Timer?
    private var completionTask: Task<Void, Never>?
    var onUpdate: (() -> Void)?
    var onCompletionAnimation: (() -> Void)?

    private enum Keys {
        static let engine = "timer.engine"
        static let configuration = "timer.configuration"
        static let visualMode = "visual.mode"
        static let appLanguage = "app.language"
    }

    init() {
        let savedDefaults = UserDefaults.standard
        if let data = savedDefaults.data(forKey: Keys.engine),
           let saved = try? JSONDecoder().decode(TimerEngine.self, from: data) {
            engine = saved
        } else if let data = savedDefaults.data(forKey: Keys.configuration),
                  let config = try? JSONDecoder().decode(TimerConfiguration.self, from: data) {
            engine = TimerEngine(configuration: config)
        } else {
            engine = TimerEngine()
        }
        visualMode = VisualMode(rawValue: savedDefaults.string(forKey: Keys.visualMode) ?? "") ?? .overlayOnly
        appLanguage = AppLanguage(rawValue: savedDefaults.string(forKey: Keys.appLanguage) ?? "") ?? .system
        L.language = appLanguage
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        requestNotificationPermission()
    }

    var phase: TimerPhase { engine.phase }
    var progress: Double { engine.progress() }
    var remaining: TimeInterval { engine.remaining() }

    func startPauseResume() {
        switch engine.phase {
        case .idle: engine.start()
        case .paused: engine.resume()
        case .focus, .shortBreak, .longBreak: engine.pause()
        case .completing: break
        }
        changed()
    }

    func skip() {
        completionTask?.cancel()
        engine.skip()
        changed()
    }

    func reset() {
        completionTask?.cancel()
        engine.reset()
        changed()
    }

    func updateConfiguration(_ configuration: TimerConfiguration) {
        engine.configuration = configuration
        saveConfiguration()
        changed()
    }

    private func tick() {
        if engine.tick() {
            notifyCompletion()
            onCompletionAnimation?()
            changed()
            completionTask = Task {
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                engine.finishCompletion()
                changed()
            }
        } else {
            onUpdate?()
        }
    }

    private func changed() {
        if let data = try? JSONEncoder().encode(engine) {
            defaults.set(data, forKey: Keys.engine)
        }
        onUpdate?()
        objectWillChange.send()
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(engine.configuration) {
            defaults.set(data, forKey: Keys.configuration)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyCompletion() {
        let content = UNMutableNotificationContent()
        content.title = engine.underlyingPhase == .focus
            ? L.text("Focus Complete")
            : L.text("Break Complete")
        content.body = engine.underlyingPhase == .focus
            ? L.text("The black hole has collapsed. Time for a break.")
            : L.text("Ready for your next focus session.")
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        ))
    }
}
