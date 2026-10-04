import XCTest
@testable import BookShelf

/// Proje kurulumunun doğru olduğunu doğrulayan "duman testi" (smoke test).
///
/// `@testable import BookShelf`: Uygulama modülündeki `internal` tipleri (ör. `Book`, `LocalBookService`)
/// testlerden görebilmemizi sağlar. Normalde `internal` tipler modül dışına kapalıdır.
final class ProjectSetupTests: XCTestCase {
    /// Uygulama paketindeki `books.json` okunabiliyor ve çözümlenebiliyor mu?
    func testBundledBooksDecode() async throws {
        let service = LocalBookService(latency: .zero)
        let books = try await service.fetchBooks()
        XCTAssertEqual(books.count, 8)
    }

    /// Objective-C köprüsü (bridging header) test hedefinden de görünüyor mu?
    func testObjectiveCBridgeIsVisible() {
        let estimator = ReadingTimeEstimator(pagesPerHour: 40)
        XCTAssertEqual(estimator.pagesPerHour, 40)
    }
}
