#if targetEnvironment(macCatalyst)
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import Foundation

@available(iOS 15.0, *)
struct CameraKitMacImportView: View {
    enum ActivePicker: Identifiable {
        case photos
        case files

        var id: Int { hashValue }
    }

    struct AlertData: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    let configuration: CameraKitConfiguration
    let requiresCrop: Bool
    let onDismiss: () -> Void
    let onResult: ([UIImage], [UIImage]) -> Void
    let onError: (CameraKitError) -> Void

    @State private var activePicker: ActivePicker?
    @State private var cropSourceImage: UIImage?
    @State private var isShowingCropper = false
    @State private var isProcessing = false
    @State private var alertData: AlertData?

    private var defaultCropRect: CGRect {
        CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                HStack {
                    Button(action: { onDismiss() }) {
                        Image(systemName: "xmark")
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                }

                Spacer()

                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        Text(CameraKitStrings.localized("camera_mac_import_title"))
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                        Text(CameraKitStrings.localized("camera_mac_import_message"))
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        actionButton(
                            titleKey: "camera_mac_import_photos",
                            systemImage: "photo.on.rectangle"
                        ) {
                            activePicker = .photos
                        }

                        actionButton(
                            titleKey: "camera_mac_import_files",
                            systemImage: "folder"
                        ) {
                            activePicker = .files
                        }

                        Divider()
                            .background(Color.white.opacity(0.2))

                        cancelButton(titleKey: "camera_cancel", action: onDismiss)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Spacer()
            }
            .padding(32)

            if isProcessing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    CameraKitActivityIndicator()
                    Text(CameraKitStrings.localized("camera_processing"))
                        .foregroundColor(.white)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .photos:
                CameraKitMacPhotosPicker(
                    selectionLimit: requiresCrop ? 1 : 0,
                    onImages: handlePicked(images:),
                    onCancel: { activePicker = nil }
                )
            case .files:
                CameraKitMacDocumentPicker(
                    allowsMultipleSelection: !requiresCrop,
                    onImages: handlePicked(images:),
                    onCancel: { activePicker = nil }
                )
            }
        }
        .fullScreenCover(isPresented: $isShowingCropper) {
            if let image = cropSourceImage {
                CameraKitCropView(
                    image: image,
                    defaultRect: defaultCropRect,
                    onCancel: {
                        cropSourceImage = nil
                        isShowingCropper = false
                    },
                    onDone: { cropped in
                        cropSourceImage = nil
                        isShowingCropper = false
                        process(images: [cropped])
                    }
                )
                .preferredColorScheme(.dark)
            } else {
                EmptyView().onAppear {
                    cropSourceImage = nil
                    isShowingCropper = false
                }
            }
        }
        .alert(item: $alertData) { data in
            Alert(
                title: Text(data.title),
                message: Text(data.message),
                dismissButton: .default(Text(CameraKitStrings.localized("camera_done")))
            )
        }
    }

    @ViewBuilder
    private func actionButton(
        titleKey: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 28)
                Text(CameraKitStrings.localized(titleKey))
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .opacity(0.5)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
    }

    @ViewBuilder
    private func cancelButton(titleKey: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(CameraKitStrings.localized(titleKey))
                    .font(.body.weight(.semibold))
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundColor(.white.opacity(0.9))
    }

    private func handlePicked(images: [UIImage]) {
        activePicker = nil
        guard !images.isEmpty else { return }
        if requiresCrop, let first = images.first {
            cropSourceImage = first
            isShowingCropper = true
        } else {
            process(images: images)
        }
    }

    private func process(images: [UIImage]) {
        isProcessing = true
        Task.detached(priority: .userInitiated) {
            do {
                let processed = try CameraKitImageProcessor.process(images: images, configuration: configuration)
                await MainActor.run {
                    self.isProcessing = false
                    self.onResult(processed.processed, processed.originals)
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.alertData = AlertData(
                        title: CameraKitStrings.localized("camera_error"),
                        message: CameraKitStrings.localized("camera_processing_failed")
                    )
                    self.onError(.processingFailed)
                }
            }
        }
    }
}

// MARK: - Photo picker

@available(iOS 15.0, *)
private struct CameraKitMacPhotosPicker: UIViewControllerRepresentable {
    let selectionLimit: Int
    let onImages: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: CameraKitMacPhotosPicker

        init(parent: CameraKitMacPhotosPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else {
                parent.onCancel()
                return
            }

            var loadedImages: [UIImage] = []
            let dispatchGroup = DispatchGroup()

            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    dispatchGroup.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let image = object as? UIImage {
                            loadedImages.append(image)
                        }
                        dispatchGroup.leave()
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                if loadedImages.isEmpty {
                    self.parent.onCancel()
                } else {
                    self.parent.onImages(loadedImages)
                }
            }
        }
    }
}

// MARK: - Document picker

@available(iOS 15.0, *)
private struct CameraKitMacDocumentPicker: UIViewControllerRepresentable {
    let allowsMultipleSelection: Bool
    let onImages: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: CameraKitMacDocumentPicker

        init(parent: CameraKitMacDocumentPicker) {
            self.parent = parent
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            var images: [UIImage] = []
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }

            if images.isEmpty {
                parent.onCancel()
            } else {
                parent.onImages(images)
            }
        }
    }
}
#endif
