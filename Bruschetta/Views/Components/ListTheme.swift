import SwiftUI

extension View {
    /// Themes a `List` / `Form` with the app's warm surfaces instead of iOS's default grays.
    func alfieListStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .listRowBackground(Color.card)
            .listRowSeparatorTint(Color.hairline)
    }
}
