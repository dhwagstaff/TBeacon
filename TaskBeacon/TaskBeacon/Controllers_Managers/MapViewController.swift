//
//  MapViewController.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/2/25.
//

import CoreLocation
import Foundation
import MapKit
import UIKit

class MapViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    var onLocationSelected: ((CLLocationCoordinate2D) -> Void)?
    var initialRegion: MKCoordinateRegion?
    
    private let locationManager = LocationManager.shared
    private var selectedLocation: CLLocationCoordinate2D?
    private var selectedLocationName: String?
    private var selectedLocationAddress: String?
    private var latitude: Double = 0.0
    private var longitude: Double = 0.0
    private var isForToDoItem: Bool = false
    
    var viewModel: ToDoListViewModel
    
    private var hasSelectedLocation: Bool = false {
        didSet {
            navigationItem.rightBarButtonItem?.isEnabled = hasSelectedLocation
        }
    }
    
    init(viewModel: ToDoListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        let context = PersistenceController.shared.container.viewContext
        self.viewModel = ToDoListViewModel(context: context)
        
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupNavigationBar()
        setupSearchBar()
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        locationManager.loadAndMonitorAllGeofences(from: PersistenceController.shared.container.viewContext)
        
        if let userLocation = locationManager.userLocation {
            // Convert 5 miles to meters (1 mile = 1609.34 meters)
            let radiusInMeters = 5.0 * 1609.34
            
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: radiusInMeters,
                longitudinalMeters: radiusInMeters
            )
            mapView.setRegion(region, animated: false)
        }
    }
    
    private func setupNavigationBar() {
        title = "Select Location"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        let saveButton = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        saveButton.isEnabled = false  // Initially disabled
        navigationItem.rightBarButtonItem = saveButton
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search location"
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.backgroundColor = .systemBackground
    }
    
    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
        // Store the selected location immediately
        selectedLocation = coordinate
        hasSelectedLocation = true
        
        // Remove any existing annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add new annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        
        // Get address information for the tapped location
        getAddressInfo(for: coordinate)
    }
    
    private func parseAddress(_ address: String) -> String {
        // Split the address by commas
        let components = address.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // If we have enough components
        if components.count >= 4 {
            // Remove any duplicate street names
            var streetComponents = components[0].components(separatedBy: " ")
            if streetComponents.count > 1 {
                // Check if the first component is a number
                if let _ = Int(streetComponents[0]) {
                    // Number is already at the start, use as is
                    return "\(components[0]), \(components[2]), \(components[3]) \(components.count > 4 ? components[4] : "")"
                } else {
                    // Number is in components[1], put it at the start
                    return "\(components[1]) \(components[0]), \(components[2]), \(components[3]) \(components.count > 4 ? components[4] : "")"
                }
            }
        }
        
        return address
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        // Format the address
        var addressComponents: [String] = []

        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        if let postalCode = placemark.postalCode {
            addressComponents.append(postalCode)
        }
        
        let address = addressComponents.joined(separator: ", ")
        
        let formattedAddress = parseAddress(address)
        
        // Add the formatted address
        components.append(formattedAddress)
        
        return components.joined(separator: ", ")
    }
    
    @objc private func cancelTapped() {
        hasSelectedLocation = false
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        // Always print the state when save is tapped
        guard let location = selectedLocation else {
            // Show alert that no location is selected
            let alert = UIAlertController(
                title: "No Location Selected",
                message: "Please tap on the map to select a location",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Create a temporary MKMapItem for the selected location
        let placemark = MKPlacemark(coordinate: location)
        let mapItem = MKMapItem(placemark: placemark)
        
        // Use the selected location name if available
        if !viewModel.selectedLocationName.isEmpty {
            mapItem.name = viewModel.selectedLocationName
        } else {
            mapItem.name = "Selected Location"
        }
        
        // Update the viewModel with the selected location
        viewModel.selectedLocation = location
        
        // Call the completion handler with the selected location
        onLocationSelected?(location)
        dismiss(animated: true)
    }
    
    private func getAddressInfo(for coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // Start with reverse geocoding first, which has a higher rate limit
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            guard let placemark = placemarks?.first else { return }
            
            // Check if we already have a POI name
            if let pointOfInterestName = placemark.areasOfInterest?.first {
                // Use the POI name directly
                self.viewModel.selectedLocationName = pointOfInterestName
                self.viewModel.selectedLocationAddress = self.formatAddress(from: placemark)
                
                // Update annotation
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = pointOfInterestName
                self.mapView.removeAnnotations(self.mapView.annotations)
                self.mapView.addAnnotation(annotation)
            } else {
                // Only perform a local search if we don't have a POI name
                let searchRequest = MKLocalSearch.Request()
                searchRequest.region = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 50,
                    longitudinalMeters: 50
                )
                
                // Use the thoroughfare as the search query if available
                if let thoroughfare = placemark.thoroughfare {
                    searchRequest.naturalLanguageQuery = thoroughfare
                }
                
                let search = MKLocalSearch(request: searchRequest)
                search.start { [weak self] response, error in
                    guard let self = self else { return }
                    
                    if let firstItem = response?.mapItems.first,
                       let businessName = firstItem.name,
                       !businessName.contains("Business District") {
                        // Business found
                        self.viewModel.selectedLocationName = businessName
                        self.viewModel.selectedLocationAddress = self.formatAddress(from: firstItem.placemark)
                        
                        // Update annotation
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = coordinate
                        annotation.title = businessName
                        self.mapView.removeAnnotations(self.mapView.annotations)
                        self.mapView.addAnnotation(annotation)
                    } else {
                        // Use the street address if no business found
                        let name = placemark.name ?? "Selected Location"
                        let address = self.formatAddress(from: placemark)
                        
                        self.viewModel.selectedLocationName = name
                        self.viewModel.selectedLocationAddress = address
                        
                        // Update annotation
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = coordinate
                        annotation.title = name
                        self.mapView.removeAnnotations(self.mapView.annotations)
                        self.mapView.addAnnotation(annotation)
                    }
                }
            }
        }
    }
}

