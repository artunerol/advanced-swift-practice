import XCTest
@testable import BookShelf

/// `BookDetailViewModel` testleri: paralel yükleme (`async let`), actor ile favori ve Objective-C köprüsü.
final class BookDetailViewModelTests: XCTestCase {
    @MainActor
    func testLoadFetchesReviewsAndAuthorProfile() async {
        let book = Book.fixture(id: 7, author: "Yazar A")
        let reviews = [Review.fixture(id: 700, bookID: 7), Review.fixture(id: 701, bookID: 7, rating: 5)]
        let author = AuthorProfile.fixture(name: "Yazar A", bookCount: 3)
        let service = StubBookService(reviews: .success(reviews), author: .success(author))
        let viewModel = BookDetailViewModel(book: book, service: service, favorites: FavoritesStore())

        await viewModel.load()

        guard case .loaded(let extras) = viewModel.extras else {
            return XCTFail("Ek bilgiler yüklenmeliydi, durum: \(viewModel.extras)")
        }
        XCTAssertEqual(extras.reviews, reviews)
        XCTAssertEqual(extras.author, author)
        let reviewCalls = await service.fetchReviewsCallCount
        let authorCalls = await service.fetchAuthorProfileCallCount
        XCTAssertEqual(reviewCalls, 1)
        XCTAssertEqual(authorCalls, 1)
    }

    /// Her istek 300 ms sürüyor. Paralel yüklenirse toplam ≈ 300 ms, sırayla yüklenseydi ≈ 600 ms.
    /// Duvar saatine sıkı bağlı kalmamak için hem cömert bir üst sınır hem de göreli bir karşılaştırma kullanıyoruz.
    @MainActor
    func testReviewsAndAuthorLoadConcurrently() async {
        let service = StubBookService(delay: .milliseconds(300))
        let viewModel = BookDetailViewModel(book: .fixture(), service: service, favorites: FavoritesStore())

        let clock = ContinuousClock()
        let start = clock.now
        await viewModel.load()
        let elapsed = start.duration(to: clock.now)

        XCTAssertLessThan(elapsed, .milliseconds(550), "İki 300 ms'lik istek paralel çalışmalıydı")

        guard case .loaded(let extras) = viewModel.extras else {
            return XCTFail("Ek bilgiler yüklenmeliydi, durum: \(viewModel.extras)")
        }
        // Göreli kontrol: toplam süre, iki isteğin sürelerinin TOPLAMINDAN kısa olmalı (yani üst üste bindiler).
        XCTAssertLessThan(extras.timing.total, extras.timing.sequentialEstimate)
    }

    @MainActor
    func testInitialFavoriteStateIsReadFromStore() async {
        let book = Book.fixture(id: 3)
        let store = FavoritesStore(initialFavorites: [3])
        let viewModel = BookDetailViewModel(book: book, service: StubBookService(), favorites: store)
        XCTAssertFalse(viewModel.isFavorite, "load() çağrılmadan önce varsayılan değer")

        await viewModel.load()

        XCTAssertTrue(viewModel.isFavorite)
    }

    /// Favori düğmesi: view model → actor → view model. Actor'deki gerçek durum da değişmeli.
    @MainActor
    func testToggleFavoriteRoundTripsThroughStore() async {
        let book = Book.fixture(id: 5)
        let store = FavoritesStore()
        let viewModel = BookDetailViewModel(book: book, service: StubBookService(), favorites: store)
        await viewModel.load()
        XCTAssertFalse(viewModel.isFavorite)

        await viewModel.toggleFavorite()
        XCTAssertTrue(viewModel.isFavorite)
        let isStoredAfterFirstToggle = await store.contains(5)
        XCTAssertTrue(isStoredAfterFirstToggle)

        await viewModel.toggleFavorite()
        XCTAssertFalse(viewModel.isFavorite)
        let isStoredAfterSecondToggle = await store.contains(5)
        XCTAssertFalse(isStoredAfterSecondToggle)
    }

