import AppKit
import MetalKit

@MainActor
final class OverlayController: NSObject {
    private let model: AppModel
    private let panel: NSPanel
    private let metalView: MTKView
    private let capture = ScreenCaptureManager()
    private var renderer: BlackHoleRenderer?
    private var completionStartedAt: Date?
    private var activeScreen: NSScreen?
    private var captureTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let positionKey = "blackhole.normalizedPosition"

    init(model: AppModel) {
        self.model = model
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        metalView = MTKView(frame: panel.contentView?.bounds ?? .zero)
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.ignoresMouseEvents = true
        panel.contentView = metalView
        metalView.wantsLayer = true
        metalView.layer?.isOpaque = false
        metalView.layer?.backgroundColor = NSColor.clear.cgColor

        renderer = BlackHoleRenderer(view: metalView, capture: capture)
        capture.onFailure = { [weak self] in
            Task { @MainActor in self?.fallBackToOverlay() }
        }
        restorePosition()
        panel.orderFrontRegardless()
        model.onUpdate = { [weak self] in self?.update() }
        model.onCompletionAnimation = { [weak self] in
            self?.completionStartedAt = Date()
        }
        update()
    }

    func setRepositioning(_ enabled: Bool) {
        model.isRepositioning = enabled
        panel.ignoresMouseEvents = !enabled
        if enabled {
            panel.level = .popUpMenu
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.level = .floating
            savePosition()
        }
    }

    func update() {
        let shouldShow = model.phase == .focus || model.phase == .paused || model.phase == .completing
        if shouldShow {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
            stopCapture()
            return
        }

        let screen = panel.screen ?? NSScreen.main
        guard let screen else { return }
        resize(on: screen)

        if model.visualMode == .liveDistortion {
            startCaptureIfNeeded(on: screen)
        } else {
            stopCapture()
        }

        let elapsed = completionStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let completion = model.phase == .completing ? min(1, elapsed / 1.6) : 0
        if model.phase != .completing { completionStartedAt = nil }
        renderer?.update(RendererState(
            progress: Float(model.progress),
            completion: Float(completion),
            liveDistortion: model.visualMode == .liveDistortion,
            windowFrame: panel.frame,
            screenFrame: screen.frame
        ))
    }

    private func resize(on screen: NSScreen) {
        let maxDiameter = screen.visibleFrame.height < screen.visibleFrame.width
            ? screen.visibleFrame.height / 3
            : screen.visibleFrame.width / 3
        let diameter = max(220, maxDiameter)
        let renderingSide = diameter / 0.72
        guard abs(panel.frame.width - renderingSide) > 1 || activeScreen !== screen else { return }
        let center = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        var origin = CGPoint(x: center.x - renderingSide / 2, y: center.y - renderingSide / 2)
        origin.x = min(max(origin.x, screen.frame.minX), screen.frame.maxX - renderingSide)
        origin.y = min(max(origin.y, screen.frame.minY), screen.frame.maxY - renderingSide)
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: renderingSide, height: renderingSide)), display: true)
        metalView.frame = panel.contentView?.bounds ?? .zero
    }

    private func startCaptureIfNeeded(on screen: NSScreen) {
        guard activeScreen !== screen || captureTask == nil else { return }
        captureTask?.cancel()
        activeScreen = screen
        captureTask = Task {
            do {
                try await capture.start(for: screen)
                UserDefaults.standard.removeObject(forKey: "capture.lastError")
            } catch {
                NSLog("Black hole screen capture failed: %@", String(describing: error))
                UserDefaults.standard.set(String(describing: error), forKey: "capture.lastError")
                fallBackToOverlay()
            }
        }
    }

    private func stopCapture() {
        captureTask?.cancel()
        captureTask = nil
        activeScreen = nil
        Task { await capture.stop() }
    }

    private func fallBackToOverlay() {
        model.visualMode = .overlayOnly
        stopCapture()
        update()
    }

    private func savePosition() {
        guard let screen = panel.screen else { return }
        let x = (panel.frame.midX - screen.frame.minX) / screen.frame.width
        let y = (panel.frame.midY - screen.frame.minY) / screen.frame.height
        defaults.set([x, y], forKey: positionKey)
    }

    private func restorePosition() {
        guard let screen = NSScreen.main else { return }
        let normalized = defaults.array(forKey: positionKey) as? [Double] ?? [0.78, 0.70]
        let x = screen.frame.minX + screen.frame.width * CGFloat(normalized[safe: 0] ?? 0.78)
        let y = screen.frame.minY + screen.frame.height * CGFloat(normalized[safe: 1] ?? 0.70)
        panel.setFrameOrigin(NSPoint(x: x - panel.frame.width / 2, y: y - panel.frame.height / 2))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
