# CoreDataStore

[![CI Status](https://img.shields.io/travis/Koshub/CoreDataStore.svg?style=flat)](https://travis-ci.org/Koshub/CoreDataStore)
[![Version](https://img.shields.io/cocoapods/v/CoreDataStore.svg?style=flat)](https://cocoapods.org/pods/CoreDataStore)
[![License](https://img.shields.io/cocoapods/l/CoreDataStore.svg?style=flat)](https://cocoapods.org/pods/CoreDataStore)
[![Platform](https://img.shields.io/cocoapods/p/CoreDataStore.svg?style=flat)](https://cocoapods.org/pods/CoreDataStore)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

CoreDataStore currently is not available through [CocoaPods](https://cocoapods.org) public repo. To install
it, simply add the following line to your Podfile:

```ruby
pod 'CoreDataStore'
```

## Example

Initialize store:
```Swift
guard let modelURL = CoreDataStore.defaultModelURL() else { return }
guard let storeURL = CoreDataStore.defaultStoreURL() else { return }

let store = CoreDataStore(
    modelURL: modelURL,
    storeType: .sqlite(
        storeURL: storeURL,
        fileProtection: .complete
    )
)
store.initialize { (result) in
    switch result {
    case .success:
        // Now - use store
    default: break
    }
}
```
Extend some type (here `User`) to be stored by some store representation (for example, you have some`CDUser` CoreData entity):
```Swift
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
```
Manage store data:
```Swift
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
```

## Author

Koshub

## License

CoreDataStore is available under the MIT license. See the LICENSE file for more info.
