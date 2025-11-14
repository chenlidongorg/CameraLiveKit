@testable import CameraKit
import XCTest
#if canImport(UIKit)
import UIKit
#endif

final class CameraKitTests: XCTestCase {
    func testConfigurationNormalizesMaxWidth() {
        let configuration = CameraKitConfiguration(mode: .captureWithCrop, maxOutputWidth: -10)
        XCTAssertNil(configuration.maxOutputWidth)
    }

    #if canImport(UIKit)
    func testImageProcessorRespectsMaxWidth() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        }

        let configuration = CameraKitConfiguration(mode: .captureWithCrop, maxOutputWidth: 1000)

        let result = try CameraKitImageProcessor.process(images: [image], configuration: configuration)
        XCTAssertEqual(result.processed.first?.size.width ?? 0, 1000, accuracy: 1)
        XCTAssertEqual(result.originals.first?.size.width ?? 0, 2000, accuracy: 1)
    }
    #endif
}
