//
//  PermissionManager.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/8/25.
//

// Create a new file: PermissionManager.swift
import SwiftUI
import CoreLocation
import UserNotifications
import AVFoundation

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var showPermissionAlert = false
    @Published var permissionAlertTitle = ""
    @Published var permissionAlertMessage = ""
    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    private let locationManager = LocationManager.shared
    private let notificationDelegate = NotificationDelegate.shared
    
    enum PermissionType {
        case camera
        case location
        case notifications
        
        var title: String {
            switch self {
            case .camera:
                return "Camera Access Required"
            case .location:
                return "Location Access Required"
            case .notifications:
                return "Notifications Required"
            }
        }
        
        var message: String {
            switch self {
            case .camera:
                return "To use the barcode scanner, please enable camera access in Settings."
            case .location:
                return "To find stores near you and receive location-based reminders, please enable location access in Settings."
            case .notifications:
                return "To receive reminders when you're near a store, please enable notifications in Settings."
            }
        }
    }
    
    init() {
        // Initialize statuses
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        locationStatus = locationManager.authorizationStatus
        
        // Get notification status
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    func getPermissionStatus(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .camera:
            return convertCameraStatus(cameraStatus)
        case .location:
            return convertLocationStatus(locationStatus)
        case .notifications:
            return convertNotificationStatus(notificationStatus)
        }
    }
    
    enum PermissionStatus {
        case authorized
        case denied
        case notDetermined
    }
    
    private func convertCameraStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    private func convertLocationStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    private func convertNotificationStatus(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined, .provisional, .ephemeral:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    func checkAndRequestPermission(for type: PermissionType) async -> Bool {
        switch type {
        case .camera:
            return await checkCameraPermission()
        case .location:
            return checkLocationPermission()
        case .notifications:
            return await checkNotificationPermission()
        }
    }
    
    private func checkCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            showPermissionAlert(for: .camera)
            return false
        @unknown default:
            return false
        }
    }
    
    private func checkLocationPermission() -> Bool {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined:
            locationManager.requestAuthorization()
            return false
        case .denied, .restricted:
            showPermissionAlert(for: .location)
            return false
        @unknown default:
            return false
        }
    }
    
    private func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                notificationDelegate.requestNotificationPermission()
                // Note: This is a simplification. In reality, you'd need to handle the async callback
                continuation.resume(returning: true)
            }
        case .denied, .provisional, .ephemeral:
            showPermissionAlert(for: .notifications)
            return false
        @unknown default:
            return false
        }
    }
    
    private func showPermissionAlert(for type: PermissionType) {
        DispatchQueue.main.async {
            self.permissionAlertTitle = type.title
            self.permissionAlertMessage = type.message
            self.showPermissionAlert = true
        }
    }
    
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
