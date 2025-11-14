import SwiftUI

struct CameraKitDetectionOverlayView: View {
    var detectionRect: CGRect?
    var defaultHeight: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            if let rect = detectionRect {
                overlayPath(for: rect, width: availableWidth, height: availableHeight)
                    .stroke(Color.yellow, lineWidth: 3)
                    .animation(.easeInOut(duration: 0.2), value: rect)
            } else {
                let width = availableWidth * 0.8
                let height = availableHeight * defaultHeight
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [12, 8]))
                    .frame(width: width, height: height)
                    .foregroundColor(.white.opacity(0.9))
                    .position(x: availableWidth / 2, y: availableHeight / 2)
            }
        }
        .allowsHitTesting(false)
    }

    private func overlayPath(for rect: CGRect, width: CGFloat, height: CGFloat) -> Path {
        let scaledRect = CGRect(
            x: rect.origin.x * width,
            y: rect.origin.y * height,
            width: rect.size.width * width,
            height: rect.size.height * height
        )
        var path = Path()
        let cornerRadius: CGFloat = 18
        path.addRoundedRect(in: scaledRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}
