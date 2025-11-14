import SwiftUI
import AVFoundation
import Vision
import UIKit
import QuartzCore

@available(iOS 15.0, *)
struct CameraKitCaptureView: View {
    @StateObject private var viewModel: CameraKitCaptureViewModel

    init(
        configuration: CameraKitConfiguration,
        onDismiss: @escaping () -> Void,
        onResult: @escaping ([UIImage], [UIImage]) -> Void,
        onError: @escaping (CameraKitError) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: CameraKitCaptureViewModel(
                configuration: configuration,
                onDismiss: onDismiss,
                onResult: onResult,
                onError: onError
            )
        )
    }

    var body: some View {
        ZStack {
            CameraKitPreviewView(session: viewModel.session)
                .ignoresSafeArea()
                .overlay(alignment: .center) {
                    if viewModel.shouldShowDetectionOverlay {
                        CameraKitDetectionOverlayView(
                            detectionRect: viewModel.detectionRect,
                            defaultHeight: viewModel.realtimeHeight
                        )
                        .padding(.horizontal, 20)
                    }
                }

            VStack {
                topBar
                Spacer()
                if viewModel.configuration.mode == .realTime {
                    realtimeControls
                }
                bottomBar
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .foregroundColor(.white)

            if viewModel.isProcessing {
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
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
        .fullScreenCover(isPresented: $viewModel.isShowingCropper) {
            if let image = viewModel.cropSourceImage {
                CameraKitCropView(
                    image: image,
                    defaultRect: viewModel.defaultCropRect,
                    onCancel: { viewModel.dismissCropper() },
                    onDone: { cropped in viewModel.completeCropping(with: cropped) }
                )
                .preferredColorScheme(.dark)
            } else {
                EmptyView().onAppear {
                    viewModel.dismissCropper()
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingPhotoPicker) {
            CameraKitPhotoPicker(
                onImage: { viewModel.handleImported(image: $0) },
                onCancel: { viewModel.isShowingPhotoPicker = false }
            )
        }
        .alert(item: $viewModel.alertData) { data in
            Alert(
                title: Text(data.title),
                message: Text(data.message),
                dismissButton: .default(Text(CameraKitStrings.localized("camera_done"))) {
                    if data.shouldDismiss {
                        viewModel.cancelFlow()
                    }
                }
            )
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { viewModel.cancelFlow() }) {
                Image(systemName: "xmark")
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }

            Spacer()

            if viewModel.isFlashSupported {
                Button(action: { viewModel.toggleFlashMode() }) {
                    Image(systemName: viewModel.flashIconName)
                        .padding(10)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .padding(.trailing, 8)
            }

            Button(action: { viewModel.switchCamera() }) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
        }
    }

    private var realtimeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CameraKitStrings.localized("camera_realtime_hint"))
                .font(.footnote)
            Slider(value: $viewModel.realtimeHeight, in: 0.3...0.95)
        }
    }

    private var bottomBar: some View {
        HStack {
            if viewModel.configuration.allowsPhotoLibraryImport {
                Button(action: { viewModel.presentPhotoPicker() }) {
                    Image(systemName: "photo.on.rectangle")
                        .frame(width: 44, height: 44)
                }
                .padding(.leading, 8)
            } else {
                Spacer()
            }

            Button(action: { viewModel.capturePhoto() }) {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 58, height: 58)
                    )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - View model

@available(iOS 15.0, *)
final class CameraKitCaptureViewModel: NSObject, ObservableObject {
    struct AlertData: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let shouldDismiss: Bool
    }

    let configuration: CameraKitConfiguration
    let session = AVCaptureSession()

    @Published var detectionRect: CGRect?
    @Published var realtimeHeight: CGFloat
    @Published var isProcessing = false
    @Published var isShowingCropper = false
    @Published var isShowingPhotoPicker = false
    @Published var cropSourceImage: UIImage?
    @Published var alertData: AlertData?

    @MainActor
    var shouldShowDetectionOverlay: Bool {
        configuration.mode == .realTime || configuration.enableLiveDetectionOverlay
    }

    @MainActor
    var isFlashSupported: Bool { flashAvailable }

    @MainActor
    var flashIconName: String {
        switch flashMode {
        case .auto:
            return "bolt.badge.a"
        case .on:
            return "bolt.fill"
        case .off:
            return "bolt.slash"
        @unknown default:
            return "bolt"
        }
    }

    @MainActor
    var defaultCropRect: CGRect {
        CGRect(
            x: 0.1,
            y: max(0.05, (1 - realtimeHeight) / 2),
            width: 0.8,
            height: realtimeHeight
        )
    }

    private let onDismiss: () -> Void
    private let onResult: ([UIImage], [UIImage]) -> Void
    fileprivate let onError: (CameraKitError) -> Void

    private let photoOutput = AVCapturePhotoOutput()
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "CameraKit.Session")
    private let detectionQueue = DispatchQueue(label: "CameraKit.Detection")
    private var currentDeviceInput: AVCaptureDeviceInput?
    private var hasStarted = false
    private var flashMode: AVCaptureDevice.FlashMode
    @Published private var flashAvailable: Bool = false
    private lazy var photoCaptureDelegate = PhotoCaptureDelegate(viewModel: self)
    private lazy var videoDataDelegate = VideoDataDelegate(viewModel: self)

    @MainActor
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
        self.realtimeHeight = configuration.defaultRealtimeHeight
        self.flashMode = configuration.defaultFlashMode
        super.init()
    }

    @MainActor
    func startSession() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await CameraKitPermissions.requestCameraPermission()
            guard granted else {
                self.alertData = AlertData(
                    title: CameraKitStrings.localized("camera_permission_title"),
                    message: CameraKitStrings.localized("camera_permission_denied"),
                    shouldDismiss: true
                )
                self.onError(.permissionDenied)
                return
            }
            self.configureSession()
        }
    }

    @MainActor
    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    @MainActor
    func cancelFlow() {
        stopSession()
        onDismiss()
    }

    @MainActor
    func toggleFlashMode() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        default:
            flashMode = .auto
        }
        objectWillChange.send()
    }

    @MainActor
    func switchCamera() {
        sessionQueue.async {
            let currentPosition = self.currentDeviceInput?.device.position
            let preferred: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferred) else {
                return
            }

            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                self.session.beginConfiguration()
                if let current = self.currentDeviceInput {
                    self.session.removeInput(current)
                }
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.currentDeviceInput = newInput
                }
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.flashAvailable = newDevice.isFlashAvailable
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertData = AlertData(
                        title: CameraKitStrings.localized("camera_error"),
                        message: error.localizedDescription,
                        shouldDismiss: false
                    )
                }
            }
        }
    }

    @MainActor
    func capturePhoto() {
        guard !isProcessing else { return }
        isProcessing = true
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        settings.flashMode = flashMode

        sessionQueue.async {
            self.photoOutput.capturePhoto(with: settings, delegate: self.photoCaptureDelegate)
        }
    }

    @MainActor
    func presentPhotoPicker() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let granted = await CameraKitPermissions.requestPhotoPermission()
            guard granted else {
                self.alertData = AlertData(
                    title: CameraKitStrings.localized("camera_photo_library_unavailable"),
                    message: CameraKitStrings.localized("camera_photo_library_denied_message"),
                    shouldDismiss: false
                )
                self.onError(.photoLibraryUnavailable)
                return
            }
            self.isShowingPhotoPicker = true
        }
    }

    @MainActor
    func dismissCropper() {
        isShowingCropper = false
        cropSourceImage = nil
        isProcessing = false
    }

    @MainActor
    func completeCropping(with image: UIImage) {
        isShowingCropper = false
        cropSourceImage = nil
        isProcessing = true
        deliver(images: [image])
    }

    @MainActor
    func handleImported(image: UIImage) {
        isShowingPhotoPicker = false
        isProcessing = true
        deliver(images: [image])
    }

    @MainActor
    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            do {
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                guard let captureDevice = device else {
                    DispatchQueue.main.async {
                        self.alertData = AlertData(
                            title: CameraKitStrings.localized("camera_error"),
                            message: CameraKitStrings.localized("camera_unavailable"),
                            shouldDismiss: true
                        )
                        self.onError(.cameraUnavailable)
                    }
                    return
                }

                let input = try AVCaptureDeviceInput(device: captureDevice)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentDeviceInput = input
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                }

                if self.configuration.enableLiveDetectionOverlay {
                    let videoOutput = AVCaptureVideoDataOutput()
                    videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    videoOutput.alwaysDiscardsLateVideoFrames = true
                    videoOutput.setSampleBufferDelegate(self.videoDataDelegate, queue: self.detectionQueue)
                    if self.session.canAddOutput(videoOutput) {
                        self.session.addOutput(videoOutput)
                        self.videoOutput = videoOutput
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertData = AlertData(
                        title: CameraKitStrings.localized("camera_error"),
                        message: error.localizedDescription,
                        shouldDismiss: true
                    )
                    self.onError(.cameraUnavailable)
                }
            }

            self.session.commitConfiguration()
            DispatchQueue.main.async {
                self.flashAvailable = self.currentDeviceInput?.device.isFlashAvailable ?? false
            }
            self.session.startRunning()
        }
    }


    @MainActor
    fileprivate func deliver(images: [UIImage]) {
        let configuration = self.configuration
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
                        message: CameraKitStrings.localized("camera_processing_failed"),
                        shouldDismiss: false
                    )
                    self.onError(.processingFailed)
                }
            }
        }
    }
}