// MARK: - MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
        
        let identifier = "LocationPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
}

// MARK: - UISearchBarDelegate
extension MapViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, !searchText.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showLocationNotFoundAlert()
                return
            }
            
            guard let response = response,
                  let firstItem = response.mapItems.first,
                  self.isValidSearchResult(firstItem, searchText: searchText) else {
                self.showLocationNotFoundAlert()
                return
            }
            
            self.mapView.removeAnnotations(self.mapView.annotations)
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = firstItem.placemark.coordinate
            annotation.title = firstItem.name
            self.mapView.addAnnotation(annotation)
            
            // Set the coordinates directly
            self.latitude = firstItem.placemark.coordinate.latitude
            self.longitude = firstItem.placemark.coordinate.longitude
            viewModel.latitude = self.latitude
            viewModel.longitude = self.longitude
            
            // Call the closure if needed
            self.onLocationSelected?(firstItem.placemark.coordinate)
            
            // Reverse geocode for address
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: self.latitude, longitude: self.longitude)
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    print("📍 MapViewWrapper: Got placemark - \(placemark.name ?? "Unknown")")
                    self.selectedLocationAddress = self.formatAddress(from: placemark)
                } else {
                    print("❌ MapViewWrapper: Failed to get placemark")
                }
                // ... handle dismiss if needed ...
            }
            
            self.selectedLocation = firstItem.placemark.coordinate
            self.selectedLocationName = firstItem.name
            self.hasSelectedLocation = true
            
            self.mapView.setRegion(
                MKCoordinateRegion(
                    center: firstItem.placemark.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ),
                animated: true
            )
        }
    }
    
