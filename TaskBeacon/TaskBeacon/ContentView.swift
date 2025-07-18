//
//  ContentView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import AppTrackingTransparency
import CoreData
import StoreKit
import SwiftUI
import CloudKit
import CoreLocation
import MapKit
import UserNotifications

struct ContentView: View {
    @EnvironmentObject private var dataUpdateManager: DataUpdateManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var shoppingListViewModel: ShoppingListViewModel
    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
    
    @StateObject private var todoListViewModel = ToDoListViewModel(context: PersistenceController.shared.container.viewContext)
    
    @State private var shoppingList: [String] = []
    @State private var todoList: [String] = []
    @State private var showSettings = false
    @State private var selectedProduct: Product? = nil
    @State private var shouldRefreshView = false
    @State private var hasLoadedProducts = false
    @State private var refresh: Bool = false
    @State private var showFreeVersion: Bool = false
    @State private var forceRefresh = UUID()
    @State private var showSubscriptionScreen: Bool = false
    @State private var showPrivacyOptionsAlert = false
    @State private var formErrorDescription: String?
    @State private var showPremiumCelebration: Bool = false
    @State private var hasShownPremiumCelebration: Bool = false
    
    private let features: [String] = ["Remove all ads", "Unlimited To-Do & Shopping Items"]
    
    @Binding var isAddingToDoItem: Bool
    @Binding var isAddingShoppingItem: Bool
    @Binding var isUpcomingToDoItems: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(entity: ShoppingItemEntity.entity(), sortDescriptors: []) private var shoppingItems: FetchedResults<ShoppingItemEntity>
    @FetchRequest(entity: ToDoItemEntity.entity(), sortDescriptors: []) private var toDoItems: FetchedResults<ToDoItemEntity>
    
    // MARK: - Views
    private var premiumCelebrationBanner: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium Unlocked!")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(subscriptionTypeMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showPremiumCelebration = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // Add this computed property
    private var subscriptionTypeMessage: String {
        // Access the current values, not the bindings
        if entitlementManager.hasMonthlySubscription {
            return "Monthly Premium Plan"
        } else if entitlementManager.hasAnnualSubscription {
            return "Annual Premium Plan"
        } else {
            return "Premium Plan"
        }
    }
    
    init(isAddingToDoItem: Binding<Bool>, isAddingShoppingItem: Binding<Bool>, isUpcomingToDoItems: Binding<Bool>) {
        self._isAddingToDoItem = isAddingToDoItem
        self._isAddingShoppingItem = isAddingShoppingItem
        self._isUpcomingToDoItems = isUpcomingToDoItems
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Show the premium banner if the user is premium
                if showPremiumCelebration {
                    premiumCelebrationBanner
                        .padding()
                        .background(Color(.systemBackground))
                }
                
                if shoppingItems.isEmpty && toDoItems.isEmpty {
                    EmptyStateView() // ✅ Show when no items exist
                        .environmentObject(todoListViewModel)
                        .environment(\.managedObjectContext, viewContext)
                } else {
                    EditableListView()
                        .onAppear { refreshData() }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            refreshData()
                        }
                        .environmentObject(LocationManager.shared)
                        .environmentObject(todoListViewModel)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .background(Color(.systemBackground))
            .alert(isPresented: $showPrivacyOptionsAlert) {
                Alert(title: Text(formErrorDescription ?? "Error"),
                        message: Text("Please try again later.")
                )
            }
            .sheet(isPresented: $isAddingToDoItem) {
                AddEditToDoItemView(toDoItem: nil,
                                    showAddTodoItem: .constant(true),
                                    isShowingAnySheet: .constant(true),
                                    navigateToEditableList: .constant(false),
                                    isEditingExistingItem: false)
            }
            .sheet(isPresented: $isAddingShoppingItem) {
                AddEditShoppingItemView(
                    navigateToEditableList: .constant(false),
                    showAddShoppingItem: .constant(true),
                    isShowingAnySheet: .constant(false),
                    isEditingExistingItem: false,
                    shoppingItem: nil
                )
            }
            .sheet(isPresented: $isUpcomingToDoItems) {
                EditableListView()
                    .environmentObject(LocationManager.shared)
                    .environmentObject(shoppingListViewModel)
                    .environmentObject(todoListViewModel)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .fullScreenCover(isPresented: $showSubscriptionScreen, onDismiss: {
            print("🔹 Subscription Screen Dismissed")
        }) {
            SubscriptionScreen(showSubscriptionScreen: $showSubscriptionScreen)
                .environmentObject(entitlementManager)
                .environmentObject(subscriptionsManager)
        }
        .onAppear {
            checkSubscriptionStatus()
            checkForPremiumCelebration()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in })
        }
        .onChange(of: entitlementManager.isPremiumUser) {
            checkForPremiumCelebration()
        }
        .overlay(ErrorAlertView())
    }
    
    private func checkForPremiumCelebration() {
        // Check if user just became premium and hasn't seen celebration yet
        if entitlementManager.isPremiumUser && !hasShownPremiumCelebration {
            showPremiumCelebrationBanner()
        }
    }

    private func showPremiumCelebrationBanner() {
        withAnimation(.easeInOut(duration: 0.5)) {
            showPremiumCelebration = true
            hasShownPremiumCelebration = true
        }
        
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showPremiumCelebration = false
            }
        }
    }
    
    // 🔹 Function to Determine When to Show Subscription Screen
    private func checkSubscriptionStatus() {
        if !entitlementManager.isPremiumUser && !entitlementManager.hasChosenFreeVersion {
            showSubscriptionScreen = true // ✅ Show the modal if needed
        } else {
            showSubscriptionScreen = false // ✅ Ensure it's hidden if Free or Premium is chosen
        }
    }
    
    private func refreshData() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: CoreDataEntities.shoppingItem.stringValue)
        do {
            let _ = try viewContext.fetch(request)
        } catch {
            ErrorAlertManager.shared.showDataError("Failed to refresh data: \(error.localizedDescription)")
            print("Failed to refresh data: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async {
            viewContext.refreshAllObjects()
            print("🔄 Data refreshed in ContentView")
        }
    }
}

