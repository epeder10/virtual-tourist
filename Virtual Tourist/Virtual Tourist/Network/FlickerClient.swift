//
//  FlickerClient.swift
//  Virtual Tourist
//
//  Created by Eric Pedersen on 1/19/19.
//  Copyright © 2019 Eric Pedersen. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

class FlickerClient {
    struct Auth {
        static var apiKey = "85f04ede2bc6b41234e0fdc37ecdc473"
        //static var apiKey = "a7a564b411d3c9fb8341e8a74c3da9b8"
        static var frob = ""
    }
    
    enum Endpoints {
        static let base = "https://api.flickr.com/services/rest/"
        
        case getPhotosByLocation(String, String, String, String)
        case getPhoto(String, String, String, String)
        
        var stringValue: String {
            switch self {
            //case .getPhotosByLocation(let lat, let long): return Endpoints.base + "?method=flickr.photos.search&api_key=\(Auth.apiKey)&lat=\(lat)&long=\(long)&min_upload_date=2018-01-01%2000:00:00.000000&format=json&per_page=15&page=1&nojsoncallback=1"
            case .getPhotosByLocation(let lat, let long, let date, let page): return Endpoints.base + "?method=flickr.photos.search&api_key=\(Auth.apiKey)&lat=\(lat)&lon=\(long)&max_upload_date=\(date)&format=json&per_page=21&page=1&page=\(page)&safe_search=1&radius=2&nojsoncallback=1"
            case .getPhoto(let farmId, let serverId, let id, let secret): return "https://farm\(farmId).staticflickr.com/\(serverId)/\(id)_\(secret).jpg"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    /*
     https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=a7a564b411d3c9fb8341e8a74c3da9b8&lat=42.393337792180745&lon=-71.06250898792659&format=json&nojsoncallback=1
     */
    class func getImagesByLatLong(lat: Double, long: Double, date: String, page: Int, completion: @escaping([JSON], Error?) -> Void) {
        
        Alamofire.request(Endpoints.getPhotosByLocation(String(lat), String(long), date, String(page)).url).responseJSON(completionHandler: { (response) in
            if response.error != nil {
                completion([], response.error)
            } else {
                print("Request: \(String(describing: response.request))")   // original url request
                if let json = response.data {
                    print("JSON: \(json)") // serialized json response
                    let jsResponse = JSON(json)
                    if jsResponse["code"].exists() && jsResponse["message"].exists(){
                        print("\(jsResponse["code"]) \(jsResponse["message"])")
                        completion([], nil)
                    } else {
                        let photo = jsResponse["photos"]["photo"].array
                        if let photo = photo {
                            completion(photo, nil)
                        }
                    }
                }
            }
        })
    }
    
    class func getPhoto(farmId: Int, serverId: String, id: String, secret: String, completion: @escaping(Data?, Error?) -> Void) {
        Alamofire.request(Endpoints.getPhoto(String(farmId), serverId, id, secret).url).responseData { (response) in
            print("Request: \(String(describing: response.request))")
            if response.error != nil {
                completion(nil, response.error)
            } else {
                if let data = response.data {
                    completion(data, nil)
                }
            }
        }
    }
    /*class func getFrob(completion: @escaping (Bool, Error?) -> Void) {
        Alamofire.request(Endpoints.getFrob.url).responseJSON { (response) in
            if response.error != nil {
                completion(false, response.error)
            }
            else if let json = response.result.value {
                let response = json as! NSDictionary
                Auth.frob = response["frob"] as! String
                completion(true, nil)
            }
        }
    }*/
}
