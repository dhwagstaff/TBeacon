//
//  RatingHelper.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 7/1/25.
//

import Foundation
import StoreKit

class RatingHelper {
    static let shared = RatingHelper()
    
    private let userDefaults = UserDefaults.standard
    private let ratingRequestKey = "ratingRequestCount"
    private let lastRatingRequestKey = "lastRatingRequestDate"
    private let appLaunchCountKey = "appLaunchCount"
    
    private init() {}
    
    // Check if we should request a rating
    func shouldRequestRating() -> Bool {
        let hasRated = userDefaults.bool(forKey: "hasRatedApp")
        if hasRated { return false }

        let requestCount = userDefaults.integer(forKey: ratingRequestKey)
        let launchCount = userDefaults.integer(forKey: appLaunchCountKey)
        let lastRequest = userDefaults.object(forKey: lastRatingRequestKey) as? Date
        
        // Don't ask more than 3 times per year (Apple's limit)
        guard requestCount < 3 else { return false }
        
        // Don't ask on first few launches
        guard launchCount >= 5 else { return false }
        
        // Don't ask if we asked recently (at least 30 days)
        if let lastRequest = lastRequest {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
            guard daysSinceLastRequest >= 30 else { return false }
        }
        
        return true
    }
    
    // Request the rating
    func requestRating() {
        guard shouldRequestRating() else { return }
        
        // Increment request count
        let currentCount = userDefaults.integer(forKey: ratingRequestKey)
        userDefaults.set(currentCount + 1, forKey: ratingRequestKey)
        userDefaults.set(Date(), forKey: lastRatingRequestKey)
        
        userDefaults.set(true, forKey: "hasRatedApp")
        
        // Request the rating
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    // Increment app launch count
    func incrementLaunchCount() {
        let currentCount = userDefaults.integer(forKey: appLaunchCountKey)
        userDefaults.set(currentCount + 1, forKey: appLaunchCountKey)
    }
    
    // Request rating after user completes a task
    func requestRatingAfterTaskCompletion() {
        // Only ask after user has completed several tasks
        let completedTasksCount = userDefaults.integer(forKey: "completedTasksCount")
        userDefaults.set(completedTasksCount + 1, forKey: "completedTasksCount")
        
        // Ask for rating after 5 completed tasks
        if completedTasksCount >= 5 {
            requestRating()
        }
    }
    
    // Request rating after user adds several items
    func requestRatingAfterItemAddition() {
        let addedItemsCount = userDefaults.integer(forKey: "addedItemsCount")
        userDefaults.set(addedItemsCount + 1, forKey: "addedItemsCount")
        
        // Ask for rating after 10 added items
        if addedItemsCount >= 10 {
            requestRating()
        }
    }
}
