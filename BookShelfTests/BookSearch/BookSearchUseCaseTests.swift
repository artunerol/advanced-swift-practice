import XCTest
@testable import BookShelf

/// **Domain katmanı testleri:** Kitap aramanın dört use case'i. UI yok, VIPER yok, `@MainActor` yok.
///
/// Servis yerine `StubBookService` (stub + spy: hazır cevap, çağrı sayacı, isteğe bağlı gecikme) ya da sahte depo
/// (`InMemoryRecentSearchesStore`, fake) kullanılır. Kuralların asıl kanıtı burası; interactor testleri bu kuralları
/// tekrar etmez, spy use case'lerle yalnızca koordinasyonu sınar.
final class BookSearchUseCaseTests: XCTestCase {
    private typealias Doubles = BookSearchArchitectureDoubles

    private func makeSearch(books: [Book] = Doubles.catalog) -> (SearchBooksUseCase, StubBookService) {
        let service = StubBookService(books: .success(books))
        return (SearchBooksUseCase(service: service), service)
    }

    private func ids(_ books: [Book]) -> [Book.ID] {
        books.map(\.id)
    }

    // MARK: - SearchBooksUseCase: Kural 1, geçerli sorgu

    func testTooShortQueryThrowsTypedErrorWithoutCallingService() async {
        let (search, service) = makeSearch()

        for query in ["", "a", "  a  ", " \n "] {
            do {
                _ = try await search.execute(query: query)
                XCTFail("'\(query)' reddedilmeliydi")
            } catch let error as SearchQueryError {
                XCTAssertEqual(error, .tooShort(minimumLength: 2))
            } catch {
                XCTFail("Beklenmeyen hata: \(error)")
            }
        }

        let calls = await service.fetchBooksCallCount
        XCTAssertEqual(calls, 0, "Kural ihlalinde servise hiç gidilmemeli")
    }

    func testValidQueryIsTrimmed() throws {
        let (search, _) = makeSearch()
        XCTAssertEqual(try search.validatedQuery("  at \n"), "at")
        // `count` kullanıcının gördüğü harfleri sayar: iki Türkçe harf iki karakterdir.
        XCTAssertEqual(try search.validatedQuery("ğü"), "ğü")
    }

    // MARK: - SearchBooksUseCase: Kural 2, Türkçe büyük/küçük harf ve aksan

    func testAtayFindsBothOguzAtayBooksRegardlessOfCase() async throws {
        let (search, _) = makeSearch()

        for query in ["atay", "ATAY", "Atay", " aTaY "] {
            let books = try await search.execute(query: query)
            // Yalnızca yazarda eşleşir; Türkçe alfabetik: Tehlikeli < Tutunamayanlar.
            XCTAssertEqual(ids(books), [6, 1], "'\(query)'")
        }
    }

    /// KARAR: Aksan farkı yok sayılır. Türkçe klavyesi olmayan kullanıcı "oguz" yazar ve Oğuz Atay'ı bulmalı.
    func testDiacriticInsensitiveOguzFindsOguzAtay() async throws {
        let (search, _) = makeSearch()

        for query in ["oğuz", "OĞUZ", "oguz", "OGUZ"] {
            let books = try await search.execute(query: query)
            XCTAssertEqual(ids(books), [6, 1], "'\(query)'")
        }
        // Diğer Türkçe harfler de: ş → s, ü → u, ç → c.
        let yasar = try await search.execute(query: "yasar")
        XCTAssertEqual(ids(yasar), [4])
        let kurk = try await search.execute(query: "kurk")
        XCTAssertEqual(ids(kurk), [2])
        let kuyucakli = try await search.execute(query: "KUYUCAKLI")
        XCTAssertEqual(ids(kuyucakli), [7])
    }

