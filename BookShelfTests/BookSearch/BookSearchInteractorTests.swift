import XCTest
@testable import BookShelf

/// **Interactor testleri:** spy use case'ler + spy output. Kurallar (en az 2 harf, Türkçe katlama) burada tekrar
/// sınanmaz; onlar `BookSearchUseCaseTests`'te. Burada sınanan **koordinasyon**: debounce, "son arama kazanır" iptali,
/// hata ayrımı, geçmişe yalnızca taahhüt edilmiş (Ara / seçim) ve sonuç vermiş aramayı yazmak.
///
/// Interactor sonucu dönüş değeriyle değil, `output`'a **sonra** bildirir. Bekleme yolları (hepsi zaman sınırlı):
/// - `perform(_:expecting:)`: spy her olayda bir `XCTestExpectation`'ı `fulfill()` eder; test `await fulfillment(of:)`.
/// - `Doubles.waitUntil`: "spy çağrıyı aldı mı?" gibi ara durumlar için kısa aralıklı yoklama (polling).
/// - `waitForCompletion(of:)`: bir task'ın bitmesini expectation ile bekler (asılı kalmaz).
/// Hiçbir yerde "herhalde bitmiştir" diye sabit `sleep` yok.
///
/// Test metotları `@MainActor`: interactor ve spy output ana actor'de. Interactor'ın açtığı `Task`'lar da ana actor'ü
/// miras alır; test bir `await` ile ana actor'ü bırakmadıkça çalışamazlar. Bu, sırayı deterministik yapar.
final class BookSearchInteractorTests: XCTestCase {
    private typealias Doubles = BookSearchArchitectureDoubles
    private typealias Response = Doubles.SearchBooksUseCaseSpy.Response

    private struct SUT {
        let interactor: BookSearchInteractor
        let output: Doubles.InteractorOutputSpy
        let search: Doubles.SearchBooksUseCaseSpy
        let favorites: Doubles.ToggleFavoriteUseCaseSpy
        let recentSearches: Doubles.RecentSearchesUseCaseSpy
    }

    @MainActor
    private func makeSUT(
        search: Doubles.SearchBooksUseCaseSpy = Doubles.SearchBooksUseCaseSpy(),
        insights: Doubles.LoadBookInsightsUseCaseStub = .init(result: .failure(.networkUnavailable)),
        recentSearches: Doubles.RecentSearchesUseCaseSpy = Doubles.RecentSearchesUseCaseSpy(),
        debounce: Duration = .zero
    ) -> SUT {
        let favorites = Doubles.ToggleFavoriteUseCaseSpy()
        let useCases = BookSearchUseCases(
            search: search,
            insights: insights,
            toggleFavorite: favorites,
            recentSearches: recentSearches
        )
        let interactor = BookSearchInteractor(useCases: useCases, configuration: BookSearchConfiguration(debounce: debounce))
        let output = Doubles.InteractorOutputSpy()
        interactor.output = output
        return SUT(interactor: interactor, output: output, search: search, favorites: favorites, recentSearches: recentSearches)
    }

    /// `action`'ı çalıştırır ve çıkışa `count` YENİ olay gelene kadar bekler (en fazla `timeout`). `action` async
    /// olabilir: debounce testi harfler arasında bekler.
    ///
    /// `count` TAM sayı olmalı: Eksik verilirse kalan olaylar test ilerlerken gelir (sonuç zamanlamaya bağlı olur).
    /// Fazla olaylar ise `fulfill()` ile değil, testin sonundaki `XCTAssertEqual(events, [...])` ile yakalanır; bu yüzden
    /// `assertForOverFulfill = false`. Varsayılan (`true`) ayarda fazladan bir `fulfill()` XCTest'te bir API ihlalidir ve
    /// Objective-C istisnası (exception) fırlatır. Çağrı interactor'ın `Task`'ından geldiği için istisnayı yakalayan
    /// olmaz: test süreci çöker ve hatayı açıklayan olay listesi farkı yerine yalnızca "Crash" görülür.
    @MainActor
    private func perform(
        _ action: @MainActor () async -> Void,
        expecting count: Int,
        on output: Doubles.InteractorOutputSpy,
        timeout: TimeInterval = 2
    ) async {
        let delivered = expectation(description: "\(count) çıkış olayı")
        delivered.expectedFulfillmentCount = count
        delivered.assertForOverFulfill = false
        output.onEvent = { delivered.fulfill() }
        await action()
        await fulfillment(of: [delivered], timeout: timeout)
        output.onEvent = nil
    }

