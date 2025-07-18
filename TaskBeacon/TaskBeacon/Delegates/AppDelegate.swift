//
//  AppDelegate.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/8/25.
//

import CoreData
import FirebaseCore
import Foundation
import GoogleMobileAds
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    // Shared instance for app-wide access
    static let shared = AppDelegate()
    
    @Published var showAd: Bool = false
    @Published var isPrivacyOptionsRequired: Bool = false
    @Published var adManager = AdManager()

    // Entitlement management
    let entitlementManager = EntitlementManager.shared

    private var hasInitializedLocationManager = false
    private var isConsentGathered = false

    var window: UIWindow?
    
    override init() {
        super.init()
        
        print("🔍 AppDelegate.init() called")
        print("🔍 Setting adManager.entitlementManager = \(entitlementManager)")
        
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Set the entitlementManager on the adManager
        adManager.entitlementManager = entitlementManager
        
        print("🔍 adManager.entitlementManager set to: \(adManager.entitlementManager)")
        print("🔍 EntitlementManager.shared.isPremiumUser: \(entitlementManager.isPremiumUser)")
    }
    
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
            ErrorAlertManager.shared.showDataError("❌ Error fetching items: \(error)")

            print("❌ Error fetching items: \(error)")
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        if !hasInitializedLocationManager {
            initializeLocationManager()
            hasInitializedLocationManager = true
        }

        clearNotifications(application)

        Task {
            GoogleMobileAdsConsentManager.shared.gatherConsent { error in
                if let error = error {
                    ErrorAlertManager.shared.showDataError("❌ Consent gathering failed: \(error.localizedDescription)")

                    print("❌ Consent gathering failed: \(error.localizedDescription)")
                } else {
                    print("✅ Consent gathered successfully")
                }
            }
        }
        
        // Request notification permission
        NotificationDelegate.shared.requestNotificationPermission()
        
        FirebaseApp.configure()

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let lastRefresh = UserDefaults.standard.object(forKey: "lastGeofenceRefresh") as? Date,
           Date().timeIntervalSince(lastRefresh) < 300 { // 5 minutes
            return
        }
                
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
            ErrorAlertManager.shared.showDataError("❌ Error fetching items: \(error)")

            print("❌ Error fetching items: \(error)")
        }
        
        // Rest of existing refresh code...
        UserDefaults.standard.set(Date(), forKey: "lastGeofenceRefresh")
        
        checkTrialExpiration()
    }
    
    func checkTrialExpiration() {
        let isInTrial = FreeLimitChecker.isInTrialPeriod()
        let wasInTrial = UserDefaults.standard.bool(forKey: "wasInTrial")
                
        if wasInTrial && !isInTrial {
            // Trial just expired - post notification
            print(" Trial just expired - posting notification")
            NotificationCenter.default.post(name: .trialExpired, object: nil)
            UserDefaults.standard.set(false, forKey: "wasInTrial")
        } else if isInTrial {
            print(" User is in trial - setting wasInTrial to true")
            UserDefaults.standard.set(true, forKey: "wasInTrial")
        }
    }
    
    // Function to load initial ad
    func loadInitialAd() {
        // Only load ad if user is not premium
        if !entitlementManager.isPremiumUser && adManager.canRequestAds {
            print("⏳ Loading initial ad for non-premium user")
            DispatchQueue.main.async {
                self.adManager.canRequestAds = self.adManager.canRequestAds
                self.adManager.isPrivacyOptionsRequired = self.isPrivacyOptionsRequired

                self.adManager.isAdReady = true
            }
        }
    }
    
    // Function to check if ads should be shown
    func shouldShowAds() -> Bool {
        return !entitlementManager.isPremiumUser
    }
    
    func handleAdChange(_ newAdReady: Bool) {
        if newAdReady && adManager.canShowAd() {
            DispatchQueue.main.async {
                self.showAd = true
            }
        }
    }
}

extension Notification.Name {
    static let quickActionTriggered = Notification.Name("quickActionTriggered")
    static let trialExpired = Notification.Name("trialExpired")
}

class CustomSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        QuickActionsManager.shared.handleQuickActionItem(shortcutItem)
    }
}