    /// I, ı, İ, i dördü aynı harf sayılır: "İnce" hem "ince" hem "INCE" (İngilizce klavye) ile bulunur.
    func testDottedAndDotlessIAreEquivalent() async throws {
        let (search, _) = makeSearch()

        for query in ["ince", "İNCE", "INCE", "ınce", "İnce"] {
            let books = try await search.execute(query: query)
            XCTAssertEqual(ids(books), [4], "'\(query)'")
        }
        for query in ["kirmizi", "KIRMIZI", "kırmızı", "Kırmızı"] {
            let books = try await search.execute(query: query)
            XCTAssertEqual(ids(books), [5], "'\(query)'")
        }
        // "tanpinar" (ı'sız) yazarın iki kitabını bulur.
        let tanpinar = try await search.execute(query: "tanpinar")
        XCTAssertEqual(ids(tanpinar), [8, 3]) // Huzur < Saatleri...
    }

    /// Neden kendi anahtarımızı yazdık? Bu iki satır, "hazır" yolların Türkçe'de nerede kırıldığının kanıtı.
    func testNaiveLowercasingFailsForTurkishLetters() {
        // 1) Varsayılan `lowercased()` "İ"yi "i" + U+0307 (birleşen nokta) yapar; "ince" içinde bulunmaz.
        XCTAssertFalse("İnce Memed".lowercased().contains("ince"))
        // 2) Türkçe `lowercased` doğru ama "I"yı "ı" yapar; İngilizce klavyeyle yazılmış "INCE" eşleşmez.
        XCTAssertNotEqual("INCE".lowercased(with: Locale(identifier: "tr_TR")), "ince")
        // Bizim anahtarımız ikisini de çözer.
        XCTAssertEqual(SearchBooksUseCase.searchKey(for: "İNCE"), "ince")
        XCTAssertEqual(SearchBooksUseCase.searchKey(for: "INCE"), "ince")
    }

    func testSearchKeyFoldsAllTurkishSpecificLetters() {
        XCTAssertEqual(SearchBooksUseCase.searchKey(for: "ÇĞIİÖŞÜ çğıiöşü"), "cgiiosu cgiiosu")
    }

    // MARK: - SearchBooksUseCase: Kural 3, sıralama

    /// Önce başlık eşleşmeleri, sonra yalnızca yazarda eşleşenler; her grup Türkçe alfabetik.
    func testTitleMatchesComeFirstThenAuthorMatchesEachAlphabetical() async throws {
        let books: [Book] = [
            .fixture(id: 1, title: "Zeytin ve Deniz", author: "Kemal"),
            .fixture(id: 2, title: "Akşam", author: "Deniz Yılmaz"),
            .fixture(id: 3, title: "Çakıl ile Deniz", author: "Ayşe"),
            .fixture(id: 4, title: "Bulut", author: "Deniz Ak"),
            .fixture(id: 5, title: "Deniz Kızı", author: "Deniz Kaya"), // ikisinde de eşleşir → başlık grubunda
            .fixture(id: 6, title: "Orman", author: "Zeynep"),         // eşleşmez
        ]
        let (search, _) = makeSearch(books: books)

        let result = try await search.execute(query: "deniz")

        // Başlık: Çakıl (Ç, C'den sonra D'den önce) < Deniz Kızı < Zeytin; yazar: Akşam < Bulut.
        XCTAssertEqual(ids(result), [3, 5, 1, 2, 4])
    }

    /// Gerçek kataloktan bir örnek: "ma" üç başlıkta, bir yazarda (Yaşar Ke**ma**l) geçer.
    func testRealCatalogExampleRanksTitleMatchesBeforeAuthorMatch() async throws {
        let (search, _) = makeSearch()
        let result = try await search.execute(query: "ma")
        XCTAssertEqual(ids(result), [2, 3, 1, 4]) // Kürk..., Saatleri..., Tutunamayanlar, sonra İnce Memed
    }

