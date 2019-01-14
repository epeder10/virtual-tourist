//
//  DataController.swift
//  Virtual Tourist
//
//  Created by Eric Pedersen on 1/14/19.
//  Copyright © 2019 Eric Pedersen. All rights reserved.
//

import Foundation
import CoreData

class DataController {
    let persistentContainer:NSPersistentContainer
    
    var viewContext:NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    init(modelName:String) {
        persistentContainer = NSPersistentContainer(name: modelName)
    }
    
    func load(completion: (() -> Void)? = nil) {
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            self.autoSaveViewController()
            completion?()
        }
    }
}

extension DataController {
    func autoSaveViewController(interval: TimeInterval = 30) {
        print("autosaving")
        guard interval > 0 else {
            print("Can't set negative autosave interval")
            return
        }
        if viewContext.hasChanges {
            try? viewContext.save()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            self.autoSaveViewController(interval: interval)
        }
    }
}
