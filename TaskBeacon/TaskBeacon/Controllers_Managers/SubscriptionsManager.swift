//
//  subscriptionsManager.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/11/25.
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class SubscriptionsManager: NSObject, ObservableObject {
    let premiumIDs = ["PMA_TBPM_25", "PMA_TBPA_25"]
    let productIDs: [String] = ["PMA_TBPM_25", "PMA_TBPA_25", "REMOVE_ADS"]
    var purchasedProductIDs: Set<String> = []

    @Published var products: [StoreKit.Product] = []
    @Published var taskBeaconProducts: [TaskBeacon.Product] = []
    @Published var hasLoadedProducts = false // Prevent multiple loads
    @Published var errorMessage: String = Constants.emptyString
    @Published var showErrorAlert = false

    @AppStorage("isPremiumUser") var isPremiumUser: Bool = false
    @AppStorage("hasRemovedAds") var hasRemovedAds: Bool = false
    
    private var entitlementManager: EntitlementManager? = nil
    private var updates: Task<Void, Never>? = nil
    
    init(entitlementManager: EntitlementManager) {
        self.entitlementManager = entitlementManager
        super.init()
        print("in init for subscription manager")
        self.updates = observeTransactionUpdates()
        SKPaymentQueue.default().add(self)
        
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    func observeTransactionUpdates() -> Task<Void, Never> {
        print("in observeTransactionUpdates")

       return Task(priority: .background) { [unowned self] in
            for await _ in Transaction.updates {
                await self.updatePurchasedProducts()
            }
        }
    }
}

// MARK: - StoreKit2 API (Products & Purchases)
extension SubscriptionsManager {
    func loadProducts() async {
        do {
            print("🔄 Loading StoreKit products...")

            let fetchedProducts = try await StoreKit.Product.products(for: productIDs)
                .sorted(by: { $0.price > $1.price })

            await MainActor.run {
                // ✅ Store StoreKit Products separately
                self.products = fetchedProducts // ✅ This remains as [StoreKit.Product]

                // ✅ Convert StoreKit Products into TaskBeacon.Product for display
                self.taskBeaconProducts = fetchedProducts.map { prods in
                    TaskBeacon.Product(gtin: prods.id,
                                       barcode: prods.id, // ✅ StoreKit uses `id`
                                       name: prods.displayName,
                                       brand: nil, // ✅ StoreKit does not provide brand info
                                       category: nil, // ✅ StoreKit does not provide category info
                                       price: prods.price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                                       expirationDate: nil)
                }

                print("✅ StoreKit Products: \(self.products.count)")
                print("✅ TaskBeacon Products: \(self.taskBeaconProducts.count)")
            }

        } catch {
            print("❌ Failed to fetch products! Error: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    func buyProduct(_ storeKitProduct: StoreKit.Product) async {
        print("in buyProduct")
        do {
            let result = try await storeKitProduct.purchase() // ✅ Ensures we're using StoreKit.Product

            switch result {
            case let .success(.verified(transaction)):
                await transaction.finish()
                await self.updatePurchasedProducts()
                
                // ✅ Force EntitlementManager to check status immediately
                await MainActor.run {
                    let hasMonthly = purchasedProductIDs.contains("PMA_TBPM_25")
                    let hasAnnual = purchasedProductIDs.contains("PMA_TBPA_25")
                    let isPremium = hasMonthly || hasAnnual
                    
                    // Update EntitlementManager immediately
                    EntitlementManager.shared.updateSubscriptionStatus(
                        isPremium: isPremium,
                        hasMonthly: hasMonthly,
                        hasAnnual: hasAnnual
                    )
                    
                    print("✅ Purchase completed - status updated immediately")
                }
                
                // ✅ Handle ad removal purchase
                if storeKitProduct.id == "REMOVE_ADS" {
                    self.hasRemovedAds = true
                }

            case let .success(.unverified(_, error)):
                print("❌ Unverified purchase. Might be jailbroken. Error: \(error)")
                
                errorMessage = error.localizedDescription
                showErrorAlert = true

            case .pending:
                print("⏳ Purchase pending approval...")

            case .userCancelled:
                print("🚫 User cancelled the purchase.")

            @unknown default:
                print("⚠️ Unknown purchase result!")
            }
        } catch {
            print("❌ Purchase failed! Error: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    func updatePurchasedProducts() async {
        print("🔄 Checking purchased products...")

        // Clear existing products first
        self.purchasedProductIDs.removeAll()

        do {
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { 
                    print("⚠️ Unverified transaction found")
                    continue 
                }

                if transaction.revocationDate == nil {
                    self.purchasedProductIDs.insert(transaction.productID)
                    print("✅ Found active transaction for product: \(transaction.productID)")
                    
                    // ✅ Check if the user is premium
                    if premiumIDs.contains(transaction.productID) {
                        isPremiumUser = true
                        print("✅ Premium subscription found: \(transaction.productID)")
                    }
                    
                    // ✅ Check if ads should be removed
                    if transaction.productID == "REMOVE_ADS" {
                        hasRemovedAds = true
                        print("✅ Ad removal purchase found")
                    }
                } else {
                    self.purchasedProductIDs.remove(transaction.productID)
                    print("❌ Transaction revoked for product: \(transaction.productID)")
                }
            }
        } catch {
            print("❌ Error checking transactions: \(error)")
        }
        
        await MainActor.run {
            // Update EntitlementManager using the new method
            let hasMonthly = purchasedProductIDs.contains("PMA_TBPM_25")
            let hasAnnual = purchasedProductIDs.contains("PMA_TBPA_25")
            let isPremium = hasMonthly || hasAnnual
            
            // Update local state
            self.isPremiumUser = isPremium
            
            // Update EntitlementManager
            EntitlementManager.shared.updateSubscriptionStatus(
                isPremium: isPremium,
                hasMonthly: hasMonthly,
                hasAnnual: hasAnnual
            )
            
            print("🔹 Premium User: \(isPremium), Ads Removed: \(hasRemovedAds)")
            print("🔹 Purchased Products: \(purchasedProductIDs)")
            print("🔹 EntitlementManager.shared.isPremiumUser after update: \(EntitlementManager.shared.isPremiumUser)")
        }
    }
    
    func restorePurchases() async {
        print("in Restore purchases")
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("❌ Restore failed! Error: \(error.localizedDescription)")
            
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - StoreKit Transaction Observers
extension SubscriptionsManager: SKPaymentTransactionObserver {
    nonisolated func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        print("🔄 Transactions updated.")
    }
    
    @preconcurrency
    nonisolated func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        return true
    }
}
