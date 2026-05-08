import Foundation
import StoreKit
import OSLog

private let log = Logger(subsystem: "com.davide.shiftblast", category: "SubscriptionStore")

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
    @Published private(set) var didFinishLoadingProducts = false

    var premiumProduct: Product? {
        products.first { $0.id == Self.premiumMonthlyProductID }
    }

    var premiumDisplayPrice: String {
        premiumProduct?.displayPrice ?? "$2.99"
    }

    private var updatesTask: Task<Void, Never>?
    private let productIDs: [String]

    init(productIDs: [String] = [SubscriptionStore.premiumMonthlyProductID]) {
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
        log.notice("⏳ Loading products for IDs: \(self.productIDs, privacy: .public)")
        state = .loading
        didFinishLoadingProducts = false

        do {
            let fetched = try await Product.products(for: productIDs)
            log.notice("✅ StoreKit returned \(fetched.count) product(s)")
            for p in fetched {
                log.notice("   → \(p.id, privacy: .public): \(p.displayName, privacy: .public) \(p.displayPrice, privacy: .public)")
            }
            products = fetched.sorted { $0.displayName < $1.displayName }
            didFinishLoadingProducts = true

            if products.isEmpty {
                log.error("⚠️ Product.products returned empty — StoreKit configuration may not be linked in scheme")
                state = .failed("Subscription not available. Check your connection.")
            } else {
                state = .idle
            }
        } catch {
            log.error("❌ Product.products threw: \(error.localizedDescription, privacy: .public)")
            products = []
            didFinishLoadingProducts = true
            state = .failed(error.localizedDescription)
        }
    }

    private func refreshEntitlements() async {
        var entitledProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            entitledProductIDs.insert(transaction.productID)
        }

        let wasPremium = isPremium
        isPremium = entitledProductIDs.contains(Self.premiumMonthlyProductID)
        if isPremium != wasPremium {
            log.notice("👑 Premium status changed: \(self.isPremium)")
        }
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
