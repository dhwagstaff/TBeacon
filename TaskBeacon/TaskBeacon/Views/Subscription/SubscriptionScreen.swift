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
            .padding(.bottom, 30)
            
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
                .minimumScaleFactor(0.5)
            
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
        .padding(.vertical, 20)
    }
    
    private var productsListView: some View {
        List(subscriptionsManager.products, id: \.self) { product in
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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                        // Show price and period/unit clearly
                        Text("\(product.price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))) \((product.subscription?.subscriptionPeriod.unit == .month) ? "per month" : (product.subscription?.subscriptionPeriod.unit == .year) ? "per year" : "")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if selectedProduct?.barcode == product.id {
                        Image(systemName: ImageSymbolNames.checkmarkCircleFill)
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: ImageSymbolNames.circle)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .frame(height: CGFloat(subscriptionsManager.products.count) * 95)
        .listStyle(.plain)
    }

//    private var productsListView: some View {
//        List(subscriptionsManager.products, id: \.self) { product in
//            Button(action: {
//                // ✅ Convert StoreKit.Product to TaskBeacon.Product before assignment
//                selectedProduct = Echolist.Product(
//                    gtin: product.id,
//                    barcode: product.id, // ✅ StoreKit uses `id`
//                    name: product.displayName,
//                    brand: nil, // ✅ StoreKit does not provide brand info
//                    category: nil, // ✅ StoreKit does not provide category info
//                    price: product.price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
//                    expirationDate: nil // ✅ StoreKit does not provide expiration date
//                )
//            }) {
//                HStack {
//                    Text(product.displayName)
//                        .foregroundColor(.primary)
//                        .font(.system(.headline, design: .rounded))
//                        .fontWeight(.bold)
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal)
//                        .frame(maxWidth: .infinity)
//                        .dynamicTypeSize(.large ... .accessibility5)
//                        .minimumScaleFactor(0.5)
//
//                    Spacer()
//                    if selectedProduct?.barcode == product.id { // ✅ Compare correctly using barcode
//                        Image(systemName: ImageSymbolNames.checkmarkCircleFill)
//                            .foregroundColor(.blue)
//                    } else {
//                        Image(systemName: ImageSymbolNames.circle)
//                            .foregroundColor(.gray)
//                    }
//                }
//                .padding()
//            }
//            .background(Color(.systemGray6))
//            .cornerRadius(10)
//        }
//        .frame(height: CGFloat(subscriptionsManager.products.count) * 95)
//        .listStyle(.plain)
//    }

    
    private var purchaseSection: some View {
        VStack(alignment: .center, spacing: 15) {
            purchaseButtonView
            
            if let selected = selectedProduct {
                VStack(alignment: .center, spacing: 6) {
                    Text(selected.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(String(describing: selected.price)) \(selected.name.contains("Annual") ? "per year" : "per month"), auto-renews")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
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
            .padding()
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