    /// Task'ın bitmesini zaman sınırıyla bekler. Doğrudan `await task.value` yazsaydık ve task hiç bitmeseydi test
    /// sonsuza dek asılı kalırdı.
    @MainActor
    private func waitForCompletion(of task: Task<Void, Never>?) async {
        guard let task else { return }
        let finished = expectation(description: "task bitmeli")
        Task {
            await task.value
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 2)
    }

    private static let atayBooks = [Doubles.book(6), Doubles.book(1)]

    // MARK: - Mutlu yol

    @MainActor
    func testSearchReportsStartThenResultsThenUpdatedRecentSearches() async {
        let sut = makeSUT(search: .init(responses: ["atay": Response(result: .success(Self.atayBooks))]))

        await perform({ sut.interactor.search(query: "  atay ", trigger: .submitted) }, expecting: 3, on: sut.output)

        // Sorgu kırpılmış olarak iletilir (kuralı uygulayan use case'in `validatedQuery`'si).
        XCTAssertEqual(sut.output.events, [
            .started("atay"),
            .found([6, 1], query: "atay"),
            .recentLoaded(["atay"]),
        ])
        let recorded = await sut.recentSearches.recordedQueries
        XCTAssertEqual(recorded, ["atay"])
    }

    @MainActor
    func testLoadRecentSearchesDeliversStoredQueries() async {
        let sut = makeSUT(recentSearches: .init(stored: ["huzur", "atay"]))

        await perform({ sut.interactor.loadRecentSearches() }, expecting: 1, on: sut.output)

        XCTAssertEqual(sut.output.events, [.recentLoaded(["huzur", "atay"])])
    }

    // MARK: - Kural ihlali: anında, ağsız

    /// Tek harf: debounce beklenmez, servis çağrılmaz; ret haberi `search` çağrısı dönmeden, senkron gelir.
    @MainActor
    func testTooShortQueryIsRejectedImmediatelyWithoutCallingTheUseCase() async {
        let sut = makeSUT(debounce: .seconds(10))

        sut.interactor.search(query: " a ", trigger: .typing)

        XCTAssertEqual(sut.output.events, [.rejected(.tooShort(minimumLength: 2))], "await olmadan, hemen")
        XCTAssertNil(sut.interactor.searchTask, "Kural ihlalinde task açılmamalı")
        let executed = await sut.search.executedQueries
        XCTAssertEqual(executed, [])
    }

    // MARK: - Debounce ve "başlamadan önce iptal"

    /// Gerçek debounce: Harfler arasında 50 ms var. Her yeni harf geldiğinde önceki task çoktan başlamış ve debounce
    /// uykusundadır (`Task.sleep`); iptal o uykuyu keser, servis hiç çağrılmaz. Yalnızca son sorgu süreyi doldurur.
    ///
    /// Neden harfler arasında `await`? Üç `search` çağrısı aynı ana actor turunda art arda yapılsaydı ilk ikisinin
    /// task'ı hiç BAŞLAMADAN iptal edilirdi; test debounce'u değil "başlamadan önce iptal"i ölçerdi (sonraki test) ve
    /// debounce tamamen kaldırılsa bile yeşil kalırdı. Debounce sıfırlanırsa bu test kırılır: "at" ve "ata" da servise gider.
    /// 1 sn'lik pencere cömert: 50 ms'lik beklemeler yavaş bir CI makinesinde uzasa bile pencereyi aşmaz.
    @MainActor
    func testDebounceSkipsQueriesTypedWithinTheWindow() async {
        let sut = makeSUT(
            search: .init(responses: ["atay": Response(result: .success(Self.atayBooks))]),
            debounce: .seconds(1)
        )

        await perform({
            for query in ["at", "ata", "atay"] {
                sut.interactor.search(query: query, trigger: .typing)
                try? await Task.sleep(for: .milliseconds(50))   // ana actor serbest: task başlar ve debounce'ta uyur
            }
        }, expecting: 2, on: sut.output, timeout: 3)
        await waitForCompletion(of: sut.interactor.searchTask)

        let executed = await sut.search.executedQueries
        XCTAssertEqual(executed, ["atay"], "Debounce süresinde yeni harf gelen sorgular servise gitmemeli")
        XCTAssertEqual(sut.output.events, [.started("atay"), .found([6, 1], query: "atay")])
    }

