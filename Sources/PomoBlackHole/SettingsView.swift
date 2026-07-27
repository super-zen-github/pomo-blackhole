import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var configuration: TimerConfiguration
    @State private var showingSaveConfirmation = false

    init(model: AppModel) {
        self.model = model
        _configuration = State(initialValue: model.engine.configuration)
    }

    var body: some View {
        VStack(spacing: 0) {
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
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button {
                    model.updateConfiguration(configuration)
                    withAnimation(.easeOut(duration: 0.15)) {
                        showingSaveConfirmation = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeIn(duration: 0.15)) {
                            showingSaveConfirmation = false
                        }
                    }
                } label: {
                    Label(
                        L.text(showingSaveConfirmation ? "Saved" : "Save"),
                        systemImage: showingSaveConfirmation ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                    .frame(minWidth: 72)
                }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .frame(width: 430, height: 430)
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
