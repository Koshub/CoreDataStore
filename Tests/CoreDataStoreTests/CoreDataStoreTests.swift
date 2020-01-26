import XCTest

@testable import CoreDataStore

#if os(iOS) || os(macOS)
#if canImport(CoreData)
import CoreData
final class CoreDataStoreTests: XCTestCase {
    
    func testExample() {
        guard let modelURL = URL(string:"/dev/null") else { XCTFail(); return }
        let failureExpectation = expectation(description: "initialize.failure.modelNotFound")
        let store = CoreDataStore(modelURL: modelURL, storeType: .memory)
        store.initialize { (result) in
            switch result {
            case .success:
                break
            case .failure(let error):
                switch error {
                case .modelNotFound(at: let urlToSearchModel):
                    XCTAssertEqual(modelURL, urlToSearchModel)
                    failureExpectation.fulfill()
                default:
                    break
                }
            }
        }
        wait(for: [failureExpectation], timeout: 1)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
#endif
#endif
