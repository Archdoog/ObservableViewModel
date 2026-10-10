import SwiftUI

extension View {

    /// Runs `observe()` on the view model while the view is on screen.
    ///
    /// SwiftUI starts the method when the view appears and cancels it when
    /// the view disappears. A different view model instance starts it again.
    public func observe(on viewModel: some ViewModel) -> some View {
        task(id: ObjectIdentifier(viewModel)) {
            await viewModel.observe()
        }
    }
}
