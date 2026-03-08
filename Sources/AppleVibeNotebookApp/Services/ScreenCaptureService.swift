import Foundation
import CoreGraphics
import AVFoundation

#if os(macOS)
import ScreenCaptureKit
import AppKit

// MARK: - Screen Capture Service (macOS)

/// Service for capturing screen content for AI vision analysis.
/// Uses ScreenCaptureKit to capture windows, screens, or regions.
@Observable
@MainActor
public final class ScreenCaptureService: NSObject {

    // MARK: - Types

    public enum CaptureMode: String, CaseIterable, Identifiable, Sendable {
        case fullScreen = "Full Screen"
        case window = "Window"
        case region = "Region"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .fullScreen: return "rectangle.dashed"
            case .window: return "macwindow"
            case .region: return "crop"
            }
        }
    }

    public enum CaptureState: Sendable {
        case idle
        case requesting
        case ready
        case capturing
        case captured(Data)
        case error(String)
    }

    public struct CapturedScreen: Identifiable, Sendable {
        public let id = UUID()
        public let imageData: Data
        public let timestamp: Date
        public let mode: CaptureMode
        public let windowTitle: String?
    }

    // MARK: - Properties

    public private(set) var state: CaptureState = .idle
    public private(set) var availableWindows: [SCWindow] = []
    public private(set) var availableDisplays: [SCDisplay] = []
    public private(set) var captureHistory: [CapturedScreen] = []

    public var selectedWindow: SCWindow?
    public var selectedDisplay: SCDisplay?
    public var captureMode: CaptureMode = .window

    private var streamConfiguration: SCStreamConfiguration?
    private var contentFilter: SCContentFilter?

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - Authorization & Discovery

    /// Request screen capture permission and discover available content
    public func requestAccess() async -> Bool {
        state = .requesting

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            availableWindows = content.windows.filter { window in
                window.frame.width > 100 && window.frame.height > 100
            }.sorted { ($0.owningApplication?.applicationName ?? "") < ($1.owningApplication?.applicationName ?? "") }

            availableDisplays = content.displays

            if let firstDisplay = content.displays.first {
                selectedDisplay = firstDisplay
            }

            state = .ready
            return true

        } catch {
            state = .error("Screen capture permission denied: \(error.localizedDescription)")
            return false
        }
    }

    /// Refresh available windows
    public func refreshAvailableContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            availableWindows = content.windows.filter { window in
                window.frame.width > 100 && window.frame.height > 100
            }

            availableDisplays = content.displays

        } catch {
            // Silently fail on refresh
        }
    }

    // MARK: - Capture

    /// Capture screen content based on current mode
    public func capture() async throws -> Data {
        state = .capturing

        let imageData: Data

        switch captureMode {
        case .fullScreen:
            imageData = try await captureFullScreen()
        case .window:
            imageData = try await captureWindow()
        case .region:
            imageData = try await captureRegion()
        }

        let captured = CapturedScreen(
            imageData: imageData,
            timestamp: Date(),
            mode: captureMode,
            windowTitle: selectedWindow?.title
        )

        captureHistory.insert(captured, at: 0)
        if captureHistory.count > 10 {
            captureHistory = Array(captureHistory.prefix(10))
        }

        state = .captured(imageData)
        return imageData
    }

    /// Capture full screen
    private func captureFullScreen() async throws -> Data {
        guard let display = selectedDisplay ?? availableDisplays.first else {
            throw CaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        return try await captureWithFilter(filter, size: CGSize(width: display.width, height: display.height))
    }

    /// Capture a specific window
    private func captureWindow() async throws -> Data {
        guard let window = selectedWindow else {
            throw CaptureError.noWindowSelected
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        return try await captureWithFilter(filter, size: window.frame.size)
    }

    /// Capture a region (interactive selection)
    private func captureRegion() async throws -> Data {
        return try await captureFullScreen()
    }

    /// Perform capture with given filter
    private func captureWithFilter(_ filter: SCContentFilter, size: CGSize) async throws -> Data {
        let config = SCStreamConfiguration()
        config.width = Int(size.width)
        config.height = Int(size.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.scalesToFit = true

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        guard let pngData = image.pngData() else {
            throw CaptureError.imageConversionFailed
        }

        return pngData
    }

    /// Quick capture with default settings
    public func quickCapture() async throws -> Data {
        if case .idle = state {
            let _ = await requestAccess()
        }

        if selectedWindow == nil && captureMode == .window {
            selectedWindow = availableWindows.first { window in
                let appName = window.owningApplication?.applicationName ?? ""
                return !appName.contains("Finder") && !appName.contains("Dock")
            }
        }

        return try await capture()
    }

    /// Clear capture history
    public func clearHistory() {
        captureHistory.removeAll()
        if case .captured(_) = state {
            state = .ready
        }
    }

    // MARK: - Errors

    public enum CaptureError: Error, LocalizedError {
        case noDisplayAvailable
        case noWindowSelected
        case capturePermissionDenied
        case imageConversionFailed
        case captureFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noDisplayAvailable:
                return "No display available for capture"
            case .noWindowSelected:
                return "No window selected for capture"
            case .capturePermissionDenied:
                return "Screen capture permission denied. Enable in System Settings > Privacy > Screen Recording"
            case .imageConversionFailed:
                return "Failed to convert captured image"
            case .captureFailed(let msg):
                return "Capture failed: \(msg)"
            }
        }
    }
}

