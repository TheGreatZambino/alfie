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
            let visibleSegments = segments.filter { $0.fraction > 0 }
            let totalGap = gap * CGFloat(max(visibleSegments.count - 1, 0))
            let usableWidth = max(geo.size.width - totalGap, 0)

            HStack(spacing: gap) {
                ForEach(Array(visibleSegments.enumerated()), id: \.offset) { _, segment in
                    // With no gap, use square segments clipped to one rounded bar so colors meet seamlessly.
                    RoundedRectangle(cornerRadius: gap == 0 ? 0 : 4, style: .continuous)
                        .fill(segment.color)
                        .frame(width: usableWidth * CGFloat(segment.fraction))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(trackColor)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(height: height)
    }
}
