import Foundation
import SwiftUI
import CoreImage
import UIKit

@available(iOS 15.0, *)
enum CameraKitImageProcessor {
    private static let ciContext = CIContext(options: nil)

    static func process(
        images: [UIImage],
        configuration: CameraKitConfiguration
    ) throws -> (processed: [UIImage], originals: [UIImage]) {
        var processed: [UIImage] = []
        var originals: [UIImage] = []

        for image in images {
            guard let normalized = image.normalizedOrientation() else {
                throw CameraKitError.processingFailed
            }
            let enhanced = enhance(image: normalized, mode: configuration.enhancement)
            let resized = resizeIfNeeded(image: enhanced, maxWidth: configuration.maxOutputWidth)
            processed.append(resized)
            originals.append(normalized)
        }

        return (processed, originals)
    }

    static func crop(image: UIImage, rect: CGRect) -> UIImage? {
        guard let normalized = image.normalizedOrientation(),
              let cgImage = normalized.cgImage else {
            return nil
        }

        let constrained = rect.standardized.constrainedToUnit()
        let x = constrained.origin.x * CGFloat(cgImage.width)
        let y = constrained.origin.y * CGFloat(cgImage.height)
        let width = constrained.size.width * CGFloat(cgImage.width)
        let height = constrained.size.height * CGFloat(cgImage.height)
        let cropRect = CGRect(x: x, y: y, width: width, height: height)

        guard let cropped = cgImage.cropping(to: cropRect.integral) else {
            return nil
        }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: normalized.imageOrientation)
    }

    private static func resizeIfNeeded(image: UIImage, maxWidth: CGFloat?) -> UIImage {
        guard let maxWidth, maxWidth > 0, image.size.width > maxWidth else {
            return image
        }

        let ratio = maxWidth / image.size.width
        let targetSize = CGSize(width: maxWidth, height: image.size.height * ratio)

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = resized.jpegData(compressionQuality: 0.85),
              let recomposed = UIImage(data: data) else {
            return resized
        }
        return recomposed
    }

    private static func enhance(image: UIImage, mode: CameraKitEnhancement) -> UIImage {
        guard mode != .none, let ciImage = CIImage(image: image) else {
            return image
        }

        let outputImage: CIImage
        switch mode {
        case .auto:
            outputImage = ciImage
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputBrightnessKey: 0.0,
                    kCIInputContrastKey: 1.1,
                    kCIInputSaturationKey: 1.0
                ])
        case .grayscale:
            outputImage = ciImage
                .applyingFilter("CIPhotoEffectMono", parameters: [:])
        case .none:
            return image
        }

        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage? {
        if imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage
    }
}

private extension CGRect {
    func constrainedToUnit() -> CGRect {
        var rect = self
        rect.origin.x = max(0, min(1, rect.origin.x))
        rect.origin.y = max(0, min(1, rect.origin.y))
        rect.size.width = max(0.01, min(1 - rect.origin.x, rect.size.width))
        rect.size.height = max(0.01, min(1 - rect.origin.y, rect.size.height))
        return rect
    }
}
