import Foundation
import SwiftUI

/// Represents the workflow that CameraKit should follow.
public enum CameraKitMode: Equatable, Sendable {
    /// Standard capture flow that always routes the user to a crop editor after shooting.
    case captureWithCrop
    /// Document scanning flow that leverages VisionKit / VNDocumentCamera when available.
    case scan

    var usesDocumentScanner: Bool {
        switch self {
        case .scan:
            return true
        case .captureWithCrop:
            return false
        }
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
    public var enhancement: CameraKitEnhancement
    public var allowsPhotoLibraryImport: Bool
    public var maxOutputWidth: CGFloat?

    public init(
        mode: CameraKitMode,
        enhancement: CameraKitEnhancement = .auto,
        allowsPhotoLibraryImport: Bool = false,
        maxOutputWidth: CGFloat? = nil
    ) {
        self.mode = mode
        self.enhancement = enhancement
        self.allowsPhotoLibraryImport = allowsPhotoLibraryImport
        if let maxOutputWidth, maxOutputWidth <= 0 {
            self.maxOutputWidth = nil
        } else {
            self.maxOutputWidth = maxOutputWidth
        }
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
