//
//  MapView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 5/29/25.
//

import MapKit
import SwiftUI
import UIKit

struct MapView: UIViewRepresentable {
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var selectedLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Set initial region to user's location
        if let userLocation = LocationManager.shared.userLocation?.coordinate {
            mapView.setRegion(MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            ), animated: false)
        }
                
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude ?? 0, longitude: longitude ?? 0)
        
        mapView.setRegion(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 10000,
            longitudinalMeters: 10000
        ), animated: true)
        
        // Update annotations
        mapView.removeAnnotations(mapView.annotations)
        if let location = selectedLocation {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "LocationPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = .red
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.latitude = mapView.region.center.latitude
            parent.longitude = mapView.region.center.longitude
        }
    }
}
