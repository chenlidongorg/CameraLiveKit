import SwiftUI
import UIKit

#if canImport(VisionKit)
import VisionKit

@available(iOS 15.0, *)
struct CameraKitDocumentScannerView: UIViewControllerRepresentable {
    let configuration: CameraKitConfiguration
    let onDismiss: () -> Void
    let onResult: ([UIImage], [UIImage]) -> Void
    let onError: (CameraKitError) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            configuration: configuration,
            onDismiss: onDismiss,
            onResult: onResult,
            onError: onError
        )
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, @MainActor VNDocumentCameraViewControllerDelegate {
        let configuration: CameraKitConfiguration
        let onDismiss: () -> Void
        let onResult: ([UIImage], [UIImage]) -> Void
        let onError: (CameraKitError) -> Void

        init(
            configuration: CameraKitConfiguration,
            onDismiss: @escaping () -> Void,
            onResult: @escaping ([UIImage], [UIImage]) -> Void,
            onError: @escaping (CameraKitError) -> Void
        ) {
            self.configuration = configuration
            self.onDismiss = onDismiss
            self.onResult = onResult
            self.onError = onError
        }

        @MainActor func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.onDismiss()
            }
        }

        @MainActor func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true) {
                self.onError(.processingFailed)
                self.onDismiss()
            }
        }

        @MainActor func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                images.append(image)
            }

            controller.dismiss(animated: true) {
                do {
                    let processed = try CameraKitImageProcessor.process(
                        images: images,
                        configuration: self.configuration
                    )
                    self.onResult(processed.processed, processed.originals)
                } catch {
                    self.onError(.processingFailed)
                    self.onDismiss()
                }
            }
        }
    }
}
#else
@available(iOS 15.0, *)
struct CameraKitDocumentScannerView: View {
    let configuration: CameraKitConfiguration
    let onDismiss: () -> Void
    let onResult: ([UIImage], [UIImage]) -> Void
    let onError: (CameraKitError) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(CameraKitStrings.localized("camera_visionkit_unavailable"))
                .foregroundColor(.secondary)
                .padding()
            Button(CameraKitStrings.localized("camera_done")) {
                onError(.visionKitUnavailable)
                onDismiss()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.9))
    }
}
#endif
