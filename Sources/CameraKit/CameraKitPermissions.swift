import AVFoundation
#if canImport(Photos)
import Photos
#endif

@available(iOS 15.0, *)
enum CameraKitPermissions {
    static func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    #if canImport(Photos)
    static func requestPhotoPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    switch newStatus {
                    case .authorized, .limited:
                        continuation.resume(returning: true)
                    default:
                        continuation.resume(returning: false)
                    }
                }
            }
        default:
            return false
        }
    }
    #else
    static func requestPhotoPermission() async -> Bool { false }
    #endif
}
