import SwiftUI
import UIKit

/// Entry point button that wraps CameraKit in a customizable label.
@available(iOS 15.0, *)
public struct CameraKitLauncher<Label: View>: View {
    private let configuration: CameraKitConfiguration
    private let onResult: ([UIImage]) -> Void
    private let onOriginalImageResult: (([UIImage]) -> Void)?
    private let onCancel: () -> Void
    private let onError: (CameraKitError) -> Void
    private let label: () -> Label

    @State private var isPresented = false

    public init(
        configuration: CameraKitConfiguration,
        onResult: @escaping ([UIImage]) -> Void,
        onOriginalImageResult: (([UIImage]) -> Void)? = nil,
        onCancel: @escaping () -> Void,
        onError: @escaping (CameraKitError) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.configuration = configuration
        self.onResult = onResult
        self.onOriginalImageResult = onOriginalImageResult
        self.onCancel = onCancel
        self.onError = onError
        self.label = label
    }

    public var body: some View {
        Button(action: { isPresented = true }) {
            label()
        }
        .fullScreenCover(isPresented: $isPresented) {
            CameraKitContainerView(
                configuration: configuration,
                isPresented: $isPresented,
                onResult: onResult,
                onOriginalImageResult: onOriginalImageResult,
                onCancel: onCancel,
                onError: onError
            )
        }
    }
}

/// Convenience launcher that uses a default system button.
@available(iOS 15.0, *)
public struct CameraKitLauncherButton: View {
    private let configuration: CameraKitConfiguration
    private let title: String
    private let onResult: ([UIImage]) -> Void
    private let onOriginalImageResult: (([UIImage]) -> Void)?
    private let onCancel: () -> Void
    private let onError: (CameraKitError) -> Void

    public init(
        configuration: CameraKitConfiguration,
        title: String = CameraKitStrings.localized("camera_launch_button"),
        onResult: @escaping ([UIImage]) -> Void,
        onOriginalImageResult: (([UIImage]) -> Void)? = nil,
        onCancel: @escaping () -> Void,
        onError: @escaping (CameraKitError) -> Void
    ) {
        self.configuration = configuration
        self.title = title
        self.onResult = onResult
        self.onOriginalImageResult = onOriginalImageResult
        self.onCancel = onCancel
        self.onError = onError
    }

    public var body: some View {
        CameraKitLauncher(
            configuration: configuration,
            onResult: onResult,
            onOriginalImageResult: onOriginalImageResult,
            onCancel: onCancel,
            onError: onError
        ) {
            Label(title, systemImage: "camera")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.accentColor.opacity(0.2)))
        }
    }
}

@available(iOS 15.0, *)
struct CameraKitContainerView: View {
    @Environment(\.dismiss) private var dismiss

    let configuration: CameraKitConfiguration
    @Binding var isPresented: Bool
    let onResult: ([UIImage]) -> Void
    let onOriginalImageResult: (([UIImage]) -> Void)?
    let onCancel: () -> Void
    let onError: (CameraKitError) -> Void

    var body: some View {
        Group {
#if targetEnvironment(macCatalyst)
            CameraKitMacImportView(
                configuration: configuration,
                requiresCrop: !configuration.mode.usesDocumentScanner,
                onDismiss: { cancelFlow() },
                onResult: handleResults(processed:originals:),
                onError: onError
            )
#else
            if configuration.mode.usesDocumentScanner {
                CameraKitDocumentScannerView(
                    configuration: configuration,
                    onDismiss: { cancelFlow() },
                    onResult: handleResults(processed:originals:),
                    onError: onError
                )
            } else {
                CameraKitCaptureView(
                    configuration: configuration,
                    onDismiss: { cancelFlow() },
                    onResult: handleResults(processed:originals:),
                    onError: onError
                )
            }
#endif
        }
        .ckInteractiveDismissDisabled(true)
    }

    private func cancelFlow() {
        isPresented = false
        dismiss()
        onCancel()
    }

    private func handleResults(processed: [UIImage], originals: [UIImage]) {
        isPresented = false
        dismiss()
        onResult(processed)
        onOriginalImageResult?(originals)
    }
}
