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
    var pinLocation: CLLocationCoordinate2D?
    
    var fetchedResultsController:NSFetchedResultsController<CurrentLocation>!
    var fetchedPinsResultsController:NSFetchedResultsController<Pin>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        
        longPress = UILongPressGestureRecognizer(target: self, action: #selector(MapViewController.handleLongPressOnMap(_:)))
        longPress?.minimumPressDuration = 1.5
        
        if let longPress = longPress {
            mapView.addGestureRecognizer(longPress)
        }
        
        loadCurrentLocation()
        reloadAllPins()
    }
    
    /*
     Long press creates a new pin.
    */
    @objc func handleLongPressOnMap(_ recognizer: UIGestureRecognizer){
        if recognizer.state == .began {
            let touchedAt = recognizer.location(in: self.mapView) // adds the location on the view it was pressed
            let touchedAtCoordinate : CLLocationCoordinate2D = self.mapView.convert(touchedAt, toCoordinateFrom: self.mapView) // will get coordinates
            let location: CLLocation = CLLocation(latitude: touchedAtCoordinate.latitude, longitude: touchedAtCoordinate.longitude)
            
            fetchCityAndCountry(from: location) { city, country, error in
                guard let city = city, let country = country, error == nil else { return }
                print(city + ", " + country)  // Rio de Janeiro, Brazil
                let annotation = MKPointAnnotation()
                annotation.coordinate = touchedAtCoordinate
                let locationName:String = "\(city), \(country)"
                annotation.title = locationName
                self.mapView.addAnnotation(annotation)
                
                self.savePin(touchedAtCoordinate, locationName: locationName)
            }
            
            //Reset this recognizer to get ready for another event
            recognizer.state = .ended
        }
    }
    
    /*
     User added a new pin.  Save it in the data model
    */
    private func savePin(_ touchedAtCoordinate: CLLocationCoordinate2D, locationName: String){
        let pin = Pin(context: dataController.viewContext)
        pin.latitude = touchedAtCoordinate.latitude
        pin.longitude = touchedAtCoordinate.longitude
        pin.locationName = locationName
        pin.numOfImages = 21
        pin.page = 1
    }
    
   /*
     Map view
    */
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .red
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    /*
     A user tapped on a pin.  Show the location and info disclosure
    */
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let coord = view.annotation?.coordinate {
            pinLocation = coord
            self.performSegue(withIdentifier: "showImages", sender: self)
        }
    }
    
    /*
     Prepare for a segue to the Location view controller
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let locationController = segue.destination as! LocationViewController
        locationController.pinLocation = self.pinLocation
        locationController.dataController = self.dataController
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
     Convert lat and long to city name and county
    */
    func fetchCityAndCountry(from location: CLLocation, completion: @escaping (_ city: String?, _ country:  String?, _ error: Error?) -> ()) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            completion(placemarks?.first?.locality,
                       placemarks?.first?.country,
                       error)
        }
    }
    
    /*
     Reload all pins
    */
    private func reloadAllPins(){
        let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "latitude", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedPinsResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedPinsResultsController.delegate = self
        do {
            try fetchedPinsResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
        
        if let results = try? dataController.viewContext.fetch(fetchRequest) {
            var annotations = [MKAnnotation]()
            if results.count > 0 {
                for result in results {
                    let annotation = MKPointAnnotation()
                    let location = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)
                    annotation.coordinate = location
                    annotation.title = result.locationName
                    annotations.append(annotation)
                }
            }
            self.mapView.addAnnotations(annotations)
        }
    }
    
    /*
     The maps current location persists between sessions.
     Load the past current location.
    */
    private func loadCurrentLocation() {
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
    }
    
    
}
