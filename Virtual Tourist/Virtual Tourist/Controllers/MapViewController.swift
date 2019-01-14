//
//  MapViewController.swift
//  Virtual Tourist
//
//  Created by Eric Pedersen on 1/11/19.
//  Copyright © 2019 Eric Pedersen. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    
    var longPress: UILongPressGestureRecognizer?
    var dataController:DataController!
    var currentLocation: CurrentLocation?
    
    var fetchedResultsController:NSFetchedResultsController<CurrentLocation>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        
        longPress = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.handleLongPressOnMap(_:)))
        longPress?.minimumPressDuration = 1.5
        
        let fetchRequest:NSFetchRequest<CurrentLocation> = CurrentLocation.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "latitude", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
        
        if let result = try? dataController.viewContext.fetch(fetchRequest) {
            if result.count > 0 {
                self.currentLocation = result[0]
                if let current = currentLocation {
                    let location = CLLocationCoordinate2D(latitude: current.latitude, longitude: current.longitude)
                    let span = MKCoordinateSpan(latitudeDelta: current.spanLatitude, longitudeDelta: current.spanLongitude)
                    let region = MKCoordinateRegion(center: location, span: span)
                    mapView.setRegion(region, animated: true)
                }
            }
        }
        
        if let longPress = longPress {
            mapView.addGestureRecognizer(longPress)
        }
    }
    
    @objc func handleLongPressOnMap(_ recognizer: UIGestureRecognizer){
        if recognizer.state == .began {
            let touchedAt = recognizer.location(in: self.mapView) // adds the location on the view it was pressed
            let touchedAtCoordinate : CLLocationCoordinate2D = self.mapView.convert(touchedAt, toCoordinateFrom: self.mapView) // will get coordinates

            let annotation = MKPointAnnotation()
            print("\(touchedAtCoordinate)")
            annotation.coordinate = touchedAtCoordinate
            annotation.title = "This is cool"
            self.mapView.addAnnotation(annotation)
            
            //Reset this recognizer to get ready for another event
            recognizer.state = .ended
        }
    }
    
    // MARK: - MKMapViewDelegate
    
    // Here we create a view with a "right callout accessory view". You might choose to look into other
    // decoration alternatives. Notice the similarity between this method and the cellForRowAtIndexPath
    // method in TableViewDataSource.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .red
            //let label = UILabel()
            //label.text = annotation.subtitle ?? ""
            //pinView!.detailCalloutAccessoryView = label
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    // This delegate method is implemented to respond to taps. It opens the system browser
    // to the URL specified in the annotationViews subtitle property.
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        //if control == view.rightCalloutAccessoryView {
        if let toOpen = view.annotation?.subtitle! {
            if let url = URL(string: toOpen) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    /*
     Delegate method to respond to map view changes
    */
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        if currentLocation == nil {
            self.currentLocation = CurrentLocation(context: dataController.viewContext)
        }
        if let current = self.currentLocation {
            let location = self.mapView.region
            current.longitude = location.center.longitude
            current.latitude = location.center.latitude
            current.spanLatitude = location.span.latitudeDelta
            current.spanLongitude = location.span.longitudeDelta
        }
    }
    /*
     func mapView(mapView: MKMapView, annotationView: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
     
     if control == annotationView.rightCalloutAccessoryView {
     let app = UIApplication.sharedApplication()
     app.openURL(NSURL(string: annotationView.annotation.subtitle))
     }
     }*/
    
    
    
}
