import SwiftUI

/// A horizontal capsule split into proportional colored segments, with small gaps between them.
/// Used by Overview's money row and Finances' balance card.
struct SegmentedBar: View {
    struct Segment {
        let fraction: Double
        let color: Color
    }

    let segments: [Segment]
    var trackColor: Color = .fill
    var height: CGFloat = 8
    var gap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let totalGap = gap * CGFloat(max(segments.count - 1, 0))
            let usableWidth = max(geo.size.width - totalGap, 0)

            HStack(spacing: gap) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(segment.color)
                        .frame(width: usableWidth * CGFloat(max(segment.fraction, 0)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(trackColor)
            )
        }
        .frame(height: height)
    }
}
