//
//  HelperFunctions.swift
//  Virtual Tourist
//
//  Created by Eric Pedersen on 1/11/19.
//  Copyright © 2019 Eric Pedersen. All rights reserved.
//

import Foundation
import UIKit

class HelperFunctions {
    func showFailure(title: String, message: String, viewController: UIViewController) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.show(alertVC, sender: nil)
    }
}
