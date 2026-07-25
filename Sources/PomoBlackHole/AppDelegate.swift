import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var overlay: OverlayController?
    private var settings: SettingsWindowController?
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlay = OverlayController(model: model)
        settings = SettingsWindowController(model: model)
        setupStatusItem()
        model.onUpdate = { [weak self] in
            self?.overlay?.update()
            self?.refreshStatusTitle()
        }
        refreshStatusTitle()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "黑洞番茄钟")
        item.button?.imagePosition = .imageLeading
        menu.delegate = self
        item.menu = menu
        statusItem = item
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        let phaseName = switch model.phase {
        case .idle: "尚未开始"
        case .focus: "专注中"
        case .shortBreak: "短休息"
        case .longBreak: "长休息"
        case .paused: "已暂停"
        case .completing: "正在坍缩"
        }
        let info = NSMenuItem(title: "\(phaseName) · \(formatted(model.remaining))", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())

        let primaryTitle = switch model.phase {
        case .idle: "开始专注"
        case .paused: "继续"
        case .focus, .shortBreak, .longBreak: "暂停"
        case .completing: "完成中…"
        }
        menu.addItem(withTitle: primaryTitle, action: #selector(toggleTimer), keyEquivalent: " ")
        menu.addItem(withTitle: "跳过当前阶段", action: #selector(skip), keyEquivalent: "")
        menu.addItem(withTitle: "重置", action: #selector(reset), keyEquivalent: "")
        menu.addItem(.separator())

        let reposition = menu.addItem(
            withTitle: model.isRepositioning ? "完成移动" : "移动黑洞",
            action: #selector(toggleReposition),
            keyEquivalent: ""
        )
        reposition.state = model.isRepositioning ? .on : .off
        menu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出黑洞番茄钟", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items where item.action != nil { item.target = self }
    }

    private func refreshStatusTitle() {
        statusItem?.button?.title = model.phase == .idle ? "" : formatted(model.remaining)
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    @objc private func toggleTimer() { model.startPauseResume() }
    @objc private func skip() { model.skip() }
    @objc private func reset() { model.reset() }
    @objc private func toggleReposition() {
        overlay?.setRepositioning(!model.isRepositioning)
    }
    @objc private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        settings?.showWindow(nil)
        settings?.window?.makeKeyAndOrderFront(nil)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
