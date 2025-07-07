//
//  NotificationDelegate.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/10/25.
//

import AVFAudio
import AVFoundation
import CoreLocation
import Foundation
import SwiftUI
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    @AppStorage("enableSpokenNotifications") private var enableSpokenNotifications: Bool = true {
        didSet {}
    }
    
    static let shared = NotificationDelegate() // ✅ Singleton instance
    
    var recentlyPresentedNotifications: Set<String> = []
    private let notificationCooldown: TimeInterval = 30 // 300 == 5 minutes
    
    private var speechSynthesizer = AVSpeechSynthesizer()

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
            print("🔔 Notification already recently presented, skipping")
            completionHandler([])
            return  // ✅ Add this return statement
        }
        
        recentlyPresentedNotifications.insert(identifier)
        
        if enableSpokenNotifications {
            speakNotification(notification)
        }
        
        completionHandler([.banner, .sound])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + notificationCooldown) {
            self.recentlyPresentedNotifications.remove(identifier)
        }
    }
    
    private func speakNotification(_ notification: UNNotification) {
        print("🗣️ App state: \(UIApplication.shared.applicationState.rawValue)")

        let content = notification.request.content
        
        // Create a natural language message
        var message = ""
        
        // ✅ Fix: Handle optional values properly
        let title = content.title
        
        if !title.isEmpty {
            message += title + ". "
        }
        
        let subtitle = content.subtitle
        
        if !subtitle.isEmpty {
            message += subtitle + ". "
        }
        
        let body = content.body
        
        if !body.isEmpty {
            message += body
        }
        
        // Don't speak if message is empty
        guard !message.isEmpty else {
            print("🔇 Message is empty, not speaking")
            return
        }
        
        DispatchQueue.main.async {
            // Create speech utterance
            let utterance = AVSpeechUtterance(string: message)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.5 // Slower rate for clarity
            utterance.pitchMultiplier = 1.0
            utterance.volume = 0.8
            
            print("🗣️ About to speak utterance")
            
            // Speak the notification
            self.speechSynthesizer.speak(utterance)
            
            print("🗣️ speak() called successfully")
            print("🗣️ Speaking notification: \(message)")
        }
    }
    
    // Add UNUserNotificationCenterDelegate method to handle notification dismissal
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Get the notification identifier
        let identifier = response.notification.request.identifier
        
        if enableSpokenNotifications {
            speakNotification(response.notification)
        }
        
        // Remove from notifiedRegionIDs if it was a region notification
        if LocationManager.shared.notifiedRegionIDs.contains(identifier) {
            LocationManager.shared.notifiedRegionIDs.remove(identifier)
            print("🗑️ Removed notification for region: \(identifier)")
        }
        
        completionHandler()
    }
    
    func scheduleNotification(title: String,
                              body: String,
                              dueDate: Date? = nil,
                              locationTrigger: CLCircularRegion? = nil,
                              identifier: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default

        var trigger: UNNotificationTrigger?

        if let dueDate = dueDate {
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        } else if let locationTrigger = locationTrigger {
            trigger = UNLocationNotificationTrigger(region: locationTrigger, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: identifier ?? UUID().uuidString,
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
