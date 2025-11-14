import Foundation

public enum CameraKitStrings {
    public static func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }
}
