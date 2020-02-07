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
        
        let store = CoreDataStore(
            modelURL: modelURL,
            storeType: .sqlite(
                storeURL: storeURL,
                fileProtection: .complete
            )
        )
        self.store = store
        store.initialize { (result) in
            switch result {
            case .success:
                guard let viewContext = store.viewContext else { return }
                let transaction = store.createTransaction()
                do {
                    
                    let single = try viewContext.fetch(firstOf: CDUser.self)
                    print(single)
                    
                    let kosUsers = try viewContext.fetch(
                        allOf: CDUser.self,
                        .whereKey("firstName", equalTo: "Kos")
                    )
                    kosUsers.forEach { print($0) }
                    
                    let users = try viewContext.fetch(allOf: CDUser.self)
                    users.forEach { print($0.firstName) }
                    
                    try transaction.run { (store, context) -> Void in
                        let user = CDUser(context: context)
                        user.id = UUID().uuidString
                        user.firstName = "Kos \(Int.random(in: 0...100))"
                    }
                    
                    transaction.commit()
                } catch {
                    transaction.rollback()
                }
                
            default: break
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

