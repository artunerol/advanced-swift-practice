import XCTest
@testable import BookShelf

/// **Presenter testleri:** spy view + mock interactor + spy router. Presenter tamamen senkron olduğu için hiçbir testte
/// `await`, expectation ya da bekleme yok. VIPER'ın "UI'sız, senkron test edilen presenter" vaadi.
///
/// İki yön ayrı ayrı sınanır:
/// - View → Presenter → Interactor/Router: "Doğru çağrı, doğru argümanla yapıldı mı?" → `InteractorMock.verify()`.
/// - Interactor → Presenter → View: "Domain sonucu doğru duruma ve doğru Türkçe metne çevrildi mi?" → `ViewSpy`.
final class BookSearchPresenterTests: XCTestCase {
    private typealias Doubles = BookSearchArchitectureDoubles

    private struct SUT {
        let presenter: BookSearchPresenter
        let view: Doubles.ViewSpy
        let interactor: Doubles.InteractorMock
        let router: Doubles.RouterSpy
    }

    @MainActor
    private func makeSUT() -> SUT {
        let view = Doubles.ViewSpy()
        let interactor = Doubles.InteractorMock()
        let router = Doubles.RouterSpy()
        let presenter = BookSearchPresenter(interactor: interactor, router: router)
        presenter.view = view
        return SUT(presenter: presenter, view: view, interactor: interactor, router: router)
    }

    /// Presenter'a "atay için şu kitaplar bulundu" dedirtir (sonraki dokunuşlar bu listeden kitap bulur).
    @MainActor
    private func showAtayResults(in sut: SUT) {
        sut.presenter.didChangeSearchText("atay")
        sut.presenter.didFindBooks([Doubles.book(6), Doubles.book(1)], for: "atay")
    }

    // MARK: - View → Presenter → Interactor (mock)

    @MainActor
    func testViewDidLoadShowsIdleAndLoadsRecentSearches() {
        let sut = makeSUT()
        sut.interactor.expect(.loadRecentSearches)

        sut.presenter.viewDidLoad()

        sut.interactor.verify()
        XCTAssertEqual(sut.view.renderedStates, [.idle(recentSearches: [])])
    }

    /// Yazmak `.typing` (debounce, geçmişe yazılmaz), "Ara" `.submitted` (beklemeden, sonuç verirse geçmişe yazılır).
    @MainActor
    func testTypingSearchesAsTypingAndSubmittingAsSubmitted() {
        let sut = makeSUT()
        sut.interactor.expect(
            .search(query: "at", trigger: .typing),
            .search(query: "atay", trigger: .typing),
            .search(query: "atay", trigger: .submitted)
        )

        sut.presenter.didChangeSearchText("at")
        sut.presenter.didChangeSearchText("atay")
        sut.presenter.didSubmitSearch("atay")

        // Presenter doğrulama/kırpma yapmaz; metni olduğu gibi iletir. Kural domain'de.
        sut.interactor.verify()
    }

    /// Kutu temizlenince: uçuştaki arama iptal, ekranda son aramalar.
    @MainActor
    func testClearingTextCancelsSearchAndShowsRecentSearches() {
        let sut = makeSUT()
        sut.presenter.didLoadRecentSearches(["huzur", "atay"])
        sut.interactor.expect(.search(query: "a", trigger: .typing), .cancelSearch)

        sut.presenter.didChangeSearchText("a")
        sut.presenter.didChangeSearchText("")

        sut.interactor.verify()
        XCTAssertEqual(sut.view.renderedStates.last, .idle(recentSearches: ["huzur", "atay"]))
    }

    @MainActor
    func testSelectingRecentSearchAndRetrySearchImmediately() {
        let sut = makeSUT()
        sut.interactor.expect(
            .search(query: "huzur", trigger: .submitted),
            .search(query: "huzur", trigger: .submitted)
        )

        sut.presenter.didSelectRecentSearch("huzur")
        sut.presenter.didTapRetry() // tekrar dene: kutudaki metinle, beklemeden

        sut.interactor.verify()
    }

    @MainActor
    func testRetryWithEmptyTextDoesNothing() {
        let sut = makeSUT()
        // Hiç beklenti yok: herhangi bir çağrı `verify()`'ı kırar.
        sut.presenter.didTapRetry()
        sut.interactor.verify()
    }