    /// Düz `sorted()` Unicode sırasıyla Ç ve Ş ile başlayanları sona atar; Türkçe sıralama atmaz.
    func testAlphabeticalOrderIsTurkishNotUnicode() async throws {
        let books: [Book] = [
            .fixture(id: 1, title: "Şeker Portakalı", author: "Yazar"),
            .fixture(id: 2, title: "Sinekli Bakkal", author: "Yazar"),
            .fixture(id: 3, title: "Çalıkuşu", author: "Yazar"),
            .fixture(id: 4, title: "Cevdet Bey", author: "Yazar"),
            .fixture(id: 5, title: "Dede Korkut", author: "Yazar"),
        ]
        let (search, _) = makeSearch(books: books)

        let result = try await search.execute(query: "yazar")

        XCTAssertEqual(result.map(\.title), ["Cevdet Bey", "Çalıkuşu", "Dede Korkut", "Sinekli Bakkal", "Şeker Portakalı"])
        XCTAssertEqual(books.map(\.title).sorted().last, "Şeker Portakalı", "Unicode sırası Ş'yi en sona atar")
    }

    func testServiceErrorIsPropagated() async {
        let search = SearchBooksUseCase(service: StubBookService(books: .failure(.networkUnavailable)))
        do {
            _ = try await search.execute(query: "atay")
            XCTFail("Hata fırlatılmalıydı")
        } catch {
            XCTAssertEqual(error as? BookServiceError, .networkUnavailable)
        }
    }

    // MARK: - LoadBookInsightsUseCase: birleştirme

    func testInsightsAggregateReviewsAndAuthor() async throws {
        let reviews = [5, 4, 5].enumerated().map { Review.fixture(id: $0.offset, rating: $0.element) }
        let service = StubBookService(reviews: .success(reviews), author: .success(.fixture(bookCount: 2)))
        let book = Book.fixture(id: 1)

        let insights = try await LoadBookInsightsUseCase(service: service).execute(for: book)

        XCTAssertEqual(insights, BookInsights(book: book, reviewCount: 3, averageRating: 4.7, authorBookCount: 2))
        XCTAssertEqual(insights.authorHasOtherBooks, true)
    }

    func testAverageRatingIsRoundedToOneDecimalAndNilWithoutReviews() {
        func average(_ ratings: [Int]) -> Double? {
            LoadBookInsightsUseCase.averageRating(of: ratings.map { Review.fixture(rating: $0) })
        }
        XCTAssertEqual(average([5, 4, 5]), 4.7)    // 4,666…
        XCTAssertEqual(average([4, 4, 5]), 4.3)    // 4,333…
        XCTAssertEqual(average([5, 4, 4, 4]), 4.3) // 4,25: eşitlikte sıfırdan uzağa
        XCTAssertEqual(average([3]), 3.0)
        XCTAssertNil(average([]), "Yorum yoksa ortalama yok (0,0 yanıltıcı olurdu)")
    }

