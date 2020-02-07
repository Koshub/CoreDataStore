//
//  CoreDataStore.swift
//
//  Created by Konstiantyn Herasimov on 8/1/19.
//  Copyright © 2019 Konstiantyn Herasimov. All rights reserved.
//

import Foundation

#if os(iOS) || os(macOS) || targetEnvironment(simulator)
#if canImport(CoreData)
import CoreData


public final class CoreDataStore {
    
    public enum Error: Swift.Error {
        case notInitialized
        case alreadyInitialized
        case modelNotFound(at: URL)
        case custom(Swift.Error)
    }
    
    public enum State {
        case notInitialized
        case initializing
        case initialized
        case initializationFailed(Error)
    }
    
    public enum StoreType {
        case sqlite(storeURL: URL, fileProtection: FileProtectionType)
        case memory
        
        var value: String {
            switch self {
            case .sqlite(storeURL: _):
                return NSSQLiteStoreType
            case .memory:
                return NSInMemoryStoreType
            }
        }
    }
    
    private(set) var storeURL: URL
    #if os(iOS)
    private(set) var storeFileProtectionType: FileProtectionType
    #endif
    private(set) var modelURL: URL
    private(set) var storeType: StoreType
    private let containerName = "Model"
    public private(set) var state: State = .notInitialized
    
    fileprivate var coordinator: NSPersistentStoreCoordinator?
    fileprivate var model: NSManagedObjectModel?
    fileprivate var context: NSManagedObjectContext?
    
    public var viewContext: NSManagedObjectContext? {
        return context
    }
    
    public init(modelURL: URL, storeType: StoreType = .memory) {
        self.modelURL = modelURL
        self.storeType = storeType
        switch storeType {
        case .sqlite(storeURL: let url, fileProtection: let protectionType):
            self.storeURL = url
            #if os(iOS)
            self.storeFileProtectionType = protectionType
            #endif
        case .memory:
            self.storeURL = URL(string: "/dev/null")!
            #if os(iOS)
            self.storeFileProtectionType = .none
            #endif
        }
    }
    
    public func initialize(completion: @escaping (Swift.Result<Void, Error>) -> ()) {
        switch state {
        case .initialized, .initializing:
            completion(.failure(.alreadyInitialized))
        case .initializationFailed(let error):
            completion(.failure(error))
        case .notInitialized:
            state = .initializing
            
            if let model = NSManagedObjectModel(contentsOf: modelURL) {
                
                if #available(iOS 10.0, OSX 10.12, *) {
                    
                    let storeDescription = NSPersistentStoreDescription(url: self.storeURL)
                    storeDescription.type = storeType.value
                    storeDescription.shouldMigrateStoreAutomatically = true
                    storeDescription.shouldInferMappingModelAutomatically = true
                    #if os(iOS)
                    storeDescription.setOption(storeFileProtectionType as NSObject, forKey: NSPersistentStoreFileProtectionKey)
                    #endif
                    let container = NSPersistentContainer(name: containerName, managedObjectModel: model)
                    container.persistentStoreDescriptions = [storeDescription]
                    container.loadPersistentStores { [weak self] (_, error) in
                        guard let self = self else { return }
                        if let error = error {
                            self.state = .initializationFailed(Error.custom(error))
                            completion(.failure(.custom(error)))
                        } else {
                            self.coordinator = container.persistentStoreCoordinator
                            self.model = model
                            self.context = container.viewContext
                            
                            self.state = .initialized
                            completion(.success(()))
                        }
                    }
                    
                } else { // < #available(iOS 10.0, OSX 10.12, *)
                    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
                    
                    do {
                        var options: [AnyHashable: Any] = [
                            NSMigratePersistentStoresAutomaticallyOption: NSNumber(value: true),
                            NSInferMappingModelAutomaticallyOption: NSNumber(value: true)
                        ]
                        
                        #if os(iOS)
                        options[NSPersistentStoreFileProtectionKey] = storeFileProtectionType as NSObject
                        #endif
                        
                        try coordinator.addPersistentStore(ofType: storeType.value, configurationName: nil, at: self.storeURL, options: options)
                        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
                        context.persistentStoreCoordinator = coordinator
                        
                        self.coordinator = coordinator
                        self.context = context
                        self.model = model
                        
                        self.state = .initialized
                        completion(.success(()))
                    } catch {
                        self.state = .initializationFailed(.custom(error))
                        completion(.failure(.custom(error)))
                    }
                }
            } else {
                self.state = .initializationFailed(.modelNotFound(at: modelURL))
                completion(.failure(.modelNotFound(at: modelURL)))
            }
        }
    }
    
    public func backgroundContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return context
    }
    
    public static func defaultModelURL(name: String = "Model", bundle: Bundle = .main) -> URL? {
        return bundle.url(forResource: name, withExtension: "momd")
    }
    
    public static func defaultStoreURL(fileName: String = "model_v1.sqlite") -> URL? {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent(fileName)
    }
}


