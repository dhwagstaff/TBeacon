//
//  ErrorAlertManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 7/17/25.
//

import Foundation
import SwiftUI

class ErrorAlertManager: ObservableObject {
    static let shared = ErrorAlertManager()
    
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var errorTitle = "Error"
    @Published var showDismissButton = true
    @Published var dismissButtonText = "OK"
    
    private init() {}
    
    // MARK: - Error Types
    enum ErrorType {
        case network
        case data
        case subscription
        case location
        case camera
        case ad
        case general
        
        var title: String {
            switch self {
            case .network: return "Network Error"
            case .data: return "Data Error"
            case .subscription: return "Subscription Error"
            case .location: return "Location Error"
            case .camera: return "Camera Error"
            case .ad: return "Ad Error"
            case .general: return "Error"
            }
        }
    }
    
    // MARK: - Public Methods
    func showError(_ message: String, type: ErrorType = .general, dismissText: String = "OK") {
        DispatchQueue.main.async {
            self.errorTitle = type.title
            self.errorMessage = message
            self.dismissButtonText = dismissText
            self.showError = true
        }
    }
    
    func showNetworkError(_ message: String) {
        showError(message, type: .network)
    }
    
    func showDataError(_ message: String) {
        showError(message, type: .data)
    }
    
    func showSubscriptionError(_ message: String) {
        showError(message, type: .subscription)
    }
    
    func showLocationError(_ message: String) {
        showError(message, type: .location)
    }
    
    func showCameraError(_ message: String) {
        showError(message, type: .camera)
    }
    
    func showAdError(_ message: String) {
        showError(message, type: .ad)
    }
    
    func dismiss() {
        showError = false
    }
}
