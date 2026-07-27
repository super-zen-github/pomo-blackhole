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
            self?.settings?.refreshLocalization()
        }
        refreshStatusTitle()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "circle.dotted",
            accessibilityDescription: L.text("Black Hole Pomodoro")
        )
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
        case .idle: L.text("Not started")
        case .focus: L.text("Focusing")
        case .shortBreak: L.text("Short break")
        case .longBreak: L.text("Long break")
        case .paused: L.text("Paused")
        case .completing: L.text("Collapsing")
        }
        let info = NSMenuItem(title: "\(phaseName) · \(formatted(model.remaining))", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        menu.addItem(.separator())

        let primaryTitle = switch model.phase {
        case .idle: L.text("Start Focus")
        case .paused: L.text("Resume")
        case .focus, .shortBreak, .longBreak: L.text("Pause")
        case .completing: L.text("Finishing…")
        }
        menu.addItem(withTitle: primaryTitle, action: #selector(toggleTimer), keyEquivalent: " ")
        menu.addItem(withTitle: L.text("Skip Current Phase"), action: #selector(skip), keyEquivalent: "")
        menu.addItem(withTitle: L.text("Reset"), action: #selector(reset), keyEquivalent: "")
        menu.addItem(.separator())

        let reposition = menu.addItem(
            withTitle: model.isRepositioning ? L.text("Finish Moving") : L.text("Move Black Hole"),
            action: #selector(toggleReposition),
            keyEquivalent: ""
        )
        reposition.state = model.isRepositioning ? .on : .off
        menu.addItem(withTitle: L.text("Settings…"), action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: L.text("Quit Black Hole Pomodoro"), action: #selector(quit), keyEquivalent: "q")

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
