import SwiftUI

/// One page of the "how to use the app" tour. Shared between the tour steps appended to
/// first-run onboarding and the standalone replay presented from Settings.
enum TourPage: Hashable {
    case overview
    case finance
    case workouts
    case nutrition

    /// Overview is always shown; the rest only appear for modules the user is tracking.
    static func pages(for modules: Set<TrackedModule>) -> [TourPage] {
        var pages: [TourPage] = [.overview]
        if modules.contains(.finance) { pages.append(.finance) }
        if modules.contains(.workouts) { pages.append(.workouts) }
        if modules.contains(.nutrition) { pages.append(.nutrition) }
        return pages
    }

    var icon: String {
        switch self {
        case .overview: return "house.fill"
        case .finance: return "wallet.bifold.fill"
        case .workouts: return "figure.strengthtraining.traditional"
        case .nutrition: return "fork.knife"
        }
    }

    var color: Color {
        switch self {
        case .overview: return .ink
        case .finance: return .money
        case .workouts: return .training
        case .nutrition: return .food
        }
    }

    var eyebrow: String {
        switch self {
        case .overview: return "YOUR HOME BASE"
        case .finance: return "FINANCES"
        case .workouts: return "WORKOUTS"
        case .nutrition: return "NUTRITION"
        }
    }

    var headline: String {
        switch self {
        case .overview: return "Start on Overview"
        case .finance: return "Track where your money goes"
        case .workouts: return "Log strength, track cardio automatically"
        case .nutrition: return "Log food, hit your macros"
        }
    }

    var bullets: [String] {
        switch self {
        case .overview:
            return [
                "See a weekly score for every pillar you're tracking, at a glance",
                "Tap any row — Money, Training, Food — to jump straight into that tab",
                "The gear icon in the corner opens Settings, including which pillars you track",
            ]
        case .finance:
            return [
                "Tap + to log a transaction in seconds",
                "See what's left to spend this pay period, and where the rest is going",
                "Keep an eye on bills, savings, and spending trends",
            ]
        case .workouts:
            return [
                "Start a workout in one tap from a template — or build your own",
                "Cardio and steps sync in automatically from Apple Health",
                "Watch your weekly sessions and step count stack up against your goals",
            ]
        case .nutrition:
            return [
                "Scan a barcode, search, or reuse a recent item to log food",
                "See calories and macros vs. your daily goals as you go",
                "Entries sort themselves into breakfast, lunch, dinner, and snacks",
            ]
        }
    }
}

/// Small call-to-action shown at the end of the tour — in first-run onboarding and the
/// standalone replay from Settings — pointing new users toward Alfie Plus.
struct SupportAlfieSection: View {
    @State private var showPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.training)
                Text("Enjoying Alfie Track?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }

            Text("Subscribe to Alfie Track Plus to remove ads and support ongoing development.")
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(Color.inkSecondary)

            Button {
                showPaywall = true
            } label: {
                Text("See Alfie Track Plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.training)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
        .padding(.top, 20)
        .sheet(isPresented: $showPaywall) {
            RemoveAdsPaywallView()
        }
    }
}

/// Icon badge + headline + bullet list for one tour page. Used inline by both the
/// onboarding flow and the standalone tour replay.
struct TourPageView: View {
    let page: TourPage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IconBadge(systemName: page.icon, color: page.color, size: 52, shape: .roundedSquare(radius: 16))

            Text(page.eyebrow)
                .eyebrowStyle(color: page.color)

            Text(page.headline)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.4)
                .lineSpacing(2)
                .foregroundStyle(Color.ink)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(page.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(page.color)
                            .padding(.top, 1)
                        Text(bullet)
                            .font(.system(size: 15))
                            .lineSpacing(3)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
