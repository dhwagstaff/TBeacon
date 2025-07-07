//
//  SmartRemindersApp.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import CloudKit
import CoreData
import CoreLocation
import MapKit
import SwiftUI
import UIKit
import UserNotifications

@main
struct TaskBeaconApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
            
    @Environment(\.scenePhase) var phase
    
    @State private var quickAction: String?
    @State private var isAddingToDoItem = false
    @State private var isAddingShoppingItem = false
    @State private var isUpcomingToDoItems = false
    @State private var showOnboarding = false

    let persistenceController = PersistenceController.shared
    
    @StateObject private var locationManager: LocationManager
//    @StateObject private var notificationDelegate = NotificationDelegate()
    @StateObject private var entitlementManager = EntitlementManager.shared
    @StateObject private var subscriptionsManager: SubscriptionsManager
    @StateObject private var dataUpdateManager = DataUpdateManager()
    @StateObject private var shoppingListViewModel = ShoppingListViewModel(context: PersistenceController.shared.container.viewContext, isEditingExistingItem: false)

    @AppStorage("showLastEditor") private var showLastEditor: Bool = true
    @AppStorage("enableDarkMode") private var enableDarkMode: Bool = false
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    @AppStorage("notificationSound") private var notificationSound: String = "Default"
    @AppStorage("geofenceRadius") private var geofenceRadius: Double = 804.67
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        _shoppingListViewModel = StateObject(wrappedValue: ShoppingListViewModel(
            context: PersistenceController.shared.container.viewContext, isEditingExistingItem: false))
        
        let context = PersistenceController.shared.container.viewContext
        var items: [NSManagedObject] = []
        
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        
        do {
            let todos = try context.fetch(todoRequest)
            let shoppingItems = try context.fetch(shoppingRequest)
            
            items.append(contentsOf: todos)
            items.append(contentsOf: shoppingItems)
            
            
            print("✅ Fetched \(items.count) items for geofencing.")
        } catch {
            print("❌ Error fetching items: \(error)")
        }
        
        // Initialize the LocationManager singleton with fetched items
        LocationManager.shared.initializeWithItems(items, context: context)
        
        // Use the singleton EntitlementManager consistently
        let entitlementManager = EntitlementManager.shared
        let subscriptionsManager = SubscriptionsManager(entitlementManager: entitlementManager)
        
        // Initialize all StateObject properties
        self._locationManager = StateObject(wrappedValue: LocationManager.shared)
//        self._notificationDelegate = StateObject(wrappedValue: NotificationDelegate())
        self._entitlementManager = StateObject(wrappedValue: entitlementManager)
        self._subscriptionsManager = StateObject(wrappedValue: subscriptionsManager)
        self._dataUpdateManager = StateObject(wrappedValue: DataUpdateManager())
        
        // Set up the relationship between EntitlementManager and SubscriptionsManager
        entitlementManager.subscriptionsManager = subscriptionsManager
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(isAddingToDoItem: $isAddingToDoItem, isAddingShoppingItem: $isAddingShoppingItem, isUpcomingToDoItems: $isUpcomingToDoItems)
                .environmentObject(locationManager)
                .environmentObject(dataUpdateManager)
                .environmentObject(entitlementManager)
                .environmentObject(subscriptionsManager)
                .environmentObject(shoppingListViewModel)
                .environment(\ .managedObjectContext, persistenceController.container.viewContext)
                .id(entitlementManager.isPremiumUser)
                .preferredColorScheme(enableDarkMode ? .dark : .light)
                .task {
                    print("🔍 App task started - requesting permissions")
                    
                    // Request location permission early in app lifecycle
                    let permissionManager = PermissionManager.shared
                    if await permissionManager.checkAndRequestPermission(for: .location) {
                        print("✅ Location permission granted in app task")
                    } else {
                        print("❌ Location permission not granted in app task")
                    }
                    
                    // Request notification permission
                    _ = await permissionManager.checkAndRequestPermission(for: .notifications)
                    
                    // Ensure subscription status is up to date
                    await subscriptionsManager.updatePurchasedProducts()
                    
                    // Force refresh EntitlementManager status
                    entitlementManager.forceRefreshSubscriptionStatus()
                    
                    do {
                        let context = CoreDataManager.shared().viewContext
                        locationManager.loadAndMonitorAllGeofences(from: context)
                    } catch {
                        print("❌ Failed to load geofences: \(error.localizedDescription)")
                    }
                }
                .onAppear {
                    // Track app launch
                    RatingHelper.shared.incrementLaunchCount()
                    
                    // Request rating after a delay (don't ask immediately)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        RatingHelper.shared.requestRating()
                    }
                    
                    // Only show onboarding if not completed
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                    appDelegate.adManager.entitlementManager = entitlementManager
                    scheduleDueDateNotifications()
                }
                .sheet(isPresented: $showOnboarding, onDismiss: {
                    if !hasCompletedOnboarding {
                        hasCompletedOnboarding = true
                    }
                }) {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
                // Dismiss the onboarding sheet when completed
                .onChange(of: hasCompletedOnboarding) {
                    if hasCompletedOnboarding {
                        showOnboarding = false
                    }
                }
        }
    }
    
    private func scheduleDueDateNotifications() {
        do {
            let items: [ToDoItemEntity] = try CoreDataManager.shared().fetch(entityName: CoreDataEntities.toDoItem.stringValue, sortBy: [NSSortDescriptor(keyPath: \ToDoItemEntity.dueDate, ascending: true)])
            
            for item in items {
                if let dueDate = item.dueDate {
                    // 🔧 FIX: Schedule notifications for all future due dates, not just today
                    if dueDate > Date() {
                        let taskName = item.task ?? "To-Do Task"
                        let identifier = "todo_due_\(item.uid ?? UUID().uuidString)"
                        
                        // Cancel any existing notification for this item
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
                        
                        NotificationDelegate.shared.scheduleNotification(
                            title: "Task Due",
                            body: "Your task '\(taskName)' is due now.",
                            dueDate: dueDate,
                            identifier: identifier
                        )
                        print("✅ Scheduled due date notification for task: \(taskName) at \(dueDate)")
                    } else {
                        print("⚠️ Due date is in the past, not scheduling notification for: \(item.task ?? "Unknown Task")")
                    }
                }
            }

        } catch {
            print("❌ Failed to fetch To-Do items: \(error.localizedDescription)")
        }
    }
    
//    private func scheduleDueDateNotifications() {
//        do {
//            let items: [ToDoItemEntity] = try CoreDataManager.shared().fetch(entityName: CoreDataEntities.toDoItem.stringValue, sortBy: [NSSortDescriptor(keyPath: \ToDoItemEntity.dueDate, ascending: true)])
//            
//            let currentDate = Calendar.current.startOfDay(for: Date())
//            
//            for item in items {
//                let taskName = item.task ?? "To-Do Task"
//
//                // ✅ Time-Based Notification only
//                if let dueDate = item.dueDate, Calendar.current.isDate(dueDate, inSameDayAs: currentDate) {
//                    NotificationDelegate.shared.scheduleNotification(
//                        title: "Task Reminder",
//                        body: "Your task '\(taskName)' is due today.",
//                        dueDate: dueDate
//                    )
//                }
//                // ❌ REMOVE location-based notification here
//            }
//
//        } catch {
//            print("❌ Failed to fetch To-Do items: \(error.localizedDescription)")
//        }
//    }
}

