//
//  ViewController.swift
//  CoreDataStore
//
//  Created by Kostiantyn Herasimov on 10/25/2019.
//  Copyright (c) 2019 Kostiantyn Herasimov. All rights reserved.
//

import UIKit
import CoreDataStore
import CoreData

final class ViewController: UIViewController {

    var store: CoreDataStore?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        guard let modelURL = CoreDataStore.defaultModelURL() else { return }
        guard let storeURL = CoreDataStore.defaultStoreURL() else { return }
        
        store = CoreDataStore(modelURL: modelURL, storeType: .sqlite(storeURL: storeURL))
        guard let store = store else { return }
        
        store.initialize { (result) in
            switch result {
            case .success:
                guard let viewContext = store.viewContext else { return }
                let transaction = store.createTransaction()
                do {
                    
                    let request: NSFetchRequest<CDUser> = CDUser.fetchRequest()
                    let result = try viewContext.fetch(request)

                    for user in result {
                        print(user)
                    }
                    
                    try transaction.run { (store, context) -> Void in
                        let user = CDUser(context: context)
                        user.id = UUID().uuidString
                        user.firstName = "Kos"
                    }
                    
                    transaction.commit()
                } catch {
                    transaction.rollback()
                }
                
            default: break
            }
        }
 */
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

