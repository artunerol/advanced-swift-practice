import XCTest
@testable import BookShelf

/// Uygulamanın gerçek servisi `LocalBookService` için testler.
///
/// Gecikme `.zero` verildiğinde testler milisaniyeler içinde biter. Servis `Bundle.main`'den okur; birim test
/// hedefi uygulamanın İÇİNDE (host application) çalıştığı için `Bundle.main` uygulama paketidir.
///
/// Bu testler hiçbir actor'e bağlı değil (`@MainActor` yok): servis de nonisolated olduğu için gerek yok.
final class LocalBookServiceTests: XCTestCase {
    private let service = LocalBookService(latency: .zero)

    func testFetchBooksDecodesAllEightBooks() async throws {
        let books = try await service.fetchBooks()

        XCTAssertEqual(books.count, 8)
        XCTAssertEqual(books.map(\.id), Array(1...8))
        XCTAssertEqual(books.first?.title, "Tutunamayanlar")
    }

    func testFetchReviewsIsDeterministic() async throws {
        let first = try await service.fetchReviews(for: 3)
        let second = try await service.fetchReviews(for: 3)

        XCTAssertEqual(first, second, "Aynı kitap için her seferinde aynı yorumlar gelmeli")
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(first.map(\.id), [300, 301, 302]) // id = bookID * 100 + sıra
        XCTAssertTrue(first.allSatisfy { $0.bookID == 3 })
        XCTAssertTrue(first.allSatisfy { (1...5).contains($0.rating) })
    }

    func testFetchAuthorProfileCountsBooksByAuthor() async throws {
        let profile = try await service.fetchAuthorProfile(named: "Oğuz Atay")

        XCTAssertEqual(profile.name, "Oğuz Atay")
        XCTAssertEqual(profile.bookCount, 2) // Tutunamayanlar + Tehlikeli Oyunlar
        XCTAssertFalse(profile.bio.isEmpty)
    }

    /// `XCTAssertThrowsError` async ifadeleri desteklemediği için `do/catch` kullanıyoruz.
    func testUnknownAuthorThrowsAuthorNotFound() async throws {
        do {
            _ = try await service.fetchAuthorProfile(named: "Bilinmeyen Yazar")
            XCTFail("Hata fırlatılmalıydı")
        } catch let error as BookServiceError {
            XCTAssertEqual(error, .authorNotFound("Bilinmeyen Yazar"))
        }
    }

    func testSimulatedFailureThrowsNetworkUnavailable() async throws {
        let failingService = LocalBookService(latency: .zero, simulatesFailure: true)

        do {
            _ = try await failingService.fetchBooks()
            XCTFail("Hata fırlatılmalıydı")
        } catch let error as BookServiceError {
            XCTAssertEqual(error, .networkUnavailable)
        }

        do {
            _ = try await failingService.fetchReviews(for: 1)
            XCTFail("Hata fırlatılmalıydı")
        } catch let error as BookServiceError {
            XCTAssertEqual(error, .networkUnavailable)
        }
    }

    /// İptal edilen bir istek `CancellationError` fırlatmalı ve 10 sn'lik gecikmeyi BEKLEMEDEN hemen bitmeli.
    /// `Task.sleep`, iptali fark edip hemen fırlatır: işbirlikçi (cooperative) iptalin en basit örneği.
    func testCancellationThrowsCancellationErrorPromptly() async throws {
        let slowService = LocalBookService(latency: .seconds(10))
        let clock = ContinuousClock()
        let start = clock.now

        let task = Task { try await slowService.fetchBooks() }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("CancellationError fırlatılmalıydı")
        } catch is CancellationError {
            // Beklenen yol.
        }
        // Cömert sınır: iptal olmasaydı 10 sn sürerdi.
        XCTAssertLessThan(start.duration(to: clock.now), .seconds(5))
    }
}