//    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
//        guard let searchText = searchBar.text, !searchText.isEmpty else { return }
//        
//        let request = MKLocalSearch.Request()
//        request.naturalLanguageQuery = searchText
//        request.region = mapView.region
//        
//        let search = MKLocalSearch(request: request)
//        search.start { [weak self] response, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                // Handle search error
//                self.showLocationNotFoundAlert()
//                return
//            }
//            
//            guard let response = response,
//                  let firstItem = response.mapItems.first,
//                  // Add additional validation for the search result
//                  self.isValidSearchResult(firstItem, searchText: searchText) else {
//                self.showLocationNotFoundAlert()
//                return
//            }
//            
//            // Remove existing annotations
//            self.mapView.removeAnnotations(self.mapView.annotations)
//            
//            // Add new annotation
//            let annotation = MKPointAnnotation()
//            annotation.coordinate = firstItem.placemark.coordinate
//            annotation.title = firstItem.name
//            self.mapView.addAnnotation(annotation)
//            
//            // Store the selected location
//            self.selectedLocation = firstItem.placemark.coordinate
//            self.selectedLocationName = firstItem.name
//            self.selectedLocationAddress = self.formatAddress(from: firstItem.placemark)
//            self.hasSelectedLocation = true
//            
//            self.viewModel = viewModel
//            
//            self.onLocationSelected = { coordinate in
//                self.latitude = coordinate.latitude
//                self.longitude = coordinate.longitude
//                
//                // Get address for selected location
//                let geocoder = CLGeocoder()
//                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
//                
//                geocoder.reverseGeocodeLocation(location) { placemarks, error in
//                    if let placemark = placemarks?.first {
//                        print("📍 MapViewWrapper: Got placemark - \(placemark.name ?? "Unknown")")
//                        self.viewModel.selectedLocationAddress = self.formatAddress(from: placemark)
//                        
//                        print("📍 MapViewWrapper: Set location name to \(self.viewModel.selectedLocationName)")
//                        print("📍 MapViewWrapper: Set location address to \(self.viewModel.selectedLocationAddress)")
//                    } else {
//                        print("❌ MapViewWrapper: Failed to get placemark")
//                    }
//                    
//                    // Only dismiss if this is not for a to-do item
//                    if !self.isForToDoItem {
//                        print("📍 MapViewWrapper: Dismissing (not for to-do item)")
//                       // presentationMode.wrappedValue.dismiss()
//                    } else {
//                        print("📍 MapViewWrapper: Not dismissing (is for to-do item)")
//                    }
//                }
//            }
//            
//            // Center map on the result
//            self.mapView.setRegion(
//                MKCoordinateRegion(
//                    center: firstItem.placemark.coordinate,
//                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                ),
//                animated: true
//            )
//        }
//    }

    // Add this helper function to validate search results
    private func isValidSearchResult(_ mapItem: MKMapItem, searchText: String) -> Bool {
        // Check if the search result name contains the search text
        // or if the search text contains the result name
        let searchTextLower = searchText.lowercased()
        let resultNameLower = mapItem.name?.lowercased() ?? ""
        let resultAddressLower = mapItem.placemark.title?.lowercased() ?? ""
        
        // Check if the search text is part of the result name or address
        let isNameMatch = resultNameLower.contains(searchTextLower)
        let isAddressMatch = resultAddressLower.contains(searchTextLower)
        
        // Check if the result is too generic (like just a state name)
        let isTooGeneric = resultNameLower.count < 3 ||
                          resultNameLower == "business district" ||
                          resultNameLower == "downtown"
        
        return (isNameMatch || isAddressMatch) && !isTooGeneric
    }

    // Add this function to show the alert
    private func showLocationNotFoundAlert() {
        let alert = UIAlertController(
            title: "Location Not Found",
            message: "We couldn't find a location matching your search. Please try a different search term.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
//    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
//        guard let searchText = searchBar.text else { return }
//        
//        let request = MKLocalSearch.Request()
//        request.naturalLanguageQuery = searchText
//        request.region = mapView.region
//        
//        let search = MKLocalSearch(request: request)
//        search.start { [weak self] response, error in
//            guard let self = self,
//                  let response = response,
//                  let firstItem = response.mapItems.first else { return }
//            
//            // Remove existing annotations
//            self.mapView.removeAnnotations(self.mapView.annotations)
//            
//            // Add new annotation
//            let annotation = MKPointAnnotation()
//            annotation.coordinate = firstItem.placemark.coordinate
//            annotation.title = firstItem.name
//            self.mapView.addAnnotation(annotation)
//            
//            // Store the selected location
//            self.selectedLocation = firstItem.placemark.coordinate
//            self.selectedLocationName = firstItem.name
//            self.selectedLocationAddress = self.formatAddress(from: firstItem.placemark)
//            self.hasSelectedLocation = true  // Enable save button
//            
//            // Center map on the result
//            self.mapView.setRegion(
//                MKCoordinateRegion(
//                    center: firstItem.placemark.coordinate,
//                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                ),
//                animated: true
//            )
//        }
//    }
    
//    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
//        guard let searchText = searchBar.text else { return }
//        
//        let request = MKLocalSearch.Request()
//        request.naturalLanguageQuery = searchText
//        request.region = mapView.region
//        
//        let search = MKLocalSearch(request: request)
//        search.start { [weak self] response, error in
//            guard let self = self,
//                  let response = response,
//                  let firstItem = response.mapItems.first else { return }
//            
//            // Remove existing annotations
//            self.mapView.removeAnnotations(self.mapView.annotations)
//            
//            // Add new annotation
//            let annotation = MKPointAnnotation()
//            annotation.coordinate = firstItem.placemark.coordinate
//            annotation.title = firstItem.name
//            self.mapView.addAnnotation(annotation)
//            
//            // Store the selected location
//            self.selectedLocation = firstItem.placemark.coordinate
//            self.selectedLocationName = firstItem.name
//            self.selectedLocationAddress = self.formatAddress(from: firstItem.placemark)
//            
//            // Center map on the result
//            self.mapView.setRegion(
//                MKCoordinateRegion(
//                    center: firstItem.placemark.coordinate,
//                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                ),
//                animated: true
//            )
//        }
//    }
}