    /// Aynı ana actor turunda art arda üç arama: İlk ikisinin task'ı daha başlamadan iptal edilir. Bu debounce DEĞİL;
    /// task'ın başındaki `try Task.checkCancellation()` kontrolü. Debounce sıfır olsa da (UI testlerindeki ayar) eski
    /// aramalar ne "yükleniyor" gösterir ne de servise gider. Yazarken yapılan arama geçmişe YAZILMAZ.
    @MainActor
    func testSearchesCancelledBeforeTheirTaskStartsNeverRunAndTypingIsNotRecorded() async {
        let sut = makeSUT(
            search: .init(responses: ["atay": Response(result: .success(Self.atayBooks))]),
            debounce: .zero
        )

        await perform({
            for query in ["at", "ata", "atay"] {
                sut.interactor.search(query: query, trigger: .typing)
            }
        }, expecting: 2, on: sut.output)
        await waitForCompletion(of: sut.interactor.searchTask)

        let executed = await sut.search.executedQueries
        XCTAssertEqual(executed, ["atay"], "Yalnızca son sorgu servise gitmeli")
        XCTAssertEqual(sut.output.events, [.started("atay"), .found([6, 1], query: "atay")])
        let recorded = await sut.recentSearches.recordedQueries
        XCTAssertEqual(recorded, [], "Yazarken yapılan arama geçmişe yazılmamalı")
    }

    /// Açık istek (Ara düğmesi, Tekrar dene, geçmişten seçim) beklemez. Debounce 10 sn olsa da sonuç 2 sn içinde gelir.
    @MainActor
    func testExplicitSearchSkipsDebounce() async {
        let sut = makeSUT(
            search: .init(responses: ["atay": Response(result: .success(Self.atayBooks))]),
            debounce: .seconds(10)
        )

        await perform({ sut.interactor.search(query: "atay", trigger: .submitted) }, expecting: 3, on: sut.output, timeout: 2)

        XCTAssertEqual(sut.output.events, [.started("atay"), .found([6, 1], query: "atay"), .recentLoaded(["atay"])])
    }

    // MARK: - İptal: son arama kazanır

    /// Yavaş ilk arama uçuştayken ikinci gelir: ilki İPTAL edilir, çıkışa yalnızca ikincinin sonucu ulaşır,
    /// `CancellationError` hata olarak raporlanmaz ve geçmişe yalnızca ikincisi yazılır.
    @MainActor
    func testNewQueryCancelsSlowPreviousSearch() async {
        let sut = makeSUT(search: .init(responses: [
            "yavaş": Response(result: .success([Doubles.book(8)]), delay: .seconds(10)),
            "hızlı": Response(result: .success(Self.atayBooks)),
        ]))

        sut.interactor.search(query: "yavaş", trigger: .submitted)
        await Doubles.waitUntil("ilk arama use case'e ulaşmalı") { await sut.search.executedQueries == ["yavaş"] }

        await perform({ sut.interactor.search(query: "hızlı", trigger: .submitted) }, expecting: 3, on: sut.output)
        await Doubles.waitUntil("ilk arama iptal edilmeli") { await sut.search.cancelledQueries == ["yavaş"] }

        XCTAssertEqual(sut.output.events, [
            .started("yavaş"),
            .started("hızlı"),
            .found([6, 1], query: "hızlı"),
            .recentLoaded(["hızlı"]),
        ], "İptal edilen aramanın ne sonucu ne de hatası raporlanmalı")
        let recorded = await sut.recentSearches.recordedQueries
        XCTAssertEqual(recorded, ["hızlı"])
    }

