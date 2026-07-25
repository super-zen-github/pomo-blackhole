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
            Section("计时") {
                Stepper("专注：\(configuration.focusMinutes) 分钟", value: $configuration.focusMinutes, in: 1...180)
                Stepper("短休息：\(configuration.shortBreakMinutes) 分钟", value: $configuration.shortBreakMinutes, in: 1...60)
                Stepper("长休息：\(configuration.longBreakMinutes) 分钟", value: $configuration.longBreakMinutes, in: 1...120)
                Stepper("每 \(configuration.roundsBeforeLongBreak) 轮长休息", value: $configuration.roundsBeforeLongBreak, in: 1...12)
            }
            Section("视觉") {
                Picker("模式", selection: $model.visualMode) {
                    ForEach(VisualMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(model.visualMode == .liveDistortion
                     ? "需要在系统设置中授予屏幕录制权限。失败时自动切换纯视觉模式。"
                     : "不读取屏幕内容，使用光环和粒子模拟吸入效果。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("保存") { model.updateConfiguration(configuration) }
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
        window.title = "黑洞番茄钟设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
