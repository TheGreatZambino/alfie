import SwiftUI

/// A circular progress ring with arbitrary centered content — used by Overview's pillar rings
/// and Nutrition's calorie ring.
struct RingGauge<Center: View>: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 6
    var size: CGFloat = 66
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.13), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)

            center()
        }
        .frame(width: size, height: size)
    }
}
