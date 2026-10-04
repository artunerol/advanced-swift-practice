import Foundation
@testable import BookShelf

/// Testlerde gerçek servisin yerine kullanılan **sahte servis** (stub).
///
/// - Döneceği sonuçları (ya da hataları) testte önceden belirleriz → testler deterministik olur.
/// - Her metodun kaç kez çağrıldığını sayar → "yükleme iki kez yapılmadı" gibi davranışları doğrulayabiliriz.
///
/// Neden `actor`? `BookServiceProtocol` `Sendable` olmayı şart koşuyor ama biz sayaçları değiştirmek istiyoruz
/// (değiştirilebilir durum). Actor bu ikisini birlikte sağlar: durumu korur ve otomatik `Sendable`'dır.
/// Protokoldeki gereksinimler zaten `async` olduğu için actor'ün izole metotları onları doğrudan karşılayabilir.
actor StubBookService: BookServiceProtocol {
    private var booksResult: Result<[Book], BookServiceError>
    private var reviewsResult: Result<[Review], BookServiceError>
    private var authorResult: Result<AuthorProfile, BookServiceError>
    private let delay: Duration

    private(set) var fetchBooksCallCount = 0
    private(set) var fetchReviewsCallCount = 0
    private(set) var fetchAuthorProfileCallCount = 0

    init(
        books: Result<[Book], BookServiceError> = .success(Book.fixtures),
        reviews: Result<[Review], BookServiceError> = .success([Review.fixture()]),
        author: Result<AuthorProfile, BookServiceError> = .success(AuthorProfile.fixture()),
        delay: Duration = .zero
    ) {
        booksResult = books
        reviewsResult = reviews
        authorResult = author
        self.delay = delay
    }

    func fetchBooks() async throws -> [Book] {
        fetchBooksCallCount += 1
        try await waitIfNeeded()
        return try booksResult.get()
    }

    func fetchReviews(for bookID: Book.ID) async throws -> [Review] {
        fetchReviewsCallCount += 1
        try await waitIfNeeded()
        return try reviewsResult.get()
    }

    func fetchAuthorProfile(named authorName: String) async throws -> AuthorProfile {
        fetchAuthorProfileCallCount += 1
        try await waitIfNeeded()
        return try authorResult.get()
    }

    // MARK: - Test sırasında davranışı değiştirmek için

    func setBooksResult(_ result: Result<[Book], BookServiceError>) {
        booksResult = result
    }

    func setReviewsResult(_ result: Result<[Review], BookServiceError>) {
        reviewsResult = result
    }

    func setAuthorResult(_ result: Result<AuthorProfile, BookServiceError>) {
        authorResult = result
    }

    /// Not: `Task.sleep` actor'ü BLOKLAMAZ. Bekleme sırasında actor başka çağrıları işleyebilir (reentrancy).
    /// Bu sayede aynı stub'a yapılan paralel çağrılar (ör. `async let`) gerçekten paralel bekler.
    private func waitIfNeeded() async throws {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
    }
}
