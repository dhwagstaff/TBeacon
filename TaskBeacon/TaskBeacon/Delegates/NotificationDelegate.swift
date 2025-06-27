//
//  NotificationDelegate.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/10/25.
//

import Foundation
import CoreLocation
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    
    static let shared = NotificationDelegate() // ✅ Singleton instance
    
    var recentlyPresentedNotifications: Set<String> = []
    private let notificationCooldown: TimeInterval = 30 // 300 == 5 minutes

    override init() {
        super.init()
    }
    
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted.")
            } else {
                print("❌ Notification permission denied.")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let identifier = notification.request.identifier
        
        if recentlyPresentedNotifications.contains(identifier) {
            completionHandler([])
        }
        
        recentlyPresentedNotifications.insert(identifier)

        completionHandler([.banner, .sound])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + notificationCooldown) {
            self.recentlyPresentedNotifications.remove(identifier)
        }
    }
    
    // Add UNUserNotificationCenterDelegate method to handle notification dismissal
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Get the notification identifier
        let identifier = response.notification.request.identifier
        
        // Remove from notifiedRegionIDs if it was a region notification
        if LocationManager.shared.notifiedRegionIDs.contains(identifier) {
            LocationManager.shared.notifiedRegionIDs.remove(identifier)
            print("🗑️ Removed notification for region: \(identifier)")
        }
        
        completionHandler()
    }
    
    func scheduleNotification(title: String, body: String, dueDate: Date? = nil, locationTrigger: CLCircularRegion? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        var trigger: UNNotificationTrigger?

        if let dueDate = dueDate {
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        }
        else if let locationTrigger = locationTrigger {
            trigger = UNLocationNotificationTrigger(region: locationTrigger, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification scheduled: \(title) \(locationTrigger != nil ? "(Location-Based)" : "(Time-Based)")")
            }
        }
    }
}
