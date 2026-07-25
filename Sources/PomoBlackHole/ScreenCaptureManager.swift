import AppKit
import CoreMedia
import CoreVideo
import ScreenCaptureKit

@available(macOS 14.0, *)
final class ScreenCaptureManager: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "pomo.capture", qos: .userInteractive)
    private let lock = NSLock()
    private var latestBuffer: CVPixelBuffer?
    private(set) var displaySize = CGSize.zero

    var onFailure: (@Sendable () -> Void)?

    @MainActor
    func start(for screen: NSScreen) async throws {
        await stop()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw CaptureError.displayUnavailable
        }
        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayUnavailable
        }
        let ownBundleID = Bundle.main.bundleIdentifier
        let excludedApps = content.applications.filter { $0.bundleIdentifier == ownBundleID }
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(display.width)
        configuration.height = Int(display.height)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 3
        configuration.showsCursor = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        stream = newStream
        displaySize = CGSize(width: display.width, height: display.height)
        try await newStream.startCapture()
    }

    @MainActor
    func stop() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        lock.withLock { latestBuffer = nil }
    }

    func copyLatestPixelBuffer() -> CVPixelBuffer? {
        lock.withLock { latestBuffer }
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        onFailure?()
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen,
              sampleBuffer.isValid,
              let buffer = sampleBuffer.imageBuffer else { return }
        lock.withLock { latestBuffer = buffer }
    }

    enum CaptureError: Error {
        case displayUnavailable
    }
}
