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
    
   // @EnvironmentObject var entitlementManager: EntitlementManager
    
    @Environment(\.scenePhase) var phase
    
    @State private var quickAction: String?
    @State private var isAddingToDoItem = false
    @State private var isAddingShoppingItem = false
    @State private var isUpcomingToDoItems = false
    
    let persistenceController = PersistenceController.shared
    
    @StateObject private var locationManager: LocationManager
    @StateObject private var notificationDelegate = NotificationDelegate()
    @StateObject private var entitlementManager = EntitlementManager()
    @StateObject private var subscriptionsManager: SubscriptionsManager
    @StateObject private var dataUpdateManager = DataUpdateManager()
    @StateObject private var shoppingListViewModel = ShoppingListViewModel(context: PersistenceController.shared.container.viewContext, isEditingExistingItem: false)

    @AppStorage("showLastEditor") private var showLastEditor: Bool = true
    @AppStorage("enableDarkMode") private var enableDarkMode: Bool = false
    @AppStorage("enableNotifications") private var enableNotifications: Bool = true
    @AppStorage("notificationSound") private var notificationSound: String = "Default"
    @AppStorage("geofenceRadius") private var geofenceRadius: Double = 804.67
    
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
        
        // Initialize Subscription Manager with Entitlement Manager
        let entitlementManager = EntitlementManager()
        let subscriptionsManager = SubscriptionsManager(entitlementManager: entitlementManager)
        
        // Initialize all StateObject properties
        self._locationManager = StateObject(wrappedValue: LocationManager.shared)
        self._notificationDelegate = StateObject(wrappedValue: NotificationDelegate())
        self._entitlementManager = StateObject(wrappedValue: entitlementManager)
        self._subscriptionsManager = StateObject(wrappedValue: subscriptionsManager)
        self._dataUpdateManager = StateObject(wrappedValue: DataUpdateManager())
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
                    await subscriptionsManager.updatePurchasedProducts()
                    
                    do {
                        let shoppingItems: [ShoppingItemEntity] = try await CoreDataManager.shared().fetch(entityName: CoreDataEntities.shoppingItem.stringValue)
                        
                        for item in shoppingItems {
                            // Only monitor shopping items that have an assigned store
                            if !(item.storeName?.isEmpty ?? true),
                               item.latitude != 0,
                               item.longitude != 0 {
                                let coordinate = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
                                locationManager.monitorRegionAtLocation(center: coordinate, identifier: item.uid ?? UUID().uuidString, item: item)
                            }
                        }
                        
//                        for item in shoppingItems {
//                            if item.latitude != 0, item.longitude != 0 {
//                                let coordinate = CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
//                                locationManager.monitorRegionAtLocation(center: coordinate, identifier: item.uid ?? UUID().uuidString, item: item)
//                            }
//                        }
                    } catch {
                        print("❌ Failed to fetch Shopping items: \(error.localizedDescription)")
                    }
                }
                .onAppear {
                    scheduleDueDateNotifications()
                }
        }
    }
    
    private func scheduleDueDateNotifications() {
        do {
            let items: [ToDoItemEntity] = try CoreDataManager.shared().fetch(entityName: CoreDataEntities.toDoItem.stringValue, sortBy: [NSSortDescriptor(keyPath: \ToDoItemEntity.dueDate, ascending: true)])
            
            let currentDate = Calendar.current.startOfDay(for: Date())
            
            for item in items {
                let taskName = item.task ?? "To-Do Task"

                // ✅ Time-Based Notification only
                if let dueDate = item.dueDate, Calendar.current.isDate(dueDate, inSameDayAs: currentDate) {
                    NotificationDelegate.shared.scheduleNotification(
                        title: "Task Reminder",
                        body: "Your task '\(taskName)' is due today.",
                        dueDate: dueDate
                    )
                }
                // ❌ REMOVE location-based notification here
            }

        } catch {
            print("❌ Failed to fetch To-Do items: \(error.localizedDescription)")
        }
    }
}

