import SwiftUI
import UIKit

@available(iOS 15.0, *)
struct CameraKitCropView: View {
    let image: UIImage
    let defaultRect: CGRect
    let onCancel: () -> Void
    let onDone: (UIImage) -> Void

    @State private var normalizedRect: CGRect
    @State private var draggingRect: CGRect?

    init(
        image: UIImage,
        defaultRect: CGRect,
        onCancel: @escaping () -> Void,
        onDone: @escaping (UIImage) -> Void
    ) {
        self.image = image
        self.defaultRect = defaultRect
        self.onCancel = onCancel
        self.onDone = onDone
        _normalizedRect = State(initialValue: defaultRect)
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    cropOverlay(in: geometry.size)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(CameraKitStrings.localized("camera_cancel"), action: onCancel)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(CameraKitStrings.localized("camera_crop_done")) {
                        guard let cropped = CameraKitImageProcessor.crop(image: image, rect: normalizedRect) else {
                            onCancel()
                            return
                        }
                        onDone(cropped)
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(CameraKitStrings.localized("camera_crop_reset")) {
                        normalizedRect = defaultRect
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func cropOverlay(in size: CGSize) -> some View {
        let actualRect = CGRect(
            x: normalizedRect.origin.x * size.width,
            y: normalizedRect.origin.y * size.height,
            width: normalizedRect.size.width * size.width,
            height: normalizedRect.size.height * size.height
        )

        let overlay = Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRoundedRect(in: actualRect, cornerSize: CGSize(width: 18, height: 18))
        }
        .fill(Color.black.opacity(0.5), style: FillStyle())

        return ZStack {
            overlay
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: actualRect.width, height: actualRect.height)
                .position(x: actualRect.midX, y: actualRect.midY)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if draggingRect == nil {
                                draggingRect = normalizedRect
                            }
                            let translation = CGSize(
                                width: value.translation.width / size.width,
                                height: value.translation.height / size.height
                            )
                            moveCrop(with: translation)
                        }
                        .onEnded { _ in
                            draggingRect = nil
                        }
                )
            cropHandles(size: size)
        }
        .animation(.easeInOut(duration: 0.2), value: normalizedRect)
    }

    private func cropHandles(size: CGSize) -> some View {
        let handleSize: CGFloat = 28
        let corners = [
            CGPoint(x: normalizedRect.minX, y: normalizedRect.minY),
            CGPoint(x: normalizedRect.maxX, y: normalizedRect.minY),
            CGPoint(x: normalizedRect.minX, y: normalizedRect.maxY),
            CGPoint(x: normalizedRect.maxX, y: normalizedRect.maxY)
        ]

        return ForEach(Array(corners.enumerated()), id: \.offset) { element in
            let index = element.offset
            let point = element.element
            Circle()
                .fill(Color.white)
                .frame(width: handleSize, height: handleSize)
                .position(
                    x: point.x * size.width,
                    y: point.y * size.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translated = CGPoint(
                                x: (value.location.x / size.width),
                                y: (value.location.y / size.height)
                            )
                            adjustCorner(index: index, to: translated)
                        }
                )
        }
    }

    private func moveCrop(with translation: CGSize) {
        let baseRect = draggingRect ?? normalizedRect
        var newRect = baseRect
        newRect.origin.x += translation.width
        newRect.origin.y += translation.height
        newRect.origin.x = max(0, min(1 - newRect.width, newRect.origin.x))
        newRect.origin.y = max(0, min(1 - newRect.height, newRect.origin.y))
        normalizedRect = newRect
    }

    private func adjustCorner(index: Int, to point: CGPoint) {
        var rect = normalizedRect
        let minSize: CGFloat = 0.1
        switch index {
        case 0: // top-left
            rect.origin.x = max(0, min(point.x, rect.maxX - minSize))
            rect.origin.y = max(0, min(point.y, rect.maxY - minSize))
            rect.size.width = rect.maxX - rect.origin.x
            rect.size.height = rect.maxY - rect.origin.y
        case 1: // top-right
            let newMaxX = max(rect.minX + minSize, min(1, point.x))
            rect.size.width = newMaxX - rect.minX
            rect.origin.y = max(0, min(point.y, rect.maxY - minSize))
            rect.size.height = rect.maxY - rect.origin.y
        case 2: // bottom-left
            rect.origin.x = max(0, min(point.x, rect.maxX - minSize))
            let newMaxY = max(rect.minY + minSize, min(1, point.y))
            rect.size.width = rect.maxX - rect.origin.x
            rect.size.height = newMaxY - rect.minY
        default: // bottom-right
            let newMaxX = max(rect.minX + minSize, min(1, point.x))
            let newMaxY = max(rect.minY + minSize, min(1, point.y))
            rect.size.width = newMaxX - rect.minX
            rect.size.height = newMaxY - rect.minY
        }
        normalizedRect = rect.standardized
    }
}