    /// İptale tepki vermeyen ("inatçı") bir servis: Eski arama iptalden SONRA sonuç döndürür. Interactor `await`'ten
    /// sonra `Task.checkCancellation()` ile bunu fark edip bildirmemeli. Bu kontrol olmasaydı eski sonuç yeniyi ezerdi.
    @MainActor
    func testStaleResultIsDroppedEvenIfServiceIgnoresCancellation() async {
        let sut = makeSUT(search: .init(responses: [
            "eski": Response(result: .success([Doubles.book(8)]), waitsForRelease: true),
            "yeni": Response(result: .success(Self.atayBooks)),
        ]))

        sut.interactor.search(query: "eski", trigger: .submitted)
        let staleTask = sut.interactor.searchTask
        await Doubles.waitUntil("eski arama servis cevabını beklemeli") { await sut.search.isWaitingForRelease("eski") }

        await perform({ sut.interactor.search(query: "yeni", trigger: .submitted) }, expecting: 3, on: sut.output)
        await sut.search.release("eski")   // eski cevap ŞİMDİ, iptalden sonra geliyor
        await waitForCompletion(of: staleTask)

        XCTAssertEqual(sut.output.events, [
            .started("eski"),
            .started("yeni"),
            .found([6, 1], query: "yeni"),
            .recentLoaded(["yeni"]),
        ], "Eski aramanın geç gelen sonucu bildirilmemeli")
    }

    /// Aynı kural HATA için: Eski arama iptalden sonra hatayla biterse o hata da bildirilmez. Bildirilseydi ekrandaki
    /// "yeni" sonuçlarının yerine "Bağlantı kurulamadı" yazılırdı (eski bir aramanın hatası yeni aramanın ekranını ezerdi).
    @MainActor
    func testStaleErrorIsDroppedEvenIfServiceIgnoresCancellation() async {
        let sut = makeSUT(search: .init(responses: [
            "eski": Response(result: .failure(.networkUnavailable), waitsForRelease: true),
            "yeni": Response(result: .success(Self.atayBooks)),
        ]))

        sut.interactor.search(query: "eski", trigger: .submitted)
        let staleTask = sut.interactor.searchTask
        await Doubles.waitUntil("eski arama servis cevabını beklemeli") { await sut.search.isWaitingForRelease("eski") }

        await perform({ sut.interactor.search(query: "yeni", trigger: .submitted) }, expecting: 3, on: sut.output)
        await sut.search.release("eski")   // eski arama ŞİMDİ, iptalden sonra hatayla bitiyor
        await waitForCompletion(of: staleTask)

        XCTAssertEqual(sut.output.events, [
            .started("eski"),
            .started("yeni"),
            .found([6, 1], query: "yeni"),
            .recentLoaded(["yeni"]),
        ], "Eski aramanın geç gelen hatası bildirilmemeli")
    }