// MARK: - CGImage Extension

extension CGImage {
    func pngData() -> Data? {
        let bitmap = NSBitmapImageRep(cgImage: self)
        return bitmap.representation(using: .png, properties: [:])
    }
}

#else

// MARK: - Screen Capture Service (iOS Stub)

/// Stub implementation for iOS - screen capture requires user interaction on iOS
@Observable
@MainActor
public final class ScreenCaptureService: NSObject {

    public enum CaptureMode: String, CaseIterable, Identifiable, Sendable {
        case fullScreen = "Full Screen"
        case window = "Window"
        case region = "Region"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .fullScreen: return "rectangle.dashed"
            case .window: return "rectangle.on.rectangle"
            case .region: return "crop"
            }
        }
    }

    public enum CaptureState: Sendable {
        case idle
        case requesting
        case ready
        case capturing
        case captured(Data)
        case error(String)
    }

    public struct CapturedScreen: Identifiable, Sendable {
        public let id = UUID()
        public let imageData: Data
        public let timestamp: Date
        public let mode: CaptureMode
        public let windowTitle: String?
    }

    public private(set) var state: CaptureState = .idle
    public private(set) var captureHistory: [CapturedScreen] = []
    public var captureMode: CaptureMode = .fullScreen

    public override init() {
        super.init()
    }

    public func requestAccess() async -> Bool {
        state = .error("Screen capture is not available on iOS")
        return false
    }

    public func refreshAvailableContent() async {
        // Not available on iOS
    }

    public func capture() async throws -> Data {
        throw CaptureError.notAvailableOnIOS
    }

    public func quickCapture() async throws -> Data {
        throw CaptureError.notAvailableOnIOS
    }

    public func clearHistory() {
        captureHistory.removeAll()
    }

    public enum CaptureError: Error, LocalizedError {
        case notAvailableOnIOS
        case noDisplayAvailable
        case noWindowSelected
        case capturePermissionDenied
        case imageConversionFailed
        case captureFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notAvailableOnIOS:
                return "Screen capture is not available on iOS. Use screenshot sharing instead."
            case .noDisplayAvailable:
                return "No display available for capture"
            case .noWindowSelected:
                return "No window selected for capture"
            case .capturePermissionDenied:
                return "Screen capture permission denied"
            case .imageConversionFailed:
                return "Failed to convert captured image"
            case .captureFailed(let msg):
                return "Capture failed: \(msg)"
            }
        }
    }
}

#endif
