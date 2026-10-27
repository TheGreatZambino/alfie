import SwiftUI

extension View {
    /// Grows the tappable area to at least 44pt (the iOS minimum) without changing the
    /// layout size. Pass the size the control should occupy in the layout; omit an axis
    /// to leave it alone. Don't clip the view afterward, or the extra area stops hit-testing.
    func tapTarget(layoutWidth: CGFloat? = nil, layoutHeight: CGFloat? = nil) -> some View {
        let minimum: CGFloat = 44
        return self
            .frame(minWidth: layoutWidth == nil ? nil : minimum, minHeight: layoutHeight == nil ? nil : minimum)
            .contentShape(Rectangle())
            .padding(.horizontal, layoutWidth.map { -max(0, minimum - $0) / 2 } ?? 0)
            .padding(.vertical, layoutHeight.map { -max(0, minimum - $0) / 2 } ?? 0)
    }
}
