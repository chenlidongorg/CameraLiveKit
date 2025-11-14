import Foundation
import SwiftUI
import AVFoundation

/// Represents the workflow that CameraKit should follow.
public enum CameraKitMode: Equatable, Sendable {
    case realTime
    case photo
    case photoWithCrop
    case scanSingle
    case scanBatch

    var usesDocumentScanner: Bool {
        switch self {
        case .scanSingle, .scanBatch:
            return true
        default:
            return false
        }
    }
}

/// Extra data that will be returned alongside capture results.
public struct CameraKitContext: Equatable, Sendable {
    public var identifier: String
    public var payload: [String: String]

    public init(identifier: String, payload: [String: String] = [:]) {
        self.identifier = identifier
        self.payload = payload
    }
}

/// Controls the output quality and down-scaling strategies.
public struct CameraKitOutputQuality: Equatable, Sendable {
    public var targetResolution: CGSize?
    public var compressionQuality: CGFloat
    public var maxOutputWidth: CGFloat?

    public init(
        targetResolution: CGSize? = nil,
        compressionQuality: CGFloat = 0.85,
        maxOutputWidth: CGFloat? = nil
    ) {
        self.targetResolution = targetResolution
        self.compressionQuality = compressionQuality
        self.maxOutputWidth = maxOutputWidth
    }
}

/// Image enhancement strategies.
public enum CameraKitEnhancement: Equatable, Sendable {
    case none
    case auto
    case grayscale
}

/// All entry configuration for CameraKit is wrapped in this struct.
@available(iOS 15.0, *)
public struct CameraKitConfiguration: Equatable, Sendable {
    public var mode: CameraKitMode
    public var defaultRealtimeHeight: CGFloat
    public var enableLiveDetectionOverlay: Bool
    public var allowsPostCaptureCropping: Bool
    public var enhancement: CameraKitEnhancement
    public var allowsPhotoLibraryImport: Bool
    public var outputQuality: CameraKitOutputQuality
    public var defaultFlashMode: AVCaptureDevice.FlashMode
    public var context: CameraKitContext?

    public init(
        mode: CameraKitMode,
        defaultRealtimeHeight: CGFloat = 0.8,
        enableLiveDetectionOverlay: Bool = true,
        allowsPostCaptureCropping: Bool = false,
        enhancement: CameraKitEnhancement = .auto,
        allowsPhotoLibraryImport: Bool = false,
        outputQuality: CameraKitOutputQuality = .init(),
        defaultFlashMode: AVCaptureDevice.FlashMode = .auto,
        context: CameraKitContext? = nil
    ) {
        self.mode = mode
        self.defaultRealtimeHeight = max(0.1, min(1.0, defaultRealtimeHeight))
        self.enableLiveDetectionOverlay = enableLiveDetectionOverlay
        self.allowsPostCaptureCropping = allowsPostCaptureCropping || mode == .photoWithCrop
        self.enhancement = enhancement
        self.allowsPhotoLibraryImport = allowsPhotoLibraryImport
        self.outputQuality = outputQuality
        self.defaultFlashMode = defaultFlashMode
        self.context = context
    }
}

/// Domain errors surfaced to the host application.
public enum CameraKitError: LocalizedError, Equatable, Sendable {
    case permissionDenied
    case cameraUnavailable
    case captureFailed
    case processingFailed
    case photoLibraryUnavailable
    case visionKitUnavailable

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return CameraKitStrings.localized("camera_permission_denied")
        case .cameraUnavailable:
            return CameraKitStrings.localized("camera_unavailable")
        case .captureFailed:
            return CameraKitStrings.localized("camera_capture_failed")
        case .processingFailed:
            return CameraKitStrings.localized("camera_processing_failed")
        case .photoLibraryUnavailable:
            return CameraKitStrings.localized("camera_photo_library_unavailable")
        case .visionKitUnavailable:
            return CameraKitStrings.localized("camera_visionkit_unavailable")
        }
    }
}
