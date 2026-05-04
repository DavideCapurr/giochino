import Foundation
import StoreKit

@MainActor
final class SubscriptionStore: ObservableObject {
    nonisolated static let premiumMonthlyProductID = "com.shiftblast.premium.monthly"

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case restoring
        case failed(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium = false
    @Published private(set) var state: PurchaseState = .idle

    var premiumProduct: Product? {
        products.first { $0.id == Self.premiumMonthlyProductID }
    }

    var premiumDisplayPrice: String {
        premiumProduct?.displayPrice ?? "Monthly"
    }

    private var updatesTask: Task<Void, Never>?
    private let productIDs: Set<String>

    init(productIDs: Set<String> = [SubscriptionStore.premiumMonthlyProductID]) {
        self.productIDs = productIDs
    }

    deinit {
        updatesTask?.cancel()
    }

    func configure() async {
        updatesTask?.cancel()
        updatesTask = listenForTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    func purchasePremium() async {
        guard let premiumProduct else {
            state = .failed("Premium subscription is not available yet.")
            await loadProducts()
            return
        }

        state = .purchasing
        do {
            let result = try await premiumProduct.purchase()
            switch result {
            case .success(let verificationResult):
                guard let transaction = verifiedTransaction(from: verificationResult) else {
                    state = .failed("The App Store could not verify this purchase.")
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
                state = .idle
            case .pending:
                state = .idle
            case .userCancelled:
                state = .idle
            @unknown default:
                state = .failed("The purchase could not be completed.")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async {
        state = .restoring
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func clearError() {
        if case .failed = state {
            state = .idle
        }
    }

    private func loadProducts() async {
        state = .loading
        do {
            products = try await Product.products(for: Array(productIDs))
                .sorted { $0.displayName < $1.displayName }
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func refreshEntitlements() async {
        var entitledProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            entitledProductIDs.insert(transaction.productID)
        }

        isPremium = entitledProductIDs.contains(Self.premiumMonthlyProductID)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = await MainActor.run(body: { self.verifiedTransaction(from: result) }) else {
                    await MainActor.run {
                        self.state = .failed("The App Store could not verify an updated transaction.")
                    }
                    continue
                }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func verifiedTransaction(from result: VerificationResult<Transaction>) -> Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }
}
