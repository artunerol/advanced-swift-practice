import Foundation
import XCTest
@testable import BookShelf

/// Kitap Arama (VIPER + servis çağrısı) testlerinin sahte nesneleri (test doubles).
///
/// Hepsi bir `enum` isim alanında: Test hedefi tek modül; Okuma Notları'nın `NotesArchitectureDoubles.ViewSpy`'ı ile
/// çakışmasın. Kullanım: `BookSearchArchitectureDoubles.ViewSpy()`.
///
/// Adlar ROLÜ söyler ve her birinin üstünde "neden bu tür?" sorusunun tek satırlık cevabı var:
/// - **Stub:** Hazır cevap döndürür; test onun nasıl çağrıldığıyla ilgilenmez.
/// - **Spy:** Çağrıları kaydeder; doğrulamayı (assert) TEST yapar.
/// - **Mock:** Beklenen çağrıları ÖNCEDEN bilir; doğrulamayı KENDİSİ yapar (`verify()`).
/// - **Fake:** Gerçekten çalışan ama basitleştirilmiş uygulama (uygulama hedefindeki `InMemoryRecentSearchesStore`).
/// - **Dummy:** Yalnızca imzayı doldurur, hiç kullanılmaz (ör. kaydırma eylemi handler'ına verilen `UIView()`).
enum BookSearchArchitectureDoubles {

    // MARK: - Use case double'ları (interactor testleri)

    /// **Spy:** Hangi sorgularla çağrıldığını, hangisinin iptal edildiğini kaydeder; interactor testleri bunlara bakar.
    /// Cevaplar sorgu başına önceden ayarlanır (o yönüyle stub da). Doğrulama kuralı (`validatedQuery`) GERÇEK kuraldır;
    /// spy'ın kontrol ettiği tek şey yavaş kısım: `execute`'un ne zaman ve ne döndüreceği.
    ///
    /// Neden `actor`? Protokol `Sendable` istiyor, spy ise kayıt tutmak (değişken durum) zorunda.
    actor SearchBooksUseCaseSpy: SearchBooksUseCaseProtocol {
        /// Bir sorgunun cevabı ve ne zaman geleceği.
        struct Response: Sendable {
            var result: Result<[Book], BookServiceError>
            /// İptal edilebilir bekleme (`Task.sleep`): iptal edilince hemen `CancellationError`.
            var delay: Duration = .zero
            /// `true` ise test `release(_:)` diyene kadar bekler ve iptali GÖRMEZDEN gelir (iptale tepki vermeyen,
            /// "yavaş ve inatçı" bir servis). Interactor'ın `await` sonrası iptal kontrolünü test etmek için.
            var waitsForRelease = false
            /// `delay` iptalle kesilince fırlatılacak hata. `nil`: `Task.sleep`'in kendi `CancellationError`'ı.
            /// `URLError(.cancelled)`: `URLSession` gibi davranır; iptal edilen istek `CancellationError` ile bitmez.
            var errorOnCancel: (any Error)?
        }

        private let responses: [String: Response]
        private let fallback: Response
        private var pendingReleases: [String: CheckedContinuation<Void, Never>] = [:]

        private(set) var executedQueries: [String] = []
        private(set) var cancelledQueries: [String] = []

        init(responses: [String: Response] = [:], fallback: Response = Response(result: .success([]))) {
            self.responses = responses
            self.fallback = fallback
        }

        nonisolated func validatedQuery(_ rawQuery: String) throws(SearchQueryError) -> String {
            try SearchBooksUseCase.validate(rawQuery)
        }

        func execute(query: String) async throws -> [Book] {
            executedQueries.append(query)
            let response = responses[query] ?? fallback
            if response.waitsForRelease {
                // `withCheckedContinuation` iptali bilmez: test serbest bırakana kadar bekler.
                await withCheckedContinuation { continuation in
                    pendingReleases[query] = continuation
                }
            } else if response.delay > .zero {
                do {
                    try await Task.sleep(for: response.delay)
                } catch {
                    cancelledQueries.append(query)
                    throw response.errorOnCancel ?? error
                }
            }
            return try response.result.get()
        }

        /// `waitsForRelease` ile bekleyen sorguyu serbest bırakır.
        func release(_ query: String) {
            pendingReleases.removeValue(forKey: query)?.resume()
        }

        func isWaitingForRelease(_ query: String) -> Bool {
            pendingReleases[query] != nil
        }
    }

    /// **Stub:** Önceden verilen sonucu döndürür. Interactor testleri yalnızca sonucun output'a nasıl iletildiğine bakar.
    struct LoadBookInsightsUseCaseStub: LoadBookInsightsUseCaseProtocol {
        var result: Result<BookInsights, BookServiceError>
        /// Bu kitapların isteği iptal edilene kadar sürer ve `URLSession` gibi `URLError(.cancelled)` ile biter
        /// (`CancellationError` ile değil). "İkinci özet isteği birincisini iptal eder" senaryosu için.
        var slowBookIDs: Set<Book.ID> = []