    /// Tasarım kararı: ya ikisi ya hiçbiri. Yazar bulunamazsa ek bilgiler hata durumuna geçer;
    /// "Tekrar Dene" (yeniden `load()`) sorun düzelince başarılı olur.
    @MainActor
    func testAuthorFailureShowsErrorAndRetrySucceeds() async {
        let service = StubBookService(author: .failure(.authorNotFound("Test Yazar")))
        let viewModel = BookDetailViewModel(book: .fixture(), service: service, favorites: FavoritesStore())

        await viewModel.load()

        let expectedMessage = BookServiceError.authorNotFound("Test Yazar").localizedDescription
        XCTAssertEqual(viewModel.extras, .failed(message: expectedMessage))

        await service.setAuthorResult(.success(.fixture()))
        await viewModel.load()

        guard case .loaded = viewModel.extras else {
            return XCTFail("Tekrar denemede yüklenmeliydi, durum: \(viewModel.extras)")
        }
    }

    @MainActor
    func testReviewsFailureShowsError() async {
        let service = StubBookService(reviews: .failure(.networkUnavailable))
        let viewModel = BookDetailViewModel(book: .fixture(), service: service, favorites: FavoritesStore())

        await viewModel.load()

        XCTAssertEqual(viewModel.extras, .failed(message: BookServiceError.networkUnavailable.localizedDescription))
    }

    /// Ekrandan geri dönülünce `.task` iptal edilir; bu bir hata gibi gösterilmemeli.
    @MainActor
    func testCancelledLoadIsNotTreatedAsError() async {
        let service = StubBookService(delay: .seconds(10))
        let viewModel = BookDetailViewModel(book: .fixture(), service: service, favorites: FavoritesStore())

        let loadTask = Task { await viewModel.load() }
        await bookDetailWaitUntil { viewModel.extras == .loading }
        loadTask.cancel()
        await loadTask.value

        XCTAssertEqual(viewModel.extras, .idle)
    }

    /// Objective-C sonuçlarını sabit metinle değil, aynı Objective-C çağrısının kendi sonucuyla karşılaştırıyoruz.
    /// Böylece test, view model'in ObjC API'sini DOĞRU girdilerle çağırdığını doğrular; ObjC algoritmasının
    /// kendisi kendi testlerinde sınanır.
    @MainActor
    func testISBNStatusAndReadingTimeComeFromObjectiveC() {
        let valid = Book.fixture(isbn: "978-605-000-001-6", pageCount: 724)
        let invalid = Book.fixture(id: 8, isbn: "978-605-000-008-6", pageCount: 392)

        for book in [valid, invalid] {
            let viewModel = BookDetailViewModel(book: book, service: StubBookService(), favorites: FavoritesStore())
            XCTAssertEqual(viewModel.isISBNValid, ISBNValidator.isValidISBN13(book.isbn))
            XCTAssertEqual(
                viewModel.readingTimeText,
                ReadingTimeEstimator(pagesPerHour: 40).formattedEstimate(forPageCount: book.pageCount)
            )
        }
    }

    /// Süre metinleri Türkçe ondalık ayırıcıyla (virgül) ve tek haneyle yazılmalı; cihaz dili ne olursa olsun.
    func testLoadTimingTextsUseTurkishFormatting() {
        let timing = BookDetailViewModel.LoadTiming(
            reviews: .milliseconds(610),
            author: .milliseconds(1_220),
            total: .milliseconds(1_230)
        )

        XCTAssertEqual(BookDetailViewModel.LoadTiming.secondsText(.milliseconds(1_234)), "1,2")
        XCTAssertEqual(timing.sequentialEstimate, .milliseconds(1_830))
        XCTAssertEqual(timing.totalText, "Yükleme süresi: 1,2 sn (paralel)")
        XCTAssertEqual(timing.breakdownText, "Yorumlar 0,6 sn · Yazar 1,2 sn · Sırayla olsaydı ≈ 1,8 sn")
    }
}

/// Koşul sağlanana kadar ana actor'ü kısa kısa serbest bırakır. Açıklama için `BookListViewModelTests`'teki
/// eşine bak; dosyaya özel (`private`) olduğu için iki kopya birbiriyle çakışmaz.
@MainActor
private func bookDetailWaitUntil(
    _ condition: () -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    for _ in 0..<10_000 {
        if condition() { return }
        await Task.yield()
    }
    XCTFail("Koşul zamanında sağlanmadı", file: file, line: line)
}
