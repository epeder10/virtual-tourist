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
        
        var annotations = [MKPointAnnotation]()
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = self.pinLocation
        annotations.append(annotation)
        self.mapView.addAnnotations(annotations)
        
        self.mapView.showAnnotations(annotations, animated: true)
        
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
            }
        }else {
            cell.flickerImage?.image = UIImage(named: "camera-flash")
        }
        return cell
    }

    /*
     User has clicked an image.  Remove it and get another image
    */
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath:IndexPath) {
        images.remove(at: indexPath.row)
        pin?.numOfImages -= 1
        let noteToDelete = images[indexPath.row]
        dataController.viewContext.delete(noteToDelete)
        collectionView.reloadData()
    }
    
    private func getImagesCompletionHandler(data: [JSON], error: Error?){
        if data.count > 0 {
            for photo in data {
                print(photo)
                if let farm = photo["farm"].int, let server = photo["server"].string, let id = photo["id"].string, let secret = photo["secret"].string {
                    FlickerClient.getPhoto(farmId: farm, serverId: server, id: id, secret: secret, completion: photoCompletionHandler(data:error:))
                }
            }
        } else {
            noImagesFoundLabel.isHidden = false
        }
        newCollectionButton.isEnabled = true
    }
    
    func photoCompletionHandler(data: Data?, error: Error?) {
        if let data = data {
            print("Photo download success")
            let image = saveImage(imageData: data)
            images.append(image)
            collectionView.reloadData()
        } else {
            print("Photo download failed: \(error?.localizedDescription ?? "" )")
        }
    }
    
    private func saveImage(imageData: Data) -> Image{
        let image = Image(context: dataController.viewContext)
        image.imageData = imageData
        image.pin = pin
        try? dataController.viewContext.save()
        return image
    }
    
    @IBAction func getNewCollectionButton(_ sender: Any) {
        images = [Image]()
        page += 1
        pin?.page = Int32(page)
        if let pin = pinLocation {
            FlickerClient.getImagesByLatLong(lat: pin.latitude, long: pin.longitude, date: getDate(), page: page, completion: getImagesCompletionHandler(data:error:))
        }
    }
    
    private func getDate() -> String {
        let monthsToAdd = -1
        let daysToAdd = 1
        let currentDate = Date()
        
        var dateComponent = DateComponents()
        
        dateComponent.month = monthsToAdd
        dateComponent.day = daysToAdd
        
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: currentDate)
        
        let formatter = DateFormatter()
        // initially set the format based on your datepicker date / server String
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let futureDate = futureDate {
            return formatter.string(from: futureDate)
        }
        return ""
    }
    
    /*
     Get all images
     */
    func loadImages() {
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
    func loadPin() {
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