    @MainActor
    func testInsightsAndFavoriteRequestsCarryTheBookFromResults() {
        let sut = makeSUT()
        showAtayResults(in: sut)
        sut.interactor.expect(
            .search(query: "atay", trigger: .typing),
            .loadInsights(bookID: 1),
            .toggleFavorite(bookID: 6)
        )

        sut.presenter.didRequestInsights(forBookID: 1)
        sut.presenter.didRequestFavoriteToggle(forBookID: 6)
        sut.presenter.didRequestInsights(forBookID: 99) // listede yok → yok sayılır

        sut.interactor.verify()
    }

    // MARK: - View → Presenter → Router (spy)

    /// Sonucu açmak: router detayı gösterir, interactor aramayı hatırlar (yazarak bulunan sonuç işe yaradı).
    @MainActor
    func testSelectingResultShowsBookAndRemembersTheSearch() {
        let sut = makeSUT()
        showAtayResults(in: sut)
        sut.interactor.expect(.search(query: "atay", trigger: .typing), .rememberSearch("atay"))

        sut.presenter.didSelectBook(id: 1)
        sut.presenter.didSelectBook(id: 99)

        XCTAssertEqual(sut.router.shownBooks, [Doubles.book(1)], "Bilinmeyen kimlik navigasyon yapmamalı")
        sut.interactor.verify()
    }

    /// Debounce penceresi: "atay"ın sonuçları ekrandayken bir harf daha yazıldı ("atayz"); yeni arama henüz sonuçlanmadı,
    /// satırlar hâlâ "atay"ın. Satır açılırsa geçmişe kutudaki metin değil, o satırı bulan sorgu yazılmalı. Kutudaki
    /// metni yazmak, belki hiç sonuç vermeyecek bir aramayı (ya da bir öneki) geçmişe sokardı.
    @MainActor
    func testOpeningAResultDuringDebounceRemembersTheQueryThatFoundIt() {
        let sut = makeSUT()
        showAtayResults(in: sut)
        sut.interactor.expect(
            .search(query: "atay", trigger: .typing),
            .search(query: "atayz", trigger: .typing),
            .rememberSearch("atay")
        )

        sut.presenter.didChangeSearchText("atayz")   // debounce sürüyor; ekranda hâlâ "atay"ın satırları
        sut.presenter.didSelectBook(id: 1)

        XCTAssertEqual(sut.router.shownBooks, [Doubles.book(1)])
        sut.interactor.verify()
    }

    /// Satırlar ekrandan kalkınca (kutu temizlendi, kural ihlali, hata) onları bulan sorgu da unutulur.
    @MainActor
    func testResultsQueryIsClearedTogetherWithResults() {
        let sut = makeSUT()
        showAtayResults(in: sut)
        XCTAssertEqual(sut.presenter.resultsQuery, "atay")

        sut.presenter.didFailSearch(BookServiceError.networkUnavailable, query: "atayz")

        XCTAssertEqual(sut.presenter.results, [])
        XCTAssertEqual(sut.presenter.resultsQuery, "")
    }

    // MARK: - Interactor → Presenter → View: durum ve metinler

    @MainActor
    func testSearchStartShowsLoadingAndResultsBecomeRows() {
        let sut = makeSUT()

        sut.presenter.didStartSearching(query: "atay")
        sut.presenter.didFindBooks([Doubles.book(6), Doubles.book(1)], for: "atay")

        XCTAssertEqual(sut.view.renderedStates, [
            .loading,
            .results(rows: [
                BookSearchRow(id: 6, title: "Tehlikeli Oyunlar", detail: "Oğuz Atay · 1973"),
                BookSearchRow(id: 1, title: "Tutunamayanlar", detail: "Oğuz Atay · 1972"),
            ]),
        ])
    }

    @MainActor
    func testNoResultsShowsEmptyMessageWithQuery() {
        let sut = makeSUT()

        sut.presenter.didFindBooks([], for: "zzz")

        XCTAssertEqual(sut.view.renderedStates.last, .empty(
            message: "“zzz” için sonuç bulunamadı. Kitap adının ya da yazarın bir kısmını dene."
        ))
    }

    @MainActor
    func testTooShortQueryShowsHintNotError() {
        let sut = makeSUT()

        sut.presenter.didRejectQuery(.tooShort(minimumLength: 2))

        XCTAssertEqual(sut.view.renderedStates.last, .empty(message: "Aramak için en az 2 harf yaz."))
    }