    /// Gerçek ağda iptal `CancellationError` olarak gelmez: `URLSession` iptal edilen isteği `URLError(.cancelled)` ile
    /// bitirir. Interactor hatanın türüne değil task'ın durumuna bakmalı; yoksa her yeni harfte bir an
    /// "Arama yapılamadı" görünürdü.
    @MainActor
    func testCancelledSearchFailingWithURLErrorCancelledIsNotReported() async {
        let sut = makeSUT(search: .init(responses: [
            "ata": Response(result: .success([]), delay: .seconds(10), errorOnCancel: URLError(.cancelled)),
            "atay": Response(result: .success(Self.atayBooks)),
        ]))

        sut.interactor.search(query: "ata", trigger: .submitted)
        let cancelledTask = sut.interactor.searchTask
        await Doubles.waitUntil("ilk arama use case'e ulaşmalı") { await sut.search.executedQueries == ["ata"] }

        await perform({ sut.interactor.search(query: "atay", trigger: .submitted) }, expecting: 3, on: sut.output)
        await waitForCompletion(of: cancelledTask)

        let cancelled = await sut.search.cancelledQueries
        XCTAssertEqual(cancelled, ["ata"], "İlk arama URLError(.cancelled) ile bitmeli")
        XCTAssertEqual(sut.output.events, [
            .started("ata"),
            .started("atay"),
            .found([6, 1], query: "atay"),
            .recentLoaded(["atay"]),
        ], "İptal, URLError(.cancelled) olarak gelse de hata diye raporlanmamalı")
    }

    /// Kutu temizlendi: uçuştaki arama iptal edilir, hiçbir şey raporlanmaz.
    @MainActor
    func testCancelSearchStopsInFlightSearchSilently() async {
        let sut = makeSUT(search: .init(responses: [
            "yavaş": Response(result: .success([Doubles.book(8)]), delay: .seconds(10)),
        ]))

        sut.interactor.search(query: "yavaş", trigger: .submitted)
        await Doubles.waitUntil("arama başlamalı") { await sut.search.executedQueries == ["yavaş"] }
        sut.interactor.cancelSearch()
        await Doubles.waitUntil("arama iptal edilmeli") { await sut.search.cancelledQueries == ["yavaş"] }

        XCTAssertEqual(sut.output.events, [.started("yavaş")])
        XCTAssertNil(sut.interactor.searchTask)
    }

    /// Modül kapandı (interactor serbest kaldı): `deinit` uçuştaki aramayı iptal eder. Task `self`'i yalnızca weak
    /// tuttuğu için interactor'ı hayatta tutmaz.
    @MainActor
    func testReleasingInteractorCancelsInFlightSearch() async {
        let search = Doubles.SearchBooksUseCaseSpy(responses: [
            "yavaş": Response(result: .success([Doubles.book(8)]), delay: .seconds(10)),
        ])
        var sut: SUT? = makeSUT(search: search)
        weak let weakInteractor = sut?.interactor

        sut?.interactor.search(query: "yavaş", trigger: .submitted)
        await Doubles.waitUntil("arama başlamalı") { await search.executedQueries == ["yavaş"] }
        sut = nil

        XCTAssertNil(weakInteractor, "Uçuştaki task interactor'ı hayatta tutmamalı ([weak self])")
        await Doubles.waitUntil("deinit aramayı iptal etmeli") { await search.cancelledQueries == ["yavaş"] }
    }

    // MARK: - Hatalar ve geçmiş

    @MainActor
    func testServiceErrorIsReportedAndQueryIsNotRecorded() async {
        let sut = makeSUT(search: .init(responses: ["atay": Response(result: .failure(.networkUnavailable))]))

        await perform({ sut.interactor.search(query: "atay", trigger: .submitted) }, expecting: 2, on: sut.output)
        await waitForCompletion(of: sut.interactor.searchTask)

        XCTAssertEqual(sut.output.events, [
            .started("atay"),
            .failed(BookServiceError.networkUnavailable.localizedDescription, query: "atay"),
        ])
        let recorded = await sut.recentSearches.recordedQueries
        XCTAssertEqual(recorded, [], "Başarısız arama geçmişe yazılmamalı")
    }

    /// Sonuç vermeyen arama başarılıdır ama geçmişe yazılmaz (kullanıcıya boş sonucu tekrar önermek anlamsız).
    @MainActor
    func testSearchWithoutResultsIsNotRecorded() async {
        let sut = makeSUT(search: .init(responses: ["zzz": Response(result: .success([]))]))

        await perform({ sut.interactor.search(query: "zzz", trigger: .submitted) }, expecting: 2, on: sut.output)
        await waitForCompletion(of: sut.interactor.searchTask)

        XCTAssertEqual(sut.output.events, [.started("zzz"), .found([], query: "zzz")])
        let recorded = await sut.recentSearches.recordedQueries
        XCTAssertEqual(recorded, [])
    }

