//
//  SubscriptionScreen.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/3/25.
//

import StoreKit
import SwiftUI

struct SubscriptionScreen: View {
    @EnvironmentObject var entitlementManager: EntitlementManager
    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
    @EnvironmentObject var todoListViewModel: ToDoListViewModel
    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel

    @Binding var showSubscriptionScreen: Bool // Controls modal dismissal

    @State private var selectedProduct: Echolist.Product? = nil
    @State private var isLoadingPurchase = false
    
    private let features: [String] = ["Remove all ads", "Unlimited To-Do & Shopping Items"]
    
    var body: some View {
        VStack {
            subscriptionOptionsView
            
            // ✅ Free version option
            Button(action: {
                withAnimation {
                    entitlementManager.isPremiumUser = false
                    entitlementManager.hasChosenFreeVersion = true
                    showSubscriptionScreen = false
                    print("🔹 User chose Free Version")
                }
            }) {
                Text("Continue with Free Version")
                    .foregroundColor(.blue)
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            
            HStack {
                Button("Privacy Policy") {
                    if let url = URL(string: "https://echolistapp.github.io/echolist/PrivacyPolicy.html") {
                        UIApplication.shared.open(url)
                    }
                }
                Spacer()
                Button("Terms of Use") {
                    if let url = URL(string: "https://echolistapp.github.io/echolist/TermsOfUse.html") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(.footnote)
            .foregroundColor(.blue)
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Subscription Options
extension SubscriptionScreen {
    private var subscriptionOptionsView: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("🔒 Unlock Premium Features")
                .foregroundColor(.primary)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .dynamicTypeSize(.large ... .accessibility5)
            
            if !subscriptionsManager.products.isEmpty {
                premiumAccessView
                featuresView
                productsListView
                purchaseSection
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .ignoresSafeArea(.all)
            }
        }
        .padding(.top, 40)
    }
    
    private var premiumAccessView: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(.tint)
                .font(.system(size: 80))
            
            Text("Unlock Premium Access")
                .foregroundColor(.primary)
                .font(.system(.body, design: .default))
                .dynamicTypeSize(.xSmall ... .xxxLarge)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
            
            Text("Get access to all of our features")
                .font(.system(.body, design: .default))
                .dynamicTypeSize(.xSmall ... .xxxLarge)
                .foregroundColor(.primary)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
        }
    }
    
    private var featuresView: some View {
        List(features, id: \.self) { feature in
            HStack(alignment: .center) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 22.5, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text(feature)
                    .foregroundColor(.primary)
                    .font(.system(size: 17.0, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.leading)
            }
            .listRowSeparator(.hidden)
        }
        .frame(height: 100)
        .scrollDisabled(true)
        .listStyle(.plain)
       // .padding(.vertical, 20)
    }
    
    private var productsListView: some View {
        Group {
            let lifetimeProduct = subscriptionsManager.products.first { $0.id == "com.pocketmeapps.TaskBeacon.Premium" }
            let monthlyProduct = subscriptionsManager.products.first { $0.subscription?.subscriptionPeriod.unit == .month }
            let annualProduct = subscriptionsManager.products.first { $0.subscription?.subscriptionPeriod.unit == .year }

            VStack(spacing: 16) {
                // Lifetime (one-time) purchase at the top
                if let product = lifetimeProduct {
                    productButton(product: product)
                }
                // Monthly and Annual side by side
                HStack(spacing: 12) {
                    if let product = monthlyProduct {
                        productButton(product: product)
                    }
                    if let product = annualProduct {
                        productButton(product: product)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func productButton(product: StoreKit.Product) -> some View {
        Button(action: {
            selectedProduct = Echolist.Product(
                gtin: product.id,
                barcode: product.id,
                name: product.displayName,
                brand: nil,
                category: nil,
                price: product.price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                expirationDate: nil
            )
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
                let priceString = product.price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                if product.id == "com.pocketmeapps.TaskBeacon.Premium" {
                    Text("\(priceString) one-time purchase")
                } else if let unit = product.subscription?.subscriptionPeriod.unit {
                    Text("\(priceString) \(unit == .month ? "per month" : unit == .year ? "per year" : "")")
                } else {
                    Text(priceString)
                }
            }
            .padding([.top, .bottom], 5)
          //  .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedProduct?.barcode == product.id ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private var purchaseSection: some View {
        VStack(alignment: .center, spacing: 15) {
            // Check if user already owns something
            let hasPremiumSubscription = subscriptionsManager.purchasedProductIDs.contains("PMA_TBPM_25") ||
                                        subscriptionsManager.purchasedProductIDs.contains("PMA_TBPA_25")
            let hasLifetime = subscriptionsManager.purchasedProductIDs.contains("com.pocketmeapps.TaskBeacon.Premium")
            
            if hasPremiumSubscription || hasLifetime {
                // User already owns something - show status
                if hasPremiumSubscription {
                    let subscriptionType = subscriptionsManager.purchasedProductIDs.contains("PMA_TBPM_25") ? "Monthly" : "Annual"
                    Text("✅ You have Echolist Premium (\(subscriptionType))!")
                        .foregroundColor(.green)
                        .font(.headline)
                }
                if hasLifetime {
                    Text("✅ You own Echolist Lifetime Access!")
                        .foregroundColor(.green)
                        .font(.headline)
                }
                
                Button("Manage Subscription") {
                    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 14.0, weight: .regular, design: .rounded))
                .frame(height: 15, alignment: .center)
                .padding()
            } else {
                // User doesn't own anything - show purchase options
                purchaseButtonView
                
                if let selected = selectedProduct {
                    VStack(alignment: .center, spacing: 6) {
                        Text(selected.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        // Fix the text to handle lifetime purchases
                        if selected.name.contains("Lifetime") || selected.barcode == "com.pocketmeapps.TaskBeacon.Premium" {
                            Text("\(selected.price ?? "$79.99") one-time purchase")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text("Lifetime access - no recurring payments")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)
                        } else {
                            Text("\(selected.price ?? (selected.name.contains("Annual") ? "$49.99" : "$4.99")) \(selected.name.contains("Annual") ? "per year" : "per month"), auto-renews")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                }
                
                Button("Restore Purchases") {
                    Task {
                        await subscriptionsManager.restorePurchases()
                    }
                }
                .font(.system(size: 14.0, weight: .regular, design: .rounded))
                .frame(height: 15, alignment: .center)
               // .padding()
            }
        }
        .onAppear {
            print("�� Available products: \(subscriptionsManager.products.map { $0.id })")
            print("�� Purchased products: \(subscriptionsManager.purchasedProductIDs)")
        }
    }

    private var purchaseButtonView: some View {
        Button(action: {
            guard let taskBeaconProduct = selectedProduct else {
                print("⚠️ Please select a valid subscription product.")
                return
            }

            // ✅ Find matching StoreKit product by ID
            guard let storeKitProduct = subscriptionsManager.products.first(where: { $0.id == taskBeaconProduct.barcode }) else {
                ErrorAlertManager.shared.showNetworkError("❌ Error: No matching StoreKit product found for \(taskBeaconProduct.barcode)")

                print("❌ Error: No matching StoreKit product found for \(taskBeaconProduct.barcode)")
                return
            }

            isLoadingPurchase = true
            Task {
                await subscriptionsManager.buyProduct(storeKitProduct) // ✅ Now using StoreKit.Product
                isLoadingPurchase = false
                
                showSubscriptionScreen = false // ✅ Close after purchase
            }
        }) {
            RoundedRectangle(cornerRadius: 12.5)
                .fill(isLoadingPurchase ? Color.gray : Color.blue)
                .frame(height: 46)
                .overlay {
                    Text(isLoadingPurchase ? "Processing..." : "Purchase")
                        .foregroundColor(.white)
                        .font(.system(size: 16.5, weight: .semibold, design: .rounded))
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .disabled(selectedProduct == nil || isLoadingPurchase)
    }
}

//#Preview {
//    SubscriptionScreen(showSubscriptionScreen: .constant(true))
//}