    /// "Tekrar dene" yalnızca tekrar denemenin işe yarayabileceği hatalarda.
    @MainActor
    func testServiceErrorsMapToMessageAndRetryDecision() {
        let sut = makeSUT()

        sut.presenter.didFailSearch(BookServiceError.networkUnavailable, query: "atay")
        XCTAssertEqual(sut.view.renderedStates.last, .error(message: "Bağlantı kurulamadı. Lütfen tekrar deneyin.", canRetry: true))

        sut.presenter.didFailSearch(BookServiceError.decodingFailed, query: "atay")
        XCTAssertEqual(sut.view.renderedStates.last, .error(message: "Kitap verisi okunamadı.", canRetry: false))

        sut.presenter.didFailSearch(URLError(.timedOut), query: "atay")
        XCTAssertEqual(sut.view.renderedStates.last, .error(message: "Arama yapılamadı. Lütfen tekrar deneyin.", canRetry: true))
    }

    /// Geç gelen "geçmiş yüklendi" haberi, kullanıcı yazmaya başladıysa ekrandaki sonuçları EZMEMELİ.
    @MainActor
    func testLateRecentSearchesDoNotOverrideResultsWhileTyping() {
        let sut = makeSUT()
        showAtayResults(in: sut)
        let resultsState = sut.view.renderedStates.last

        sut.presenter.didLoadRecentSearches(["atay"])

        XCTAssertEqual(sut.view.renderedStates.last, resultsState)
        XCTAssertEqual(sut.presenter.recentSearches, ["atay"], "Saklanır; kutu boşalınca gösterilir")
    }

    @MainActor
    func testFavoriteToggleShowsStatusMessage() {
        let sut = makeSUT()

        sut.presenter.didToggleFavorite(Doubles.book(8), isFavorite: true)
        sut.presenter.didToggleFavorite(Doubles.book(8), isFavorite: false)

        XCTAssertEqual(sut.view.statuses, ["“Huzur” favorilere eklendi.", "“Huzur” favorilerden çıkarıldı."])
    }

    // MARK: - Özet: biçimlendirme (saf fonksiyon) ve router'a iletim

    @MainActor
    func testLoadedInsightsAreFormattedAndShownByRouter() {
        let sut = makeSUT()
        let insights = BookInsights(book: Doubles.book(1), reviewCount: 3, averageRating: 4.7, authorBookCount: 2)

        sut.presenter.didLoadInsights(insights)

        XCTAssertEqual(sut.router.shownInsights, [BookInsightsSummary(
            title: "Tutunamayanlar",
            lines: [
                "3 yorum · ortalama 4,7 / 5", // Türkçe ondalık virgül, cihaz dilinden bağımsız
                "Oğuz Atay: kitaplıkta 2 kitabı var. Yazarın başka kitabı da var.",
            ]
        )])
    }

    @MainActor
    func testInsightsSummaryCoversMissingReviewsSingleBookAndMissingAuthor() {
        let book = Doubles.book(8)

        let singleBook = BookSearchPresenter.insightsSummary(
            for: BookInsights(book: book, reviewCount: 0, averageRating: nil, authorBookCount: 1)
        )
        XCTAssertEqual(singleBook.lines, ["Henüz yorum yok.", "Ahmet Hamdi Tanpınar: kitaplıktaki tek kitabı bu."])

        // Kısmi hata politikası: yazar profili gelmedi, özet yine gösterilir.
        let noAuthor = BookSearchPresenter.insightsSummary(
            for: BookInsights(book: book, reviewCount: 2, averageRating: 4.5, authorBookCount: nil)
        )
        XCTAssertEqual(noAuthor.lines, ["2 yorum · ortalama 4,5 / 5", "Ahmet Hamdi Tanpınar hakkındaki bilgi şu an alınamadı."])
        XCTAssertEqual(noAuthor.message, noAuthor.lines.joined(separator: "\n"))
    }

    @MainActor
    func testInsightsFailureShowsError() {
        let sut = makeSUT()

        sut.presenter.didFailInsights(BookServiceError.networkUnavailable, for: Doubles.book(1))

        XCTAssertEqual(sut.view.errors.map(\.title), ["Özet yüklenemedi"])
        XCTAssertEqual(sut.view.errors.map(\.message), ["“Tutunamayanlar”: Bağlantı kurulamadı. Lütfen tekrar deneyin."])
    }

    // MARK: - Bellek

    /// Presenter view'ı `weak` tutar: view yok olunca presenter onu hayatta tutmaz, çağrılar sessizce düşer.
    @MainActor
    func testPresenterHoldsViewWeakly() {
        let sut = makeSUT()
        var view: Doubles.ViewSpy? = Doubles.ViewSpy()
        sut.presenter.view = view
        weak let weakView = view

        view = nil

        XCTAssertNil(weakView)
        XCTAssertNil(sut.presenter.view)
        sut.presenter.didFindBooks([], for: "atay") // çökmemeli
    }
}
