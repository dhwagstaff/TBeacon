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
   // @Binding var isShowingAnySheet: Bool
   // @Binding var showAddShoppingItem:Bool

    @State private var selectedProduct: Echolist.Product? = nil
    @State private var isLoadingPurchase = false
    
    private let features: [String] = ["Remove all ads", "Unlimited To-Do & Shopping Items"]
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallDevice = geometry.size.height < 700 // iPhone SE, smaller devices
            let isIPad = geometry.size.width > 768
            
            // Smaller fonts for compact devices
            let titleFont = isSmallDevice ? Font.system(.title3, design: .rounded) : Font.system(.title2, design: .rounded)
            let bodyFont = isSmallDevice ? Font.system(.callout, design: .default) : Font.system(.body, design: .default)
            let featureFont = isSmallDevice ? Font.system(size: 15.0, weight: .semibold, design: .rounded) : Font.system(size: 17.0, weight: .semibold, design: .rounded)
            
            let iconSize = isSmallDevice ? min(geometry.size.width * 0.15, 60) :
                           isIPad ? min(geometry.size.width * 0.15, 100) :
                           min(geometry.size.width * 0.2, 80)
            
            let spacing = isSmallDevice ? geometry.size.height * 0.01 :
                          isIPad ? geometry.size.height * 0.015 :
                          geometry.size.height * 0.02
            
            ScrollView {
                VStack(spacing: 0) {
                    subscriptionOptionsView(geometry: geometry)
                    
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
                    .padding(.top, 15)
                   // .padding(.bottom, 10)
                    
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
                    .padding(.bottom, 20)
                }
                .padding()
             //   .frame(minHeight: geometry.size.height)
                .frame(maxWidth: geometry.size.width > 768 ? 600 : .infinity, minHeight: geometry.size.height) // Limit width on iPad
            }
        }
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
}

