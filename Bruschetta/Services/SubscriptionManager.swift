import Combine
import Foundation
import StoreKit

/// Tracks the "Alfie Plus" remove-ads subscription via StoreKit 2. `isSubscribed` drives
/// whether `AdSlot` renders a banner ad — this is the single source of truth for that.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var isSubscribed = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlement()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [Secrets.removeAdsSubscriptionProductID])
            product = products.first
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Secrets.removeAdsSubscriptionProductID,
                  transaction.revocationDate == nil else { continue }
            isSubscribed = true
            return
        }
        isSubscribed = false
    }

    func purchase() async {
        guard let product else {
            await loadProduct()
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result,
              transaction.productID == Secrets.removeAdsSubscriptionProductID else { return }
        if transaction.revocationDate == nil {
            isSubscribed = true
        }
        await transaction.finish()
    }
}
