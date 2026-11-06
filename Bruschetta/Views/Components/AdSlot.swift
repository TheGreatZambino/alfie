import SwiftUI

/// Drop-in bottom banner slot for the Nutrition and Workout tabs. Renders nothing once the
/// user holds the Alfie Plus subscription — Finances/Overview never call this.
struct AdSlot: View {
    @ObservedObject private var subscriptions = SubscriptionManager.shared
    @ObservedObject private var ads = GoogleMobileAdsInitializer.shared
    @State private var showPaywall = false
    @State private var hasLoadedAd = false
    @State private var loadFailed = false

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

                // No ad request until the ATT prompt has been answered.
                if ads.isReady {
                    // Collapse the gap when no ad fills. A failed refresh keeps the previous ad on
                    // screen, so only collapse if nothing has loaded; a later fill re-expands it.
                    BannerAdView { loaded in
                        if loaded {
                            hasLoadedAd = true
                            loadFailed = false
                        } else if !hasLoadedAd {
                            loadFailed = true
                        }
                    }
                    .frame(height: loadFailed ? 0 : BannerAdViewController.approximateHeight)
                } else {
                    Color.clear.frame(height: BannerAdViewController.approximateHeight)
                }
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