    /// İki 300 ms'lik istek `async let` ile üst üste binmeli. Üst sınır cömert (sıralı olsaydı ≥ 600 ms).
    func testReviewsAndAuthorAreFetchedConcurrently() async throws {
        let service = StubBookService(delay: .milliseconds(300))
        let useCase = LoadBookInsightsUseCase(service: service)

        let clock = ContinuousClock()
        let start = clock.now
        _ = try await useCase.execute(for: .fixture())
        let elapsed = start.duration(to: clock.now)

        XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(300), "Her istek en az 300 ms sürer")
        XCTAssertLessThan(elapsed, .milliseconds(550), "İki istek paralel çalışmalıydı (sıralı ≥ 600 ms)")
        let reviewCalls = await service.fetchReviewsCallCount
        let authorCalls = await service.fetchAuthorProfileCallCount
        XCTAssertEqual([reviewCalls, authorCalls], [1, 1])
    }

    /// Politika: Yazar profili isteğe bağlı. Gelmezse özet yine döner, yazar alanları `nil`.
    func testAuthorFailureStillReturnsInsightsWithoutAuthor() async throws {
        let service = StubBookService(author: .failure(.authorNotFound("Test Yazar")))

        let insights = try await LoadBookInsightsUseCase(service: service).execute(for: .fixture())

        XCTAssertEqual(insights.reviewCount, 1)
        XCTAssertNil(insights.authorBookCount)
        XCTAssertNil(insights.authorHasOtherBooks, "Bilinmiyor: ne evet ne hayır")
    }

    /// Politika: Yorumlar zorunlu. Gelmezse özetin tamamı hata.
    func testReviewsFailureFailsWholeInsights() async {
        let service = StubBookService(reviews: .failure(.networkUnavailable))
        do {
            _ = try await LoadBookInsightsUseCase(service: service).execute(for: .fixture())
            XCTFail("Hata fırlatılmalıydı")
        } catch {
            XCTAssertEqual(error as? BookServiceError, .networkUnavailable)
        }
    }

    func testSingleBookAuthorHasNoOtherBooks() async throws {
        let service = StubBookService(author: .success(.fixture(bookCount: 1)))
        let insights = try await LoadBookInsightsUseCase(service: service).execute(for: .fixture())
        XCTAssertEqual(insights.authorHasOtherBooks, false)
    }

    /// İptal "yazar bilgisi yok" sayılmamalı: Yorumlar geldikten sonra iptal edilen iş `CancellationError` ile biter.
    /// (`try?` ile yazılsaydı iptal yutulur ve yarım bir özet dönerdi.)
    @MainActor
    func testCancellationWhileWaitingForAuthorIsNotTreatedAsMissingAuthor() async {
        await assertCancellingWhileWaitingForAuthorThrowsCancellationError(service: SlowAuthorServiceStub())
    }

    /// Aynı kural, iptal `URLSession`'daki gibi `URLError(.cancelled)` olarak geldiğinde: `catch is CancellationError`
    /// bunu kaçırır ve iptal edilmiş işi "yazar bilgisi yok" diye sürdürürdü. Use case hatanın türüne değil
    /// `Task.isCancelled`'a bakar ve çağırana her durumda `CancellationError` iletir.
    @MainActor
    func testCancellationReportedAsURLErrorIsNotTreatedAsMissingAuthor() async {
        await assertCancellingWhileWaitingForAuthorThrowsCancellationError(
            service: SlowAuthorServiceStub(errorOnCancel: URLError(.cancelled))
        )
    }

    /// Yorumlar gelmiş, yazar isteği sürerken iş iptal ediliyor: sonuç yarım bir özet değil `CancellationError` olmalı.
    @MainActor
    private func assertCancellingWhileWaitingForAuthorThrowsCancellationError(
        service: SlowAuthorServiceStub,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let useCase = LoadBookInsightsUseCase(service: service)
        let task = Task { try await useCase.execute(for: .fixture()) }

        await Doubles.waitUntil("yazar isteği başlamalı", file: file, line: line) { await service.authorRequestStarted }
        task.cancel()
        let result = await task.result

        XCTAssertThrowsError(try result.get(), file: file, line: line) { error in
            XCTAssertTrue(error is CancellationError, "Beklenen CancellationError, gelen: \(error)", file: file, line: line)
        }
    }

    // MARK: - ToggleFavoriteUseCase: komut

    func testToggleFavoriteChangesSharedStoreAndReturnsNewState() async {
        let store = FavoritesStore(initialFavorites: [2])
        let useCase = ToggleFavoriteUseCase(store: store)

        let added = await useCase.execute(bookID: 5)
        let removed = await useCase.execute(bookID: 2)

        XCTAssertTrue(added)
        XCTAssertFalse(removed)
        let ids = await store.allIDs
        XCTAssertEqual(ids, [5], "Yan etki paylaşılan actor'de görünmeli")
    }

    // MARK: - RecentSearchesUseCase: yerel depolama politikası

    func testRecentSearchesAreNewestFirst() async {
        let useCase = RecentSearchesUseCase(store: InMemoryRecentSearchesStore())

        await useCase.record("atay")
        await useCase.record("huzur")
        let queries = await useCase.record("pamuk")

        XCTAssertEqual(queries, ["pamuk", "huzur", "atay"])
        let loaded = await useCase.load()
        XCTAssertEqual(loaded, queries)
    }

    /// Tekrar yok: Aynı arama (büyük/küçük harf ve aksan farkıyla) öne taşınır, son yazılan biçim kalır.
    func testDuplicatesAreRemovedCaseInsensitivelyAndMovedToFront() async {
        let useCase = RecentSearchesUseCase(store: InMemoryRecentSearchesStore())

        await useCase.record("atay")
        await useCase.record("huzur")
        let afterUppercase = await useCase.record("ATAY")
        XCTAssertEqual(afterUppercase, ["ATAY", "huzur"])

        // Aynı arama anahtarı: "oğuz" ile "oguz" aynı sonucu verir, aynı arama sayılır.
        await useCase.record("oğuz")
        let afterAscii = await useCase.record("oguz")
        XCTAssertEqual(afterAscii, ["oguz", "ATAY", "huzur"])
    }

    func testOnlyTheFiveNewestAreKept() async {
        let useCase = RecentSearchesUseCase(store: InMemoryRecentSearchesStore())

        for query in ["q1", "q2", "q3", "q4", "q5", "q6", "q7"] {
            await useCase.record(query)
        }

        let queries = await useCase.load()
        XCTAssertEqual(queries, ["q7", "q6", "q5", "q4", "q3"])
    }

    func testQueriesAreTrimmedAndBlankQueriesIgnored() {
        XCTAssertEqual(RecentSearchesUseCase.applying("  atay \n", to: ["huzur"]), ["atay", "huzur"])
        XCTAssertEqual(RecentSearchesUseCase.applying("   ", to: ["huzur"]), ["huzur"])
    }

    /// `update(_:)` atomik: Aynı anda gelen kayıtların hiçbiri kaybolmaz ("lost update" yok).
    /// `load` + `save` iki ayrı çağrı olsaydı, ikisi de eski listeyi okuyup birbirinin yazdığını ezebilirdi.
    func testConcurrentRecordsAreNotLost() async {
        let useCase = RecentSearchesUseCase(store: InMemoryRecentSearchesStore())
        let queries = ["q1", "q2", "q3", "q4", "q5"]

        await withTaskGroup(of: Void.self) { group in
            for query in queries {
                group.addTask { await useCase.record(query) }
            }
        }

        let stored = await useCase.load()
        XCTAssertEqual(Set(stored), Set(queries), "Sıra eşzamanlılığa bağlı, ama hiçbiri kaybolmamalı")
    }

    /// UserDefaults uygulaması: Testler kendi geçici suite'ini kullanır ve siler (gerçek kullanıcı verisine dokunmaz).
    func testUserDefaultsStorePersistsAcrossInstances() async {
        let suiteName = "BookShelfTests.recentSearches.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let first = RecentSearchesUseCase(store: UserDefaultsRecentSearchesStore(suiteName: suiteName))
        await first.record("atay")
        await first.record("huzur")

        // Yeni bir örnek ("uygulama yeniden açıldı") aynı suite'ten okur.
        let second = RecentSearchesUseCase(store: UserDefaultsRecentSearchesStore(suiteName: suiteName))
        let loaded = await second.load()
        XCTAssertEqual(loaded, ["huzur", "atay"])
    }
}

/// **Stub:** Yorumları anında, yazar profilini ise iptal edilene kadar "hiç" döndürmeyen servis. Kısmi hata politikasında
/// iptalin doğru ele alındığını sınamak için. Yazar isteğinin başladığını `authorRequestStarted` ile haber verir.
private actor SlowAuthorServiceStub: BookServiceProtocol {
    /// İptal edilen yazar isteğinin hangi hatayla biteceği. `nil`: `Task.sleep`'in kendi `CancellationError`'ı.
    /// `URLError(.cancelled)`: `URLSession` gibi davranır.
    private let errorOnCancel: (any Error)?
    private(set) var authorRequestStarted = false

    init(errorOnCancel: (any Error)? = nil) {
        self.errorOnCancel = errorOnCancel
    }

    func fetchBooks() async throws -> [Book] { [] }

    func fetchReviews(for bookID: Book.ID) async throws -> [Review] {
        [.fixture(bookID: bookID)]
    }

    func fetchAuthorProfile(named authorName: String) async throws -> AuthorProfile {
        authorRequestStarted = true
        do {
            try await Task.sleep(for: .seconds(30)) // iptal edilince hemen fırlatır
        } catch {
            throw errorOnCancel ?? error
        }
        return .fixture(name: authorName)
    }
}