    /// Kullanıcı yazarak bulduğu bir sonucu açtı: arama işe yaradı, geçmişe yazılır ve güncel liste bildirilir.
    @MainActor
    func testRememberSearchRecordsQueryAndReportsUpdatedList() async {
        let sut = makeSUT(recentSearches: .init(stored: ["huzur"]))

        await perform({ sut.interactor.rememberSearch("atay") }, expecting: 1, on: sut.output)

        XCTAssertEqual(sut.output.events, [.recentLoaded(["atay", "huzur"])])
        let recorded = await sut.recentSearches.recordedQueries
        XCTAssertEqual(recorded, ["atay"])
    }

    // MARK: - Özet ve favori

    @MainActor
    func testLoadInsightsDeliversResultOrFailure() async {
        let book = Doubles.book(1)
        let insights = BookInsights(book: book, reviewCount: 3, averageRating: 4.0, authorBookCount: 2)

        let success = makeSUT(insights: .init(result: .success(insights)))
        await perform({ success.interactor.loadInsights(for: book) }, expecting: 1, on: success.output)
        XCTAssertEqual(success.output.events, [.insightsLoaded(insights)])

        let failure = makeSUT(insights: .init(result: .failure(.networkUnavailable)))
        await perform({ failure.interactor.loadInsights(for: book) }, expecting: 1, on: failure.output)
        XCTAssertEqual(failure.output.events, [
            .insightsFailed(BookServiceError.networkUnavailable.localizedDescription, bookID: 1),
        ])
    }

    /// İkinci "Özet" isteği birincisini iptal eder. Birincisi `URLSession` gibi `URLError(.cancelled)` ile bitse de
    /// "Özet yüklenemedi" bildirilmemeli; yoksa yeni özetin alert'iyle aynı anda bir hata alert'i açılmaya çalışırdı.
    @MainActor
    func testSupersededInsightsRequestIsNotReportedAsFailure() async {
        let insights = BookInsights(book: Doubles.book(1), reviewCount: 3, averageRating: 4.0, authorBookCount: 2)
        let sut = makeSUT(insights: .init(result: .success(insights), slowBookIDs: [6]))

        sut.interactor.loadInsights(for: Doubles.book(6))
        let supersededTask = sut.interactor.insightsTask
        await perform({ sut.interactor.loadInsights(for: Doubles.book(1)) }, expecting: 1, on: sut.output)
        await waitForCompletion(of: supersededTask)

        XCTAssertEqual(sut.output.events, [.insightsLoaded(insights)], "İptal edilen özetin hatası bildirilmemeli")
    }

    @MainActor
    func testToggleFavoriteReportsNewState() async {
        let sut = makeSUT()
        let book = Doubles.book(8)

        await perform({ sut.interactor.toggleFavorite(for: book) }, expecting: 1, on: sut.output)
        await perform({ sut.interactor.toggleFavorite(for: book) }, expecting: 1, on: sut.output)

        XCTAssertEqual(sut.output.events, [
            .favoriteToggled(8, isFavorite: true),
            .favoriteToggled(8, isFavorite: false),
        ])
        let toggled = await sut.favorites.toggledBookIDs
        XCTAssertEqual(toggled, [8, 8])
    }

    // MARK: - Bellek

    /// Interactor çıkışını `weak` tutar: presenter yoksa sonuç sessizce düşer ve interactor onu hayatta tutmaz.
    @MainActor
    func testInteractorHoldsOutputWeakly() {
        let sut = makeSUT()
        var output: Doubles.InteractorOutputSpy? = Doubles.InteractorOutputSpy()
        sut.interactor.output = output
        weak let weakOutput = output

        output = nil

        XCTAssertNil(weakOutput)
        XCTAssertNil(sut.interactor.output)
    }
}
