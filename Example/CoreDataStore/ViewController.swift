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
                let transaction = store.createTransaction()
                do {
                    try transaction.run { _, context in
                        
                        print("Existed: \n \(try context.fetch(User.self))")
                        try context.delete(User.self)
                        print("After delete: \n \(try context.fetch(User.self))")
                        try context.insert([ User(), User(), User(id: "1", firstName: "Special") ])
                        print("After insert: \n \(try context.fetch(User.self))")
                        let special = try context.fetch(User.self, byID: "1")
                        print(String(describing: special))
                    }
                    transaction.commit()
                } catch {
                    transaction.rollback()
                }
            default: break
            }
        }
    }
}


struct User {
    var id = UUID().uuidString
    var firstName = UUID().uuidString
}


extension User: CoreDataStoreRepresentable, StoreIdentifiable {
    
    typealias RepresentationRequest = NSFetchRequest<CDUser>
    
    static var identifierKey: String { "id" }
    
    static func from(_ representation: CDUser, in context: NSManagedObjectContext) throws -> User {
        .init(id: representation.id ?? "", firstName: representation.firstName ?? "")
    }
    
    func update(_ representation: CDUser, in context: NSManagedObjectContext) throws {
        representation.id = id
        representation.firstName = firstName
    }
}
