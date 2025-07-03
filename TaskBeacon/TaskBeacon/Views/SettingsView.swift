//
//  SettingsView.swift
//  SmartReminders
//
//  Created by Dean Wagstaff on 2/5/25.
//

import AVFoundation
import MapKit
import SafariServices
import StoreKit
import SwiftUI

// In SettingsView.swift
struct SettingsView: View {
    @AppStorage("preferredStoreName") private var preferredStoreName: String = ""
    @AppStorage("preferredStoreAddress") private var preferredStoreAddress: String = ""
    @AppStorage("preferredStoreLatitude") private var preferredStoreLatitude: Double = 0.0
    @AppStorage("preferredStoreLongitude") private var preferredStoreLongitude: Double = 0.0
    @AppStorage("enableDarkMode") private var enableDarkMode: Bool = false
    @AppStorage("distanceUnit") private var distanceUnit: String = "meters"
    @AppStorage("enableSpokenNotifications") private var enableSpokenNotifications: Bool = false

    @EnvironmentObject var subscriptionsManager: SubscriptionsManager
    @EnvironmentObject var preferredStoreManager: PreferredStoreManager
    @EnvironmentObject var viewModel: ShoppingListViewModel
    @EnvironmentObject var locationManager: LocationManager

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var appDelegate = AppDelegate.shared

    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var formErrorDescription: String = ""
    @State private var showPrivacyOptionsAlert: Bool = false
    @State private var isPrivacyOptionsButtonDisabled: Bool = false
    @State private var showHelpView = false
    @State private var showPreferredStoreSelection = false
    @State private var selectedStoreName: String = ""
    @State private var selectedStoreAddress: String = ""
    @State private var selectedLatitude: Double = 0.0
    @State private var selectedLongitude: Double = 0.0
    @State private var showPrivacyPolicy: Bool = false

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
                Section("Support") {
                    Button(action: {
                        showHelpView = true
                    }) {
                        Label("Help & Guide", systemImage: "questionmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Legal")) {
                    Button("Privacy Policy") {
                        showPrivacyPolicy = true
                    }
                }
                
                Section(header: Text("Preferred Store")) {
                    if !preferredStoreName.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Current Preferred Store")
                                    .font(.headline)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preferredStoreName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(preferredStoreAddress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Button("Change Store") {
                                    showPreferredStoreSelection = true
                                }
                                .buttonStyle(.bordered)
                                
                                Spacer()
                                
                                Button("Clear Preferred Store") {
                                    preferredStoreManager.clearPreferredStore()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No Preferred Store Set")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Set a preferred store to automatically assign it to new shopping items.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Set Preferred Store") {
                                showPreferredStoreSelection = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Subscription")) {
                    let hasPremiumSubscription = subscriptionsManager.purchasedProductIDs.contains("PMA_TBPM_25") ||
                                                subscriptionsManager.purchasedProductIDs.contains("PMA_TBPA_25")

                    if hasPremiumSubscription {
                        let subscriptionType = subscriptionsManager.purchasedProductIDs.contains("PMA_TBPM_25") ? "Monthly" : "Annual"

                        Text("✅ You have Task Beacon Premium (\(subscriptionType))!")
                            .foregroundColor(.green)
                            .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .clear, radius: 1)

                        Button("Manage Subscription") {
                            openAppStoreSubscriptionManagement()
                        }
                        .foregroundColor(colorScheme == .dark ? .accentColor.opacity(0.9) : .accentColor)
                    } else {
                        if !subscriptionsManager.products.isEmpty {
                            ForEach(subscriptionsManager.products, id: \.id) { product in
                                // Only show upgrade options for subscriptions the user doesn't already have
                                if !subscriptionsManager.purchasedProductIDs.contains(product.id) {
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
                    
                    Button("Force Consent Form (Debug)") {
                        Task {
                            do {
                                print("�� Force consent form tapped")
                                try await GoogleMobileAdsConsentManager.shared.presentPrivacyOptionsForm()
                            } catch {
                                print("❌ Force consent error: \(error.localizedDescription)")
                                formErrorDescription = error.localizedDescription
                                showPrivacyOptionsAlert = true
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    
                    // Improved consent status indicator
                    if !appDelegate.adManager.canRequestAds {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("Ad consent required - Tap 'Privacy Settings' above")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ad consent granted")
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
                
//                Section(header: Text("Privacy")) {
//                    Button("Privacy Settings") {
//                        Task {
//                            do {
//                                try await GoogleMobileAdsConsentManager.shared.presentPrivacyOptionsForm()
//                                // Update button state after presenting form
//                                isPrivacyOptionsButtonDisabled = !GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired
//                            } catch {
//                                formErrorDescription = error.localizedDescription
//                                showPrivacyOptionsAlert = true
//                            }
//                        }
//                    }
//                    .disabled(isPrivacyOptionsButtonDisabled)
//                    
//                    // Add consent status indicator
//                    if !appDelegate.adManager.canRequestAds {
//                        HStack {
//                            Image(systemName: "exclamationmark.triangle.fill")
//                                .foregroundColor(.yellow)
//                            Text("Ad consent required")
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                }
//                .onAppear {
//                    // Existing permission status updates
//                    locationStatus = LocationManager.shared.authorizationStatus
//                    
//                    // Update privacy button state
//                    isPrivacyOptionsButtonDisabled = !GoogleMobileAdsConsentManager.shared.isPrivacyOptionsRequired
//                }
//                .alert("Privacy Options Error", isPresented: $showPrivacyOptionsAlert) {
//                    Button("OK", role: .cancel) { }
//                } message: {
//                    Text(formErrorDescription)
//                }
                
                Section(header: Text("Notifications")) {
                    Button("Test Spoken Notification") {
                        let content = UNMutableNotificationContent()
                        content.title = "Test Notification"
                        content.body = "This is a test of spoken notifications"
                        content.sound = .default
                        
                        let request = UNNotificationRequest(
                            identifier: "test_spoken_\(Date().timeIntervalSince1970)",
                            content: content,
                            trigger: nil
                        )
                        
                        UNUserNotificationCenter.current().add(request) { error in
                            if let error = error {
                                print("❌ Test notification failed: \(error.localizedDescription)")
                            } else {
                                print("✅ Test notification scheduled")
                            }
                        }
                    }
                    
                    Toggle("Spoken Notifications", isOn: $enableSpokenNotifications)
                        .tint(.blue)
                    
                    if enableSpokenNotifications {
                        Text("Siri will read your location-based reminders aloud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                
                Section(header: Text("Debug Settings")) {
                    HStack {
                        Text("Current Trial Limit")
                        Spacer()
                        Text("\(FreeLimitChecker.getCurrentLimit())")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Trial Limit Override")
                        Spacer()
                        Text("\(UserDefaults.standard.integer(forKey: "debug_trial_limit"))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Button("Set Trial Limit: 10") {
                            UserDefaults.standard.set(10, forKey: "debug_trial_limit")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Set Trial Limit: 50") {
                            UserDefaults.standard.set(50, forKey: "debug_trial_limit")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear Override") {
                            UserDefaults.standard.removeObject(forKey: "debug_trial_limit")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    
                    HStack {
                        Text("Free Limit Override")
                        Spacer()
                        Text("\(UserDefaults.standard.integer(forKey: "debug_free_limit"))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Button("Set Free Limit: 3") {
                            UserDefaults.standard.set(3, forKey: "debug_free_limit")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Set Free Limit: 5") {
                            UserDefaults.standard.set(5, forKey: "debug_free_limit")
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear Override") {
                            UserDefaults.standard.removeObject(forKey: "debug_free_limit")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    
                    Button("Reset Trial Data") {
                        FreeLimitChecker.resetTrialForTesting()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(.top, -100)
            .sheet(isPresented: $showPrivacyPolicy) {
                SafariView(url: URL(string: "https://taskbeaconsupport.github.io/taskbeaconsupportandfeedback/PrivacyPolicy")!)            }
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
        .sheet(isPresented: $showHelpView) {
            HelperView()
        }
        .sheet(isPresented: $showPreferredStoreSelection) {
            MapView(
                cameraPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: preferredStoreLatitude != 0.0 ? preferredStoreLatitude : 40.7128,
                        longitude: preferredStoreLongitude != 0.0 ? preferredStoreLongitude : -74.0060
                    ),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )),
                mapIsForShoppingItem: true,
                onLocationSelected: { coordinate, name, address in
                    // Update the preferred store
                    preferredStoreName = name
                    preferredStoreAddress = address
                    preferredStoreLatitude = coordinate.latitude
                    preferredStoreLongitude = coordinate.longitude
                    
                    // Also update the PreferredStoreManager if you're using it
                    preferredStoreManager.setPreferredStore(
                        name: name,
                        address: address,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                    
                    showPreferredStoreSelection = false
                }
            )
            .environmentObject(locationManager)
            .environmentObject(viewModel)
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

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    SettingsView()
}
