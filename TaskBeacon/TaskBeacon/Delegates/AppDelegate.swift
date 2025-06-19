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
            print("❌ Error fetching items: \(error)")
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if !hasInitializedLocationManager {
            initializeLocationManager()
            hasInitializedLocationManager = true
        }

        clearNotifications(application)
        
        print("🚀 Initializing Google Mobile Ads SDK...")
        
     //   MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["d848514766cb1b5f090f430b07efcc7d"]
        
        // Delay consent gathering to ensure window is ready
        // Start the consent flow
        Task {
            GoogleMobileAdsConsentManager.shared.gatherConsent { error in
                if let error = error {
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
    
    
//    private func gatherConsentAndInitializeSDK() {
//        print("🔄 Gathering consent...")
//        isConsentGathered = false
//        
//        // Ensure we have a window and root view controller before proceeding
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//              let window = windowScene.windows.first,
//              let rootViewController = window.rootViewController else {
//            print("❌ No window or root view controller available for consent gathering")
//            return
//        }
//        
//        GoogleMobileAdsConsentManager.shared.gatherConsent { [weak self] consentError in
//            guard let self = self else { return }
//            
//            if let consentError {
//                print("❌ Consent gathering failed: \(consentError.localizedDescription)")
//                return
//            }
//            
//            // Update consent status
//            Task { @MainActor in
//                await self.adManager.updateConsentStatus()
//                self.isPrivacyOptionsRequired = self.adManager.isPrivacyOptionsRequired
//                self.isConsentGathered = self.adManager.canRequestAds
//            }
//            
////            DispatchQueue.main.async {
////                self.isPrivacyOptionsRequired = GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired
////                self.adManager.canRequestAds = GoogleMobileAdsConsentManager.shared.canRequestAds
////                
////                print("📊 Consent Status - canRequestAds: \(self.adManager.canRequestAds), isPrivacyOptionsRequired: \(self.isPrivacyOptionsRequired)")
////                
////                // Only initialize SDK after consent is gathered
////                if self.adManager.canRequestAds {
////                    print("✅ Consent granted, initializing SDK...")
////                    GoogleMobileAdsConsentManager.shared.startGoogleMobileAdsSDK()
////                    
////                    // SDK is now initialized, proceed with ad loading
////                    self.isConsentGathered = true
////                    self.loadInitialAd()
////                } else {
////                    print("⚠️ Cannot request ads due to consent status")
////                }
////            }
//        }
//    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let lastRefresh = UserDefaults.standard.object(forKey: "lastGeofenceRefresh") as? Date,
           Date().timeIntervalSince(lastRefresh) < 300 { // 5 minutes
            return
        }
        
        print("📲 App became active. Refreshing geofences.")
        
        // Revalidate consent when app becomes active
//        if !isConsentGathered {
//            print("🔄 Revalidating consent status...")
//            gatherConsentAndInitializeSDK()
//        }
        
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
    func loadInitialAd() {
        // Only load ad if user is not premium
        if !entitlementManager.isPremiumUser && adManager.canRequestAds {
            print("⏳ Loading initial ad for non-premium user")
            DispatchQueue.main.async {
                self.adManager.canRequestAds = self.adManager.canRequestAds
                self.adManager.isPrivacyOptionsRequired = self.isPrivacyOptionsRequired

                self.adManager.isAdReady = true
                
                print("app delegate 📊 AdManager consent status updated - canRequestAds: \(self.adManager.canRequestAds)")
            }
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