// MARK: - Transactions

public extension CoreDataStore {
    
    final class Transaction {
        
        public enum Result {
            case success
            case failure(CoreDataStore.Error)
        }
        
        private enum State {
            case running
            case commiting
            case committed
            case failed(CoreDataStore.Error)
            case cancelled
        }
        
        private weak var store: CoreDataStore?
        private var parentContext: NSManagedObjectContext
        private var transactionContext: NSManagedObjectContext
        private var state: State = .running
        
        
        public init(store: CoreDataStore, parentContext: NSManagedObjectContext) {
            self.store = store
            self.parentContext = parentContext
            self.transactionContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            self.transactionContext.parent = parentContext
        }
        
        deinit {
            if case .running = state {
                let transactionContext = self.transactionContext
                transactionContext.performAndWait {
                    transactionContext.reset()
                }
            }
        }
        
        @discardableResult
        public func run<T>(_ work: (_ store: CoreDataStore, _ context: NSManagedObjectContext) throws -> T) throws -> T {
            guard case .running = state else {
                throw Error.alreadyInitialized
            }
            guard let store = store, case .initialized = store.state else {
                state = .failed(.notInitialized)
                throw Error.notInitialized
            }
            
            return try work(store, transactionContext)
        }
        
        public func commit(receivingCompletionIn completionQueue: DispatchQueue = .main, _ completion: ((_ result: Result) -> ())? = nil) {
            switch state {
            case .running:
                state = .commiting
                transactionContext.perform {
                    do {
                        
                        if self.transactionContext.hasChanges {
                            try self.transactionContext.save()
                        }
                        
                        self.parentContext.perform {
                            do {
                                
                                try self.parentContext.save()
                                
                                self.state = .committed
                                completionQueue.async {
                                    completion?(.success)
                                }
                            } catch {
                                self.state = .failed(.custom(error))
                                completionQueue.async {
                                    completion?(.failure(.custom(error)))
                                }
                            }
                        }
                        
                    } catch {
                        self.state = .failed(.custom(error))
                        completionQueue.async {
                            completion?(.failure(.custom(error)))
                        }
                    }
                }
            default:
                completionQueue.async {
                    completion?(.failure(.notInitialized))
                }
            }
        }
        
        public func rollback(receivingCompletionIn completionQueue: DispatchQueue = .main, _ completion: (() -> ())? = nil) {
            switch state {
            case .running:
                state = .cancelled
                transactionContext.perform {
                    self.transactionContext.reset()
                    completionQueue.async {
                        completion?()
                    }
                }
            default:
                completionQueue.async {
                    completion?()
                }
            }
        }
    }
    
    func createTransaction(parentContext: NSManagedObjectContext? = nil) -> CoreDataStore.Transaction {
        let context = parentContext ?? backgroundContext()
        return Transaction(store: self, parentContext: context)
    }
}


public extension NSManagedObject {
    
    class var entityName: String {
        return String(describing: self).components(separatedBy: ".").last!
    }
    
    class func create<T: NSManagedObject>(context: NSManagedObjectContext) -> T {
        if #available(iOS 10.0, OSX 10.12,  *) {
            return T(context: context)
        } else {
            return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! T
        }
    }
}


public extension NSManagedObjectContext {
    
    enum FetchRanage {
        case single
        case all
        case range(NSRange)
    }
    
    enum FetchCondition {
        case `where`(NSPredicate)
        case `whereKey`(String, equalTo: Any)
    }
    
    func fetch<T: NSManagedObject>(allOf entity: T.Type, _ condition: FetchCondition? = nil, sortedBy sortDescriptors: [NSSortDescriptor]? = nil, range: FetchRanage = .all) throws -> [T] {
        
        let request: NSFetchRequest = NSFetchRequest<T>(entityName: entity.entityName)
        
        if let condition = condition {
            switch condition {
            case .where(let predicate):
                request.predicate = predicate
            case .`whereKey`(let key, equalTo: let value):
                request.predicate = .init(format: "%K == %@", argumentArray: [key, value])
            }            
        }
        
        request.sortDescriptors = sortDescriptors
        
        switch range {
        case .single:
            request.fetchLimit = 0
            request.fetchOffset = 0
        case .range(let range):
            request.fetchLimit = range.length
            request.fetchOffset = range.location
        case .all: break
        }
        
        return try fetch(request)
    }
    
    func fetch<T: NSManagedObject>(firstOf entity: T.Type, _ condition: FetchCondition? = nil) throws -> T? {
        return try fetch(allOf: entity, condition, range: .single).first
    }
}

#endif
#endif
