//
//  AppDelegate.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/8/25.
//

import CoreData
import Foundation
import GoogleMobileAds
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    // Shared instance for app-wide access
    static let shared = AppDelegate()
    
    @Published var isAdReady: Bool = false
    @Published var showAd: Bool = false
    
    // Entitlement management
    let entitlementManager = EntitlementManager()

    private var hasInitializedLocationManager = false

    var window: UIWindow?
    
    var adManager = AdManager() // ✅ Create an instance
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            QuickActionsManager.shared.handleQuickActionItem(shortcutItem)
        }

        let sceneConfiguration = UISceneConfiguration(name: "Custom Configuration", sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = CustomSceneDelegate.self

        return sceneConfiguration
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        
        print("📌 Quick Action Triggered: \(shortcutItem.type)") // ✅ Debug log
                
        // handle quick actions
        NotificationCenter.default.post(name: .quickActionTriggered, object: shortcutItem.type)
        completionHandler(true)
    }
    
    private func clearNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().setBadgeCount(0)
        print("🧹 Cleared all notifications and reset badge count.")
    }
    
    // Fetch items and initialize LocationManager
    private func initializeLocationManager() {
        print("🛎️ Fetching data for LocationManager initialization...")
        let context = PersistenceController.shared.container.viewContext
        var items: [NSManagedObject] = []
        
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        
        do {
            let todos = try context.fetch(todoRequest)
            let shoppingItems = try context.fetch(shoppingRequest)
            
            items.append(contentsOf: todos)
            items.append(contentsOf: shoppingItems)
            
            print("✅ Fetched \(items.count) items for location monitoring.")
            LocationManager.shared.initializeWithItems(items, context: context)
        } catch {
            print("❌ Error fetching items: \(error)")
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if !hasInitializedLocationManager {
            initializeLocationManager()
            hasInitializedLocationManager = true
        }

        clearNotifications(application)
        initializeLocationManager()
        
        print("🚀 Initializing Google Mobile Ads SDK...")
        
        // Start Google Mobile Ads SDK with a slight delay
        // Initialize Google Mobile Ads SDK
        MobileAds.shared.start { status in
            print("📱 Google Mobile Ads SDK initialization status: \(status)")
            
            if status.adapterStatusesByClassName.count > 0 {
                print("✅ Google Mobile Ads SDK initialized successfully")
                // Start loading first ad
                self.loadInitialAd()
            } else {
                print("❌ Google Mobile Ads SDK initialization failed")
            }
        }
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//            MobileAds.shared.start(completionHandler: nil)
//        }

        // Request notification permission
        NotificationDelegate.shared.requestNotificationPermission()

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let lastRefresh = UserDefaults.standard.object(forKey: "lastGeofenceRefresh") as? Date,
           Date().timeIntervalSince(lastRefresh) < 300 { // 5 minutes
            return
        }
        
        print("📲 App became active. Refreshing geofences.")
        
        let context = PersistenceController.shared.container.viewContext
        var items: [NSManagedObject] = []
        
        let todoRequest = NSFetchRequest<ToDoItemEntity>(entityName: CoreDataEntities.toDoItem.stringValue)
        let shoppingRequest = NSFetchRequest<ShoppingItemEntity>(entityName: CoreDataEntities.shoppingItem.stringValue)
        
        do {
            let todos = try context.fetch(todoRequest)
            let shoppingItems = try context.fetch(shoppingRequest)
            
            items.append(contentsOf: todos)
            items.append(contentsOf: shoppingItems)
            
            LocationManager.shared.initializeWithItems(items, context: context)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                LocationManager.shared.loadAndMonitorAllGeofences(from: context)
            }
        } catch {
            print("❌ Error fetching items: \(error)")
        }
        
        // Rest of existing refresh code...
        UserDefaults.standard.set(Date(), forKey: "lastGeofenceRefresh")
    }
    
    // Function to load initial ad
    private func loadInitialAd() {
        // Only load ad if user is not premium
        if !entitlementManager.isPremiumUser {
            print("⏳ Loading initial ad for non-premium user")
            // Ad loading logic would go here
            // This would be similar to the RewardedAdSection implementation
        }
    }
    
    // Function to check if ads should be shown
    func shouldShowAds() -> Bool {
        return !entitlementManager.isPremiumUser
    }
    
    func handleAdChange(_ newAdReady: Bool) {
        if newAdReady && adManager.canShowAd() {
            print("🚀 Ad is ready and cooldown passed, setting showAd = true")
            DispatchQueue.main.async {
                self.showAd = true
            }
        }
    }
}

extension Notification.Name {
    static let quickActionTriggered = Notification.Name("quickActionTriggered")
}

class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        QuickActionsManager.shared.handleQuickActionItem(shortcutItem)
    }
}
