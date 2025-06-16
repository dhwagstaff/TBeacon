//
//  SettingsView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import AVFoundation
import MapKit
import StoreKit
import SwiftUI

// In SettingsView.swift
struct SettingsView: View {
    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("enableDarkMode") private var enableDarkMode: Bool = false
    @AppStorage("distanceUnit") private var distanceUnit: String = "meters"

    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var appDelegate = AppDelegate.shared

    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var formErrorDescription: String = ""
    @State private var showPrivacyOptionsAlert: Bool = false
    @State private var isPrivacyOptionsButtonDisabled: Bool = false

    var radiusDisplay: String {
        let radiusMeters = UserDefaults.standard.double(forKey: "geofenceRadius")
        if distanceUnit == "miles" {
            let miles = radiusMeters / 1609.34
            return String(format: "%.2f mi", miles)
        } else {
            return "\(Int(radiusMeters)) m"
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Subscription")) {
                    if subscriptionsManager.purchasedProductIDs.contains("com.pocketmeapps.taskbeacon.premium") {
                        Text("✅ You have Task Beacon Premium!")
                            .foregroundColor(.green)
                            .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .clear, radius: 1)

                        Button("Manage Subscription") {
                            openAppStoreSubscriptionManagement()
                        }
                        .foregroundColor(colorScheme == .dark ? .accentColor.opacity(0.9) : .accentColor)
                    } else {
                        if !subscriptionsManager.products.isEmpty {
                            ForEach(subscriptionsManager.products, id: \.id) { product in
                                Button(action: {
                                    Task {
                                        await subscriptionsManager.buyProduct(product)
                                    }
                                }) {
                                    Text("Upgrade to \(product.displayName) for \(product.displayPrice)")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(colorScheme == .dark ? .accentColor.opacity(0.9) : .accentColor)
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            ProgressView("Loading purchase options...")
                                .foregroundColor(colorScheme == .dark ? .gray.opacity(0.7) : .secondary)
                                .onAppear {
                                    Task {
                                        await subscriptionsManager.loadProducts()
                                    }
                                }
                        }

                        Button("Restore Purchases") {
                            Task {
                                await subscriptionsManager.restorePurchases()
                            }
                        }
                        .foregroundColor(colorScheme == .dark ? .accentColor.opacity(0.9) : .accentColor)
                    }
                }

                // 🔹 Appearance
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $enableDarkMode)
                        .tint(colorScheme == .dark ? .accentColor.opacity(0.9) : .accentColor)
                }

                // Add new Permissions section
                Section(header: Text("Permissions")) {
                    // Location Permission Row
                    Button(action: {
                        Task {
                            if await permissionManager.checkAndRequestPermission(for: .location) {
                                // Permission granted, update status
                                locationStatus = LocationManager.shared.authorizationStatus
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Location Access")
                            Spacer()
                            locationStatusView
                        }
                    }
                    
                    // Camera Permission Row
                    Button(action: {
                        Task {
                            _ = await permissionManager.checkAndRequestPermission(for: .camera)
                        }
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                            Text("Camera Access")
                            Spacer()
                            cameraStatusView
                        }
                    }
                    
                    // Notifications Permission Row
                    Button(action: {
                        Task {
                            _ = await permissionManager.checkAndRequestPermission(for: .notifications)
                        }
                    }) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                            Text("Notifications")
                            Spacer()
                            notificationStatusView
                        }
                    }
                }
                
                Section(header: Text("Privacy")) {
                    Button("Privacy Settings") {
                        Task {
                            do {
                                try await GoogleMobileAdsConsentManager.shared.presentPrivacyOptionsForm()
                                // Update button state after presenting form
                                isPrivacyOptionsButtonDisabled = !GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired
                            } catch {
                                formErrorDescription = error.localizedDescription
                                showPrivacyOptionsAlert = true
                            }
                        }
                    }
                    .disabled(isPrivacyOptionsButtonDisabled)
                    
                    // Add consent status indicator
                    if !appDelegate.adManager.canRequestAds {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("Ad consent required")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onAppear {
                    // Existing permission status updates
                    locationStatus = LocationManager.shared.authorizationStatus
                    
                    // Update privacy button state
                    isPrivacyOptionsButtonDisabled = !GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired
                }
                .alert("Privacy Options Error", isPresented: $showPrivacyOptionsAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(formErrorDescription)
                }
                
                Section(header: Text("Distance Units")) {
                    Picker("Unit", selection: $distanceUnit) {
                        Text("Meters").tag("meters")
                        Text("Miles").tag("miles")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Add a section for location settings
                Section(header: Text("Location Settings")) {
                    HStack {
                        Text("Geofence Radius")
                        Spacer()
                        Text(radiusDisplay)
                            .foregroundColor(.secondary)
                    }
                    
                    // Geofence Radius Slider
                    Slider(
                        value: Binding(
                            get: { UserDefaults.standard.double(forKey: "geofenceRadius") },
                            set: { newValue in
                                UserDefaults.standard.set(newValue, forKey: "geofenceRadius")
                                // Update all existing geofences with new radius
                                LocationManager.shared.updateAllGeofenceRadii()
                            }
                        ),
                        in: 100...500,
                        step: 50
                    )
                    
                    // Location Accuracy Setting
                    Picker("Location Accuracy", selection: Binding(
                        get: { UserDefaults.standard.string(forKey: "locationAccuracy") ?? "medium" },
                        set: { UserDefaults.standard.set($0, forKey: "locationAccuracy") }
                    )) {
                        Text("High").tag("high")
                        Text("Medium").tag("medium")
                        Text("Low").tag("low")
                    }
                }
            }
            .padding(.top, -100)
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(colorScheme == .dark ? .gray.opacity(0.7) : .secondary)
                        .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .clear, radius: 1)
                }
            }
        }
        .onAppear {
            // Update permission statuses when view appears
            locationStatus = LocationManager.shared.authorizationStatus
        }
        .alert(permissionManager.permissionAlertTitle, isPresented: $permissionManager.showPermissionAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
            }
            Button(Constants.cancel, role: .cancel) {}
        } message: {
            Text(permissionManager.permissionAlertMessage)
        }
        .preferredColorScheme(enableDarkMode ? .dark : .light)
    }
    
    // Helper views for permission status indicators
    var locationStatusView: some View {
        Group {
            switch locationStatus {
            case .authorizedAlways:
                Image(systemName: ImageSymbolNames.checkmarkCircleFill)
                    .foregroundColor(.green)
            case .authorizedWhenInUse:
                Image(systemName: ImageSymbolNames.checkmarkCircleFill)
                    .foregroundColor(.yellow)
            case .denied, .restricted:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .notDetermined:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            @unknown default:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }
    
    var notificationStatusView: some View {
        Group {
            switch permissionManager.getPermissionStatus(for: .notifications) {
            case .authorized:
                Image(systemName: ImageSymbolNames.checkmarkCircleFill)
                    .foregroundColor(.green)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .notDetermined:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }

    var cameraStatusView: some View {
        Group {
            switch permissionManager.getPermissionStatus(for: .camera) {
            case .authorized:
                Image(systemName: ImageSymbolNames.checkmarkCircleFill)
                    .foregroundColor(.green)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .notDetermined:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func openAppStoreSubscriptionManagement() {
        guard let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

}

#Preview {
    SettingsView()
}