        func execute(for book: Book) async throws -> BookInsights {
            if slowBookIDs.contains(book.id) {
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    throw URLError(.cancelled)
                }
            }
            return try result.get()
        }
    }

    /// **Spy:** Hangi kitabın favori durumunun değiştirildiğini kaydeder; yeni durumu basit bir küme üzerinde hesaplar.
    actor ToggleFavoriteUseCaseSpy: ToggleFavoriteUseCaseProtocol {
        private var favorites: Set<Book.ID> = []
        private(set) var toggledBookIDs: [Book.ID] = []

        func execute(bookID: Book.ID) async -> Bool {
            toggledBookIDs.append(bookID)
            if favorites.remove(bookID) == nil {
                favorites.insert(bookID)
                return true
            }
            return false
        }
    }

    /// **Spy:** Geçmişe neyin yazıldığını (`recordedQueries`) kaydeder; "yalnızca taahhüt edilmiş başarılı arama yazılır"
    /// testleri buna bakar.
    actor RecentSearchesUseCaseSpy: RecentSearchesUseCaseProtocol {
        private var stored: [String]
        private(set) var recordedQueries: [String] = []

        init(stored: [String] = []) {
            self.stored = stored
        }

        func load() async -> [String] {
            stored
        }

        func record(_ query: String) async -> [String] {
            recordedQueries.append(query)
            stored.insert(query, at: 0)
            return stored
        }
    }

    // MARK: - VIPER parçalarının double'ları

    /// **Spy:** Interactor'ın çıkışını dinler ve olayları sırasıyla kaydeder. Interactor işini bir `Task` içinde, SONRA
    /// bitirir; test beklemek için `onEvent`'e bir `XCTestExpectation`'ın `fulfill()`'ını koyar.
    @MainActor
    final class InteractorOutputSpy: BookSearchInteractorOutput {
        enum Event: Equatable {
            case recentLoaded([String])
            case started(String)
            /// Bulunan kitapların kimlikleri (sırası önemli) ve sorgu.
            case found([Book.ID], query: String)
            case rejected(SearchQueryError)
            case failed(String, query: String)
            case insightsLoaded(BookInsights)
            case insightsFailed(String, bookID: Book.ID)
            case favoriteToggled(Book.ID, isFavorite: Bool)
        }

        private(set) var events: [Event] = []
        var onEvent: (() -> Void)?

        func didLoadRecentSearches(_ queries: [String]) { record(.recentLoaded(queries)) }
        func didStartSearching(query: String) { record(.started(query)) }
        func didFindBooks(_ books: [Book], for query: String) { record(.found(books.map(\.id), query: query)) }
        func didRejectQuery(_ error: SearchQueryError) { record(.rejected(error)) }
        func didFailSearch(_ error: any Error, query: String) { record(.failed(error.localizedDescription, query: query)) }
        func didLoadInsights(_ insights: BookInsights) { record(.insightsLoaded(insights)) }
        func didFailInsights(_ error: any Error, for book: Book) {
            record(.insightsFailed(error.localizedDescription, bookID: book.id))
        }
        func didToggleFavorite(_ book: Book, isFavorite: Bool) { record(.favoriteToggled(book.id, isFavorite: isFavorite)) }

        private func record(_ event: Event) {
            events.append(event)
            onEvent?()
        }
    }

    /// **Spy:** Presenter'ın View'a ne çizdirdiğini kaydeder.
    @MainActor
    final class ViewSpy: BookSearchViewProtocol {
        private(set) var renderedStates: [BookSearchViewState] = []
        private(set) var statuses: [String] = []
        private(set) var errors: [(title: String, message: String)] = []

        func render(_ state: BookSearchViewState) { renderedStates.append(state) }
        func showStatus(_ message: String) { statuses.append(message) }
        func showError(title: String, message: String) { errors.append((title, message)) }
    }

    /// **Mock:** Presenter'dan BEKLENEN interactor çağrılarını önceden bilir ve doğrulamayı kendisi yapar (`verify()`).
    ///
    /// Spy'dan farkı doğrulamanın yeri: Test "şunlar beklenir" der (`expect`), sonra `verify()` der; karşılaştırma ve
    /// hata mesajı mock'un içinde. Presenter'ın işi neredeyse tamamen "doğru çağrıyı doğru argümanla yapmak" olduğu için
    /// burada mock uygun. Bedeli: Test, çağrıların sırasına ve sayısına sıkıca bağlanır; refactor'da daha kolay kırılır.
    @MainActor
    final class InteractorMock: BookSearchInteractorInput {
        enum Call: Equatable {
            case loadRecentSearches
            case search(query: String, trigger: BookSearchTrigger)
            case cancelSearch
            case rememberSearch(String)
            case loadInsights(bookID: Book.ID)
            case toggleFavorite(bookID: Book.ID)
        }

        private var expectedCalls: [Call] = []
        private(set) var receivedCalls: [Call] = []

        func expect(_ calls: Call...) {
            expectedCalls.append(contentsOf: calls)
        }

        /// Beklenen çağrılar, beklenen sırayla ve fazlası olmadan yapıldı mı?
        func verify(file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(receivedCalls, expectedCalls, "Interactor'a beklenmeyen çağrılar", file: file, line: line)
        }

        func loadRecentSearches() { receivedCalls.append(.loadRecentSearches) }
        func search(query: String, trigger: BookSearchTrigger) { receivedCalls.append(.search(query: query, trigger: trigger)) }
        func cancelSearch() { receivedCalls.append(.cancelSearch) }
        func rememberSearch(_ query: String) { receivedCalls.append(.rememberSearch(query)) }
        func loadInsights(for book: Book) { receivedCalls.append(.loadInsights(bookID: book.id)) }
        func toggleFavorite(for book: Book) { receivedCalls.append(.toggleFavorite(bookID: book.id)) }
    }

    /// **Spy:** Router'a hangi navigasyonların istendiğini kaydeder; ekran açmaz.
    @MainActor
    final class RouterSpy: BookSearchRouterProtocol {
        private(set) var shownBooks: [Book] = []
        private(set) var shownInsights: [BookInsightsSummary] = []

        func showBookDetail(_ book: Book) { shownBooks.append(book) }
        func showInsights(_ summary: BookInsightsSummary) { shownInsights.append(summary) }
    }

    /// **Spy:** View controller testleri için presenter'ın yerine geçer; VC'nin hangi olayları ilettiğini kaydeder.
    @MainActor
    final class PresenterSpy: BookSearchPresenterProtocol {
        enum Event: Equatable {
            case viewDidLoad
            case textChanged(String)
            case submitted(String)
            case recentSelected(String)
            case bookSelected(Book.ID)
            case insightsRequested(Book.ID)
            case favoriteToggleRequested(Book.ID)
            case retryTapped
        }

        private(set) var events: [Event] = []

        func viewDidLoad() { events.append(.viewDidLoad) }
        func didChangeSearchText(_ text: String) { events.append(.textChanged(text)) }
        func didSubmitSearch(_ text: String) { events.append(.submitted(text)) }
        func didSelectRecentSearch(_ query: String) { events.append(.recentSelected(query)) }
        func didSelectBook(id: Book.ID) { events.append(.bookSelected(id)) }
        func didRequestInsights(forBookID id: Book.ID) { events.append(.insightsRequested(id)) }
        func didRequestFavoriteToggle(forBookID id: Book.ID) { events.append(.favoriteToggleRequested(id)) }
        func didTapRetry() { events.append(.retryTapped) }
    }

    // MARK: - Test verisi

    /// Uygulamadaki `books.json`'un 8 kitabı (Türkçe harfli başlık ve yazarlar). Arama kurallarını gerçekçi veriyle sınamak için.
    static let catalog: [Book] = [
        .fixture(id: 1, title: "Tutunamayanlar", author: "Oğuz Atay", year: 1972),
        .fixture(id: 2, title: "Kürk Mantolu Madonna", author: "Sabahattin Ali", year: 1943),
        .fixture(id: 3, title: "Saatleri Ayarlama Enstitüsü", author: "Ahmet Hamdi Tanpınar", year: 1961),
        .fixture(id: 4, title: "İnce Memed", author: "Yaşar Kemal", year: 1955),
        .fixture(id: 5, title: "Benim Adım Kırmızı", author: "Orhan Pamuk", year: 1998),
        .fixture(id: 6, title: "Tehlikeli Oyunlar", author: "Oğuz Atay", year: 1973),
        .fixture(id: 7, title: "Kuyucaklı Yusuf", author: "Sabahattin Ali", year: 1937),
        .fixture(id: 8, title: "Huzur", author: "Ahmet Hamdi Tanpınar", year: 1949),
    ]

    static func book(_ id: Book.ID) -> Book {
        catalog.first { $0.id == id }!
    }

    // MARK: - Bekleme yardımcısı

    /// `condition` doğru olana kadar kısa aralıklarla yoklar; en fazla `timeout` bekler, sonra testi kırar.
    ///
    /// Sabit `sleep(1)` yerine bu: koşul sağlandığı an döner (hızlı) ve bir üst sınırı var (asılı kalmaz).
    /// Koşul `async` olabilir; actor'deki bir sayaca `await` ile bakmak için.
    @MainActor
    static func waitUntil(
        _ description: String,
        timeout: Duration = .seconds(3),
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () async -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while await !condition() {
            guard clock.now < deadline else {
                XCTFail("Zaman aşımı: \(description)", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