// MARK: - Capture delegates

@available(iOS 15.0, *)
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    weak var viewModel: CameraKitCaptureViewModel?

    init(viewModel: CameraKitCaptureViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            Task { @MainActor [weak viewModel = viewModel] in
                guard let viewModel else { return }
                viewModel.isProcessing = false
                viewModel.alertData = CameraKitCaptureViewModel.AlertData(
                    title: CameraKitStrings.localized("camera_error"),
                    message: error.localizedDescription,
                    shouldDismiss: false
                )
                viewModel.onError(.captureFailed)
            }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor [weak viewModel = viewModel] in
                guard let viewModel else { return }
                viewModel.isProcessing = false
                viewModel.alertData = CameraKitCaptureViewModel.AlertData(
                    title: CameraKitStrings.localized("camera_error"),
                    message: CameraKitStrings.localized("camera_capture_failed"),
                    shouldDismiss: false
                )
                viewModel.onError(.captureFailed)
            }
            return
        }

        Task { @MainActor [weak viewModel = viewModel] in
            guard let viewModel else { return }
            if viewModel.configuration.allowsPostCaptureCropping {
                viewModel.isProcessing = false
                viewModel.cropSourceImage = image
                viewModel.isShowingCropper = true
            } else {
                viewModel.deliver(images: [image])
            }
        }
    }
}

@available(iOS 15.0, *)
private final class VideoDataDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    weak var viewModel: CameraKitCaptureViewModel?
    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handle(rectangles: request, error: error)
        }
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumConfidence = 0.5
        return request
    }()
    private var lastDetectionTime: TimeInterval = 0

    init(viewModel: CameraKitCaptureViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastDetectionTime > 0.2 else { return }
        lastDetectionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([rectangleRequest])
        } catch {
            Task { @MainActor [weak viewModel = viewModel] in
                viewModel?.detectionRect = nil
            }
        }
    }

    private func handle(rectangles request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNRectangleObservation],
              let best = results.max(by: { $0.confidence < $1.confidence }) else {
            Task { @MainActor [weak viewModel = viewModel] in
                viewModel?.detectionRect = nil
            }
            return
        }

        let converted = CGRect(
            x: best.boundingBox.origin.x,
            y: 1 - best.boundingBox.origin.y - best.boundingBox.size.height,
            width: best.boundingBox.size.width,
            height: best.boundingBox.size.height
        )

        Task { @MainActor [weak viewModel = viewModel] in
            viewModel?.detectionRect = converted
        }
    }
}

@available(iOS 15.0, *)
extension CameraKitCaptureViewModel: @unchecked Sendable {}

