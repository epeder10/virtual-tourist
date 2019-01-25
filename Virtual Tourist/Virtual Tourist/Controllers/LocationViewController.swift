//
//  LocationViewController.swift
//  Virtual Tourist
//
//  Created by Eric Pedersen on 1/15/19.
//  Copyright © 2019 Eric Pedersen. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData
import SwiftyJSON

class LocationViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate, UICollectionViewDataSource {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var noImagesFoundLabel: UILabel!
    @IBOutlet weak var newCollectionButton: UIButton!

    var dataController:DataController!
    var images = [Image]()
    var page: Int = 1
    var pinLocation: CLLocationCoordinate2D!
    var fetchedPinsResultsController:NSFetchedResultsController<Pin>!
    var fetchedImageResultsController:NSFetchedResultsController<Image>!
    var pin:Pin?
    var numberOfImages:Int = 21
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        
        newCollectionButton.isEnabled = false
        noImagesFoundLabel.isHidden = true
        
        loadPin()
        loadImages()
        
        centerMapOnPin()
        
        loadNewImages()
    }

    /*
     Center the map on the pin that was selected by the user
    */
    func centerMapOnPin() {
        var annotations = [MKPointAnnotation]()
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = self.pinLocation
        annotations.append(annotation)
        self.mapView.addAnnotations(annotations)
        
        self.mapView.showAnnotations(annotations, animated: true)
    }
    
    /*
     If images.count == 0 then this pin has no images.  Start a new connection to Flickr and get images.
    */
    func loadNewImages() {
        if images.count == 0 {
            if let pin = pinLocation {
                FlickerClient.getImagesByLatLong(lat: pin.latitude, long: pin.longitude, date: getDate(), page: page, completion: getImagesCompletionHandler(data:error:))
            }
        } else {
            newCollectionButton.isEnabled = true
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    /*
     Dynamically determine the size of each image
    */
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellsAcross: CGFloat = 3
        let width = self.collectionView.bounds.width - 20
        let dim = (width / cellsAcross)
        return CGSize(width: dim, height: dim)
    }

    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCollectionCell", for: indexPath) as! FlickerImageViewCell
        if indexPath.row <= (self.images.count - 1) {
            let image = self.images[(indexPath as NSIndexPath).row]
            if let imageData = image.imageData {
                cell.flickerImage?.image = UIImage(data: imageData)
            } else {
                cell.flickerImage?.image = UIImage(named: "camera-flash")
                if let url = image.url {
                    FlickerClient.getPhoto(url: url, index: indexPath.row, completion: photoCompletionHandler(data:index:error:))
                }
            }
        }
        return cell
    }

    /*
     Check if all images have downloaded
    */
    private func checkAllImagesDownloaded() {
        for image in images {
            if image.imageData == nil {
                return
            }
        }
        newCollectionButton.isEnabled = true
    }
    /*
     User has clicked an image.  Remove it.
    */
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath:IndexPath) {
        let noteToDelete = images[indexPath.row]
        dataController.viewContext.delete(noteToDelete)
        try? dataController.viewContext.save()
        images.remove(at: indexPath.row)
        collectionView.reloadData()
    }
    
    /*
     Called when the getImages request completes.
     Iterate over each image from the getImages request and get each image
    */
    private func getImagesCompletionHandler(data: [JSON], error: Error?){
        if data.count > 0 {
            for photo in data {
                if let farm = photo["farm"].int, let server = photo["server"].string, let id = photo["id"].string, let secret = photo["secret"].string {
                    let imageUrl = FlickerClient.Endpoints.getPhoto(String(farm), server, id, secret).url
                    images.append(saveImage(url: imageUrl))
                    collectionView.reloadData()
                }
            }
        } else {
            noImagesFoundLabel.isHidden = false
        }
    }
    
    /*
     A single image download has completed
    */
    private func photoCompletionHandler(data: Data?, index: Int?, error: Error?) {
        if let data = data, let index = index {
            print("Photo download success")
            let image = images[index]
            image.imageData = data
            collectionView.reloadData()
        } else {
            print("Photo download failed: \(error?.localizedDescription ?? "" )")
        }
        checkAllImagesDownloaded()
    }
    
    /*
     Convert the image from Flickr to the internal data model
    */
    private func saveImage(url: URL) -> Image{
        let image = Image(context: dataController.viewContext)
        image.imageData = nil
        image.pin = pin
        image.url = url
        try? dataController.viewContext.save()
        return image
    }
    
    /*
     New Collection button action.  Gets new images from the next page
    */
    @IBAction func getNewCollectionButton(_ sender: Any) {
        newCollectionButton.isEnabled = false
        images = [Image]()
        page += 1
        pin?.page = Int32(page)
        if let pin = pinLocation {
            FlickerClient.getImagesByLatLong(lat: pin.latitude, long: pin.longitude, date: getDate(), page: page, completion: getImagesCompletionHandler(data:error:))
        }
    }
    
    /*
     Get the data from exactly a month ago.
    */
    private func getDate() -> String {
        let monthsToAdd = -1
        let daysToAdd = 1
        let currentDate = Date()
        
        var dateComponent = DateComponents()
        
        dateComponent.month = monthsToAdd
        dateComponent.day = daysToAdd
        
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: currentDate)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let futureDate = futureDate {
            return formatter.string(from: futureDate)
        }
        return ""
    }
    
    /*
     Get all images
     */
    private func loadImages() {
        let fetchRequest:NSFetchRequest<Image> = Image.fetchRequest()
        if let pin = pin {
            let predicate = NSPredicate(format: "pin == %@", pin)
            fetchRequest.predicate = predicate
            let sortDescriptor = NSSortDescriptor(key: "imageData", ascending: false)
            fetchRequest.sortDescriptors = [sortDescriptor]
            fetchedImageResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
            fetchedImageResultsController.delegate = self
            do {
                try fetchedImageResultsController.performFetch()
            } catch {
                fatalError("The fetch could not be performed: \(error.localizedDescription)")
            }
            
            if let result = try? dataController.viewContext.fetch(fetchRequest) {
                if result.count > 0 {
                    for img in result {
                        images.append(img)
                    }
                }
            }
        }
    }

    
    /*
    Get current pin
    */
    private func loadPin() {
        let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
        let predicate = NSPredicate(format: "longitude == %@ AND latitude == %@", argumentArray: [pinLocation.longitude, pinLocation.latitude])
        fetchRequest.predicate = predicate
        let sortDescriptor = NSSortDescriptor(key: "latitude", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedPinsResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedPinsResultsController.delegate = self
        do {
            try fetchedPinsResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
        
        if let result = try? dataController.viewContext.fetch(fetchRequest) {
            if result.count > 0 {
                self.pin = result[0]
            }
        }
    }
}
