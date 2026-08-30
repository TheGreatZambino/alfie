import SwiftUI

/// Drop-in bottom banner slot for the Nutrition and Workout tabs. Renders nothing once the
/// user holds the Alfie Plus subscription — Finances/Overview never call this.
struct AdSlot: View {
    @ObservedObject private var subscriptions = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        if !subscriptions.isSubscribed {
            VStack(spacing: 6) {
                Button {
                    showPaywall = true
                } label: {
                    Text("Remove ads — $3.99/mo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
                .buttonStyle(.plain)

                BannerAdView()
                    .frame(height: BannerAdViewController.approximateHeight)
            }
            .padding(.top, 4)
            .padding(.bottom, 2)
            .background(Color.paper)
            .sheet(isPresented: $showPaywall) {
                RemoveAdsPaywallView()
            }
        }
    }
}
