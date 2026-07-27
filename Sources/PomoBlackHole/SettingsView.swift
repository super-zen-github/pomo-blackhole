import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var configuration: TimerConfiguration

    init(model: AppModel) {
        self.model = model
        _configuration = State(initialValue: model.engine.configuration)
    }

    var body: some View {
        Form {
            Section(L.text("Language")) {
                Picker(L.text("App Language"), selection: $model.appLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.title).tag(language)
                    }
                }
            }
            Section(L.text("Timer")) {
                Stepper(L.format("Focus: %d minutes", configuration.focusMinutes), value: $configuration.focusMinutes, in: 1...180)
                Stepper(L.format("Short break: %d minutes", configuration.shortBreakMinutes), value: $configuration.shortBreakMinutes, in: 1...60)
                Stepper(L.format("Long break: %d minutes", configuration.longBreakMinutes), value: $configuration.longBreakMinutes, in: 1...120)
                Stepper(L.format("Long break every %d rounds", configuration.roundsBeforeLongBreak), value: $configuration.roundsBeforeLongBreak, in: 1...12)
            }
            Section(L.text("Visuals")) {
                Picker(L.text("Mode"), selection: $model.visualMode) {
                    ForEach(VisualMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(model.visualMode == .liveDistortion
                     ? L.text("Screen Recording permission is required in System Settings. The app falls back to Visual Only mode if capture fails.")
                     : L.text("Does not read screen content. Uses a glow and particles to simulate the pull."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button(L.text("Save")) { model.updateConfiguration(configuration) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 430, height: 390)
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    init(model: AppModel) {
        let controller = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(contentViewController: controller)
        window.title = L.text("Black Hole Pomodoro Settings")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    func refreshLocalization() {
        window?.title = L.text("Black Hole Pomodoro Settings")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
