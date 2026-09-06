import StoreKit
import SwiftUI

private let termsOfUseURL = URL(string: "https://thegreatzambino.github.io/alfie/legal/terms.html")!
private let privacyPolicyURL = URL(string: "https://thegreatzambino.github.io/alfie/legal/privacy.html")!

struct RemoveAdsPaywallView: View {
    @ObservedObject private var subscriptions = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        IconBadge(systemName: "sparkles", color: .training, size: 56, shape: .roundedSquare(radius: 16))
                        Text("Alfie Track Plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.ink)
                        Text("Remove ads everywhere in Alfie Track.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.inkTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 12) {
                        featureRow(icon: "nosign", text: "No ads anywhere in the app")
                        featureRow(icon: "heart.fill", text: "Supports ongoing development of Alfie Track")
                    }
                    .padding(16)
                    .background(Color.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.cardBorder, lineWidth: 1)
                    )

                    if subscriptions.isSubscribed {
                        Text("You're subscribed — thank you!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.money)
                    } else {
                        subscribeButton
                        restoreButton
                    }

                    legalLinks
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color.paper)
            .navigationTitle("Alfie Track Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await subscriptions.loadProduct()
        }
    }

    private var subscribeButton: some View {
        Button {
            Task { await subscriptions.purchase() }
        } label: {
            HStack {
                if subscriptions.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Subscribe — \(priceLabel)")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.trainingFill)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(subscriptions.isLoading || subscriptions.product == nil)
    }

    private var restoreButton: some View {
        Button {
            Task { await subscriptions.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkTertiary)
        }
        .disabled(subscriptions.isLoading)
    }

    private var legalLinks: some View {
        HStack(spacing: 6) {
            Link("Terms of Use", destination: termsOfUseURL)
            Text("·").foregroundStyle(Color.inkQuaternary)
            Link("Privacy Policy", destination: privacyPolicyURL)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.top, 4)
    }

    private var priceLabel: String {
        guard let product = subscriptions.product else { return "$3.99/mo" }
        return "\(product.displayPrice)/mo"
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.training)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.ink)
            Spacer()
        }
    }
}

#Preview {
    RemoveAdsPaywallView()
}