//struct SubscriptionScreen: View {
//    @EnvironmentObject var entitlementManager: EntitlementManager
//    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
//    @EnvironmentObject var todoListViewModel: ToDoListViewModel
//    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
//
//    @Binding var showSubscriptionScreen: Bool // Controls modal dismissal
//   // @Binding var isShowingAnySheet: Bool
//   // @Binding var showAddShoppingItem:Bool
//
//    @State private var selectedProduct: Echolist.Product? = nil
//    @State private var isLoadingPurchase = false
//    
//    private let features: [String] = ["Remove all ads", "Unlimited To-Do & Shopping Items"]
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ScrollView {
//                VStack(spacing: 0) {
//                    subscriptionOptionsView(geometry: geometry)
//                    
//                    // ✅ Free version option
//                    Button(action: {
//                        withAnimation {
//                            entitlementManager.isPremiumUser = false
//                            entitlementManager.hasChosenFreeVersion = true
//                            showSubscriptionScreen = false
//                            print("🔹 User chose Free Version")
//                        }
//                    }) {
//                        Text("Continue with Free Version")
//                            .foregroundColor(.blue)
//                            .font(.headline)
//                            .padding()
//                            .frame(maxWidth: .infinity)
//                            .background(Color(.secondarySystemBackground))
//                            .cornerRadius(10)
//                    }
//                    .padding(.horizontal, 20)
//                    .padding(.top, 20)
//                   // .padding(.bottom, 10)
//                    
//                    HStack {
//                        Button("Privacy Policy") {
//                            if let url = URL(string: "https://echolistapp.github.io/echolist/PrivacyPolicy.html") {
//                                UIApplication.shared.open(url)
//                            }
//                        }
//                        Spacer()
//                        Button("Terms of Use") {
//                            if let url = URL(string: "https://echolistapp.github.io/echolist/TermsOfUse.html") {
//                                UIApplication.shared.open(url)
//                            }
//                        }
//                    }
//                    .font(.footnote)
//                    .foregroundColor(.blue)
//                    .padding(.top, 8)
//                    .padding(.bottom, 20)
//                }
//                .padding()
//                .frame(minHeight: geometry.size.height)
//            }
//        }
//        .background(Color(.systemBackground))
//        .edgesIgnoringSafeArea(.all)
//    }
//}

// MARK: - Subscription Options
extension SubscriptionScreen {
    
    private func subscriptionOptionsView(geometry: GeometryProxy) -> some View {
        let isIPad = geometry.size.width > 768
        let topPadding = isIPad ? geometry.size.height * 0.01 : geometry.size.height * 0.05 // Less padding on iPad
        
        return VStack(alignment: .center, spacing: 0) {
            Text("🔒 Unlock Premium Features")
                .foregroundColor(.primary)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .dynamicTypeSize(.large ... .accessibility5)
              //  .minimumScaleFactor(0.5)
            
            if !subscriptionsManager.products.isEmpty {
                premiumAccessView(geometry: geometry)
                featuresView(geometry: geometry)
                productsListView(geometry: geometry)
                purchaseSection(geometry: geometry)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .ignoresSafeArea(.all)
            }
        }
        .padding(.top, isIPad ? 0 : topPadding)
    }
    
    private func premiumAccessView(geometry: GeometryProxy) -> some View {
        let isSmallDevice = geometry.size.height < 700
        let isIPad = geometry.size.width > 768
        
        let iconSize = isSmallDevice ? min(geometry.size.width * 0.15, 60) :
                       isIPad ? min(geometry.size.width * 0.15, 100) :
                       min(geometry.size.width * 0.2, 80)
        
        let spacing = isSmallDevice ? geometry.size.height * 0.01 :
                      isIPad ? geometry.size.height * 0.015 :
                      geometry.size.height * 0.02
        
        let verticalPadding = isSmallDevice ? geometry.size.height * 0.015 :
                              isIPad ? geometry.size.height * 0.02 :
                              geometry.size.height * 0.03
        
        return VStack(alignment: .center, spacing: spacing) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(.tint)
                .font(.system(size: iconSize))
            
            Text("Unlock Premium Access")
                .foregroundColor(.primary)
                .font(isSmallDevice ? .system(.callout, design: .default) : .system(.body, design: .default))
                .dynamicTypeSize(.xSmall ... .xxxLarge)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
            
            Text("Get access to all of our features")
                .font(isSmallDevice ? .system(.callout, design: .default) : .system(.body, design: .default))
                .dynamicTypeSize(.xSmall ... .xxxLarge)
                .foregroundColor(.primary)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, verticalPadding)
    }
    
    private func featuresView(geometry: GeometryProxy) -> some View {
        let isSmallDevice = geometry.size.height < 700
        let isIPad = geometry.size.width > 768
        
        return List(features, id: \.self) { feature in
            HStack(alignment: .center) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: isSmallDevice ? 18 : 22.5, weight: .medium))
                    .foregroundStyle(.blue)
                
                Text(feature)
                    .foregroundColor(.primary)
                    .font(isSmallDevice ? .system(size: 15.0, weight: .semibold, design: .rounded) :
                                   .system(size: 17.0, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.leading)
            }
            .listRowSeparator(.hidden)
        }
        .frame(height: isIPad ? 70 : 100)
        .scrollDisabled(true)
        .listStyle(.plain)
    }
    
    private func productsListView(geometry: GeometryProxy) -> some View {
        let isIPad = geometry.size.width > 768
        let spacing = isIPad ? geometry.size.width * 0.02 : geometry.size.width * 0.03 // Less spacing on iPad
        let verticalPadding = isIPad ? geometry.size.height * 0.015 : geometry.size.height * 0.02 // Less padding on iPad
        
        return Group {
            let lifetimeProduct = subscriptionsManager.products.first { $0.id == "com.pocketmeapps.TaskBeacon.Premium" }
            let monthlyProduct = subscriptionsManager.products.first { $0.subscription?.subscriptionPeriod.unit == .month }
            let annualProduct = subscriptionsManager.products.first { $0.subscription?.subscriptionPeriod.unit == .year }

            VStack(spacing: spacing) {
                // Lifetime (one-time) purchase at the top
                if let product = lifetimeProduct {
                    productButton(product: product, geometry: geometry)
                }
                // Monthly and Annual side by side
                HStack(spacing: spacing) {
                    if let product = monthlyProduct {
                        productButton(product: product, geometry: geometry)
                    }
                    if let product = annualProduct {
                        productButton(product: product, geometry: geometry)
                    }
                }
            }
            .padding(.vertical, verticalPadding)
        }
    }

    @ViewBuilder
    private func productButton(product: StoreKit.Product, geometry: GeometryProxy) -> some View {
        let isSmallDevice = geometry.size.height < 700
        let isIPad = geometry.size.width > 768
        
        let buttonHeight = isSmallDevice ? geometry.size.height * 0.04 :
                           isIPad ? geometry.size.height * 0.045 :
                           geometry.size.height * 0.06
        
        let minButtonHeight: CGFloat = 44
        let maxButtonHeight: CGFloat = isSmallDevice ? 48 : (isIPad ? 50 : 60)
        let dynamicButtonHeight = max(minButtonHeight, min(maxButtonHeight, buttonHeight))
        
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
            VStack(alignment: .leading, spacing: isSmallDevice ? 2 : 4) {
                Text(product.displayName)
                    .font(isSmallDevice ? .headline : .headline)
                    .fontWeight(.bold)
                let priceString = product.price.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                if product.id == "com.pocketmeapps.TaskBeacon.Premium" {
                    Text("\(priceString) one-time purchase")
                        .font(isSmallDevice ? .caption : .subheadline)
                } else if let unit = product.subscription?.subscriptionPeriod.unit {
                    Text("\(priceString) \(unit == .month ? "per month" : unit == .year ? "per year" : "")")
                        .font(isSmallDevice ? .caption : .subheadline)
                } else {
                    Text(priceString)
                        .font(isSmallDevice ? .caption : .subheadline)
                }
            }
            .padding([.top, .bottom], isSmallDevice ? 3 : 5)
            .frame(maxWidth: .infinity)
            .frame(height: dynamicButtonHeight)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedProduct?.barcode == product.id ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private func purchaseSection(geometry: GeometryProxy) -> some View {
        let isIPad = geometry.size.width > 768
        let spacing = isIPad ? geometry.size.height * 0.015 : geometry.size.height * 0.02 // Less spacing on iPad
        
        return VStack(alignment: .center, spacing: spacing) {
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
                purchaseButtonView(geometry: geometry)
                
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
            print(" Available products: \(subscriptionsManager.products.map { $0.id })")
            print(" Purchased products: \(subscriptionsManager.purchasedProductIDs)")
        }
    }

    private func purchaseButtonView(geometry: GeometryProxy) -> some View {
        let isIPad = geometry.size.width > 768
        let buttonHeight = isIPad ? geometry.size.height * 0.04 : geometry.size.height * 0.055 // Smaller on iPad
        let minButtonHeight: CGFloat = 44
        let maxButtonHeight: CGFloat = isIPad ? 48 : 50 // Lower max height on iPad
        let dynamicButtonHeight = max(minButtonHeight, min(maxButtonHeight, buttonHeight))
        
        return Button(action: {
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

//                isShowingAnySheet = true
//                showAddShoppingItem = true
                
                showSubscriptionScreen = false // ✅ Close after purchase
            }
        }) {
            RoundedRectangle(cornerRadius: 12.5)
                .fill(isLoadingPurchase ? Color.gray : Color.blue)
                .frame(height: dynamicButtonHeight)
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

