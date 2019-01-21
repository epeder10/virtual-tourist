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
    
    var images = [UIImage]()
    var page: Int = 1
    var pinLocation: CLLocationCoordinate2D!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        
        newCollectionButton.isEnabled = false
        noImagesFoundLabel.isHidden = true
        
        var annotations = [MKPointAnnotation]()
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = self.pinLocation
        annotations.append(annotation)
        self.mapView.addAnnotations(annotations)
        
        self.mapView.showAnnotations(annotations, animated: true)
        
        if let pin = pinLocation {
            FlickerClient.getImagesByLatLong(lat: pin.latitude, long: pin.longitude, date: getDate(), page: page, completion: getImagesCompletionHandler(data:error:))
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 21
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
            cell.flickerImage?.image = image
        }else {
            cell.flickerImage?.image = UIImage(named: "camera-flash")
        }
        return cell
    }

    /*
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath:IndexPath) {
        
        let detailController = self.storyboard!.instantiateViewController(withIdentifier: "DetailViewController") as! DetailViewController
        detailController.meme = self.memes[(indexPath as NSIndexPath).row]
        self.navigationController!.pushViewController(detailController, animated: true)
        
    }
 */
    
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
            if let image = UIImage(data: data) {
                images.append(image)
                collectionView.reloadData()
            }
        } else {
            print("Photo download failed: \(error?.localizedDescription)")
        }
    }
    
    private func getDate() -> String {
        let monthsToAdd = -1
        let daysToAdd = 1
        let currentDate = Date()
        
        var dateComponent = DateComponents()
        
        dateComponent.month = monthsToAdd
        dateComponent.day = daysToAdd
        //dateComponent.year = yearsToAdd
        
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: currentDate)
        
        let formatter = DateFormatter()
        // initially set the format based on your datepicker date / server String
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let futureDate = futureDate {
            return formatter.string(from: futureDate)
        }
        return ""
    }
}
