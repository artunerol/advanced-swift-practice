import XCTest
@testable import BookShelf

/// `BookListViewModel` testleri.
///
/// Sınıf `@MainActor` DEĞİL (o zaman `setUp` override'ları sorun çıkarır); bunun yerine view model'e dokunan
/// her test metodu tek tek `@MainActor` işaretli. `async` test metotları `await` kullanabilir; XCTest
/// metodun bitmesini bekler.
///
/// Servis olarak gerçek `LocalBookService` değil, `StubBookService` kullanıyoruz: sonuçları biz belirliyoruz
/// (deterministik) ve kaç kez çağrıldığını sayabiliyoruz.
final class BookListViewModelTests: XCTestCase {
    @MainActor
    func testLoadSuccessMovesToLoadedState() async {
        let service = StubBookService()
        let viewModel = BookListViewModel(service: service)
        XCTAssertEqual(viewModel.state, .idle)

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
        let calls = await service.fetchBooksCallCount // actor özelliği: okumak için bile `await`
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testLoadFailureMovesToFailedStateWithMessage() async {
        let service = StubBookService(books: .failure(.networkUnavailable))
        let viewModel = BookListViewModel(service: service)

        await viewModel.load()

        // Mesajı elle yazmak yerine hatanın kendi açıklamasıyla karşılaştırıyoruz; metin değişse test bozulmaz.
        let expectedMessage = BookServiceError.networkUnavailable.localizedDescription
        XCTAssertEqual(viewModel.state, .failed(message: expectedMessage))
    }

    @MainActor
    func testRetryAfterFailureLoadsAgain() async {
        let service = StubBookService(books: .failure(.networkUnavailable))
        let viewModel = BookListViewModel(service: service)
        await viewModel.load()
        guard case .failed = viewModel.state else {
            return XCTFail("İlk yükleme başarısız olmalıydı, durum: \(viewModel.state)")
        }

        await service.setBooksResult(.success(Book.fixtures))
        await viewModel.load() // "Tekrar Dene" düğmesinin yaptığı şey

        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
        let calls = await service.fetchBooksCallCount
        XCTAssertEqual(calls, 2)
    }

    /// `.task` sekmeye her dönüşte yeniden çalışır; yüklü liste tekrar indirilmemeli.
    @MainActor
    func testLoadWhenAlreadyLoadedDoesNotFetchAgain() async {
        let service = StubBookService()
        let viewModel = BookListViewModel(service: service)

        await viewModel.load()
        await viewModel.load()

        let calls = await service.fetchBooksCallCount
        XCTAssertEqual(calls, 1)
    }

    /// Aynı anda iki `load()` (ör. `.task` + "Tekrar Dene") servisi yalnızca BİR kez çağırmalı.
    @MainActor
    func testConcurrentLoadsCallServiceOnlyOnce() async {
        let service = StubBookService(delay: .milliseconds(50))
        let viewModel = BookListViewModel(service: service)

        // İki yapılandırılmamış Task; ikisi de ana actor'ü devralır. İlki `state = .loading` yapıp servisi
        // beklerken askıya alınır; ikincisi çalıştığında `.loading` görür ve hemen döner.
        let first = Task { await viewModel.load() }
        let second = Task { await viewModel.load() }
        await first.value
        await second.value

        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
        let calls = await service.fetchBooksCallCount
        XCTAssertEqual(calls, 1)
    }

    /// Kullanıcı ekrandan ayrılınca SwiftUI `.task`'ı iptal eder. Bu bir hata DEĞİL:
    /// hata ekranı gösterilmemeli ve view tekrar göründüğünde yükleme yeniden başlayabilmeli.
    @MainActor
    func testCancelledLoadIsNotTreatedAsErrorAndCanStartAgain() async {
        // Uzun gecikme: iptal etmezsek test 10 sn sürerdi. `Task.sleep` iptal edilince HEMEN
        // `CancellationError` fırlattığı için test aslında milisaniyeler içinde biter.
        let service = StubBookService(delay: .seconds(10))
        let viewModel = BookListViewModel(service: service)

        let firstLoad = Task { await viewModel.load() }
        await bookListWaitUntil { viewModel.state == .loading }
        firstLoad.cancel()
        await firstLoad.value

        XCTAssertEqual(viewModel.state, .idle, "İptal, hata olarak gösterilmemeli")

        // View tekrar göründü: yeni `.task` → yeni `load()`. Guard tarafından engellenmemeli.
        let secondLoad = Task { await viewModel.load() }
        await bookListWaitUntil { viewModel.state == .loading }
        let calls = await service.fetchBooksCallCount
        XCTAssertEqual(calls, 2, "İptalden sonra yükleme yeniden başlayabilmeli")

        secondLoad.cancel()
        await secondLoad.value
        XCTAssertEqual(viewModel.state, .idle)
    }

    /// Pull-to-refresh sırasında eski liste ekranda kalmalı, bitince yenisiyle değişmeli.
    @MainActor
    func testRefreshKeepsExistingContentWhileRefreshing() async {
        let service = StubBookService(delay: .milliseconds(100))
        let viewModel = BookListViewModel(service: service)
        await viewModel.load()
        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))

        let updatedBooks = [Book.fixture(id: 42, title: "Yeni Kitap")]
        await service.setBooksResult(.success(updatedBooks))

        let refresh = Task { await viewModel.refresh() }
        await bookListWaitUntil { viewModel.isRefreshing }
        // Yenileme sürerken: içerik hâlâ eski liste, `.loading`'e düşmedik.
        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))

        await refresh.value
        XCTAssertFalse(viewModel.isRefreshing)
        XCTAssertEqual(viewModel.state, .loaded(updatedBooks))
        XCTAssertNil(viewModel.refreshErrorMessage)
    }

    /// Yenileme başarısız olursa liste silinmemeli; sadece uyarı mesajı çıkmalı.
    @MainActor
    func testRefreshFailureKeepsContentAndShowsMessage() async {
        let service = StubBookService()
        let viewModel = BookListViewModel(service: service)
        await viewModel.load()

        await service.setBooksResult(.failure(.networkUnavailable))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
        XCTAssertEqual(viewModel.refreshErrorMessage, BookServiceError.networkUnavailable.localizedDescription)

        // Bir sonraki başarılı yenileme uyarıyı temizler.
        await service.setBooksResult(.success(Book.fixtures))
        await viewModel.refresh()
        XCTAssertNil(viewModel.refreshErrorMessage)
    }

    /// Henüz liste yokken yenileme, normal bir yükleme gibi davranır.
    @MainActor
    func testRefreshWithoutContentPerformsInitialLoad() async {
        let service = StubBookService()
        let viewModel = BookListViewModel(service: service)

        await viewModel.refresh()

        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
    }
}

/// Koşul sağlanana kadar ana actor'ü kısa kısa serbest bırakır (`Task.yield()`), böylece arka planda başlattığımız
/// `Task` ilerleyebilir. Sonsuz döngüye girmemek için deneme sayısı sınırlı; koşul hiç sağlanmazsa test başarısız olur.
///
/// Neden `sleep` değil? Sabit bir süre beklemek hem yavaş hem de yavaş bir CI makinesinde kırılgandır.
/// Neden `private` ve önekli ad? Tüm test dosyaları tek bir modülde derleniyor; genel adlı yardımcılar çakışabilir.
@MainActor
private func bookListWaitUntil(
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
