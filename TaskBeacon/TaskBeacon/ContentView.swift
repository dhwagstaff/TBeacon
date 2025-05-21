//
//  ContentView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

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
    @State private var shouldRefreshView = false // 🔹 Force re-render
    @State private var hasLoadedProducts = false // Prevent multiple loads
    @State private var refresh: Bool = false
    @State private var showFreeVersion: Bool = false
    @State private var forceRefresh = UUID() // 🔹 New State variable
    @State private var showSubscriptionScreen: Bool = false // Controls modal visibility

    private let features: [String] = ["Remove all ads", "Unlimited To-Do & Shopping Items"]
    
    @Binding var isAddingToDoItem: Bool
    @Binding var isAddingShoppingItem: Bool
    @Binding var isUpcomingToDoItems: Bool

    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(entity: ShoppingItemEntity.entity(), sortDescriptors: []) private var shoppingItems: FetchedResults<ShoppingItemEntity>
    @FetchRequest(entity: ToDoItemEntity.entity(), sortDescriptors: []) private var toDoItems: FetchedResults<ToDoItemEntity>
    
    // MARK: - Views
    private var hasSubscriptionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .foregroundStyle(.yellow)
                .font(Font.system(size: 100))
            
            Text("You've Unlocked Premium Access")
                .font(.system(size: 30.0, weight: .bold))
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .ignoresSafeArea(.all)
    }
    
    init(isAddingToDoItem: Binding<Bool>, isAddingShoppingItem: Binding<Bool>, isUpcomingToDoItems: Binding<Bool>) {
        self._isAddingToDoItem = isAddingToDoItem
        self._isAddingShoppingItem = isAddingShoppingItem
        self._isUpcomingToDoItems = isUpcomingToDoItems

        // Initialize other properties
        let context = PersistenceController.shared.container.viewContext
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        
        do {
            let todos = try context.fetch(todoRequest)
            let shoppingItems = try context.fetch(shoppingRequest)
           // let allItems = todos + shoppingItems
        } catch {
            print("❌ Failed to fetch items: \(error)")
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if entitlementManager.isPremiumUser {
                    AnyView(
                        VStack {
                            hasSubscriptionView
                                .padding()
                                .background(Color(.systemBackground))
                            
                            NavigationView {
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
                            .sheet(isPresented: $isAddingToDoItem) {
                                AddEditToDoItemView(toDoItem: nil,
                                                    showAddTodoItem: .constant(true),
                                                    isShowingAnySheet: .constant(true),
                                                    navigateToEditableList: .constant(false))
                            }
                            .sheet(isPresented: $isAddingShoppingItem) {
                                AddEditShoppingItemView(
                                    navigateToEditableList: .constant(false),
                                    showAddShoppingItem: .constant(true),
                                    isShowingAnySheet: .constant(false),
                                    shoppingItem: nil
                                )
                              //  .environmentObject(locationManager)
                            }
                            .sheet(isPresented: $isUpcomingToDoItems) {
                                EditableListView()
                                    .environmentObject(LocationManager.shared)
                                    .environmentObject(shoppingListViewModel)
                                    .environmentObject(todoListViewModel)
                                    .environment(\.managedObjectContext, viewContext)
                            }
                        }
                        .background(Color(.systemBackground))
                    )
                } else {
                    AnyView(
                        VStack {
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
                    )
                }
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
            checkSubscriptionStatus() // ✅ Ensure correct UI state on app launch
            
            Task {
                await subscriptionsManager.restorePurchases()
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
            print("Failed to refresh data: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async {
            viewContext.refreshAllObjects()
            print("🔄 Data refreshed in ContentView")
        }
    }
}

