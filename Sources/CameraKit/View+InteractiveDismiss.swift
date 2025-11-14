import SwiftUI

@available(iOS 15.0, *)
extension View {
    @ViewBuilder
    func ckInteractiveDismissDisabled(_ disabled: Bool) -> some View {
        interactiveDismissDisabled(disabled)
    }
}
