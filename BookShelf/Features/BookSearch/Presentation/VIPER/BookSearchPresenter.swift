import Foundation

/// **VIPER → Presenter.** View'dan olay alır; Interactor'a iş, Router'a navigasyon yaptırır; Interactor'dan gelen domain
/// sonucunu (`[Book]`, `SearchQueryError`, `BookInsights`, hatalar) View'ın doğrudan çizebileceği duruma ve Türkçe
/// metinlere çevirir.
///
/// Bilerek `import UIKit` YOK ve hiç `await` yok: Presenter tamamen senkron. Testleri sahte View/Interactor/Router ile
/// bekleme olmadan çalışır (bkz. `BookSearchPresenterTests`). Async iş, iptal ve zamanlama interactor'da.
///
/// Presenter'ın tuttuğu durum **sunum durumu**dur, iş durumu değil:
/// - `searchText`: Kutuda ne yazıyor? Boşsa geçmişi göster. Geç gelen bir "geçmiş yüklendi" haberi, kullanıcı yazmaya
///   başlamışsa sonuç listesini EZMEMELİ (bkz. `didLoadRecentSearches`).
/// - `results`: Son gösterilen kitaplar. View yalnızca `id` gönderir; dokunulan kitabı presenter buradan bulur.
/// - `resultsQuery`: `results`'ı bulan sorgu. Kutudaki metinle aynı olmak zorunda değil (bkz. `didSelectBook`).
@MainActor
final class BookSearchPresenter {
    weak var view: (any BookSearchViewProtocol)?
    let interactor: any BookSearchInteractorInput
    let router: any BookSearchRouterProtocol

    private(set) var searchText = ""
    private(set) var recentSearches: [String] = []
    private(set) var results: [Book] = []
    /// Ekrandaki satırları bulan sorgu (interactor'ın kırptığı hali). Kullanıcı bir harf daha yazınca debounce süresince
    /// (300 ms) eski satırlar ekranda kalır; kutuda artık "atayz" yazar ama satırlar "atay"ındır.
    private(set) var resultsQuery = ""

    init(interactor: any BookSearchInteractorInput, router: any BookSearchRouterProtocol) {
        self.interactor = interactor
        self.router = router
    }

    // MARK: - Saf çeviriler (static: `self`'e ve View'a erişemez; girdi → çıktı)

    /// Bulunan kitapları ekran durumuna çevirir.
    static func viewState(for books: [Book], query: String) -> BookSearchViewState {
        guard !books.isEmpty else {
            return .empty(message: "“\(query)” için sonuç bulunamadı. Kitap adının ya da yazarın bir kısmını dene.")
        }
        return .results(rows: books.map(row(for:)))
    }

    /// "Oğuz Atay · 1972". `String(year)`: sayı biçimlendirici bazı dillerde "1.972" yazabilirdi.
    static func row(for book: Book) -> BookSearchRow {
        BookSearchRow(id: book.id, title: book.title, detail: "\(book.author) · \(String(book.year))")
    }

    /// Kural ihlalinin Türkçe karşılığı. Kural domain'de, cümle burada.
    static func message(for error: SearchQueryError) -> String {
        switch error {
        case .tooShort(let minimumLength):
            "Aramak için en az \(minimumLength) harf yaz."
        }
    }

    /// Servis hatasını mesaja ve "tekrar denensin mi?" kararına çevirir.
    ///
    /// Bağlantı hatası geçicidir → "Tekrar dene" anlamlı. Paketteki veri eksik/bozuksa tekrar denemek aynı sonucu verir →
    /// düğme gösterilmez (kullanıcıyı boşuna denetmeyelim). Mesajlar `BookServiceError`'ın kendi Türkçe açıklamaları.
    static func errorState(for error: any Error) -> BookSearchViewState {
        guard let serviceError = error as? BookServiceError else {
            return .error(message: "Arama yapılamadı. Lütfen tekrar deneyin.", canRetry: true)
        }
        let message = serviceError.localizedDescription
        switch serviceError {
        case .networkUnavailable:
            return .error(message: message, canRetry: true)
        case .resourceMissing, .decodingFailed, .authorNotFound:
            return .error(message: message, canRetry: false)
        }
    }

    /// Kitap özetini başlık + satırlara çevirir. Ondalık ayırıcı cihaz dilinden bağımsız olarak Türkçe (4,7).
    static func insightsSummary(for insights: BookInsights) -> BookInsightsSummary {
        var lines: [String] = []
        if let average = insights.averageRating {
            let formatted = average.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "tr_TR")))
            lines.append("\(insights.reviewCount) yorum · ortalama \(formatted) / 5")
        } else {
            lines.append("Henüz yorum yok.")
        }

        let author = insights.book.author
        switch (insights.authorBookCount, insights.authorHasOtherBooks) {
        case let (count?, true?):
            lines.append("\(author): kitaplıkta \(count) kitabı var. Yazarın başka kitabı da var.")
        case (_?, false?):
            lines.append("\(author): kitaplıktaki tek kitabı bu.")
        default:
            // Kısmi hata politikası (use case): yazar profili isteğe bağlı. Özet yine gösterilir.
            lines.append("\(author) hakkındaki bilgi şu an alınamadı.")
        }
        return BookInsightsSummary(title: insights.book.title, lines: lines)
    }

    // MARK: - Yardımcılar

    private func book(withID id: Book.ID) -> Book? {
        results.first { $0.id == id }
    }

    /// Satırlar ekrandan kalkınca onları bulan sorgu da unutulur; ikisi hep birlikte değişir.
    private func clearResults() {
        results = []
        resultsQuery = ""
    }

    private func updateSearch(_ text: String, trigger: BookSearchTrigger) {
        searchText = text
        // Sunum kararı: Kutu boşsa arama yok, geçmiş var. (Yalnızca boşluk ise kurala gider: "en az 2 harf".)
        guard !text.isEmpty else {
            interactor.cancelSearch()
            clearResults()
            view?.render(.idle(recentSearches: recentSearches))
            return
        }
        interactor.search(query: text, trigger: trigger)
    }
}

// MARK: - View → Presenter

extension BookSearchPresenter: BookSearchPresenterProtocol {
    func viewDidLoad() {
        view?.render(.idle(recentSearches: recentSearches))
        interactor.loadRecentSearches()
    }

    /// Yazarken: debounce ile (her harfte istek gitmesin), geçmişe yazmadan.
    func didChangeSearchText(_ text: String) {
        updateSearch(text, trigger: .typing)
    }

    /// Klavyedeki "Ara": kullanıcı ne istediğini söyledi; beklemeye gerek yok, sonuç verirse geçmişe yazılır.
    func didSubmitSearch(_ text: String) {
        updateSearch(text, trigger: .submitted)
    }

    func didSelectRecentSearch(_ query: String) {
        searchText = query
        interactor.search(query: query, trigger: .submitted)
    }

    /// Detayı aç ve aramayı hatırla: Kullanıcı yazarak bulduğu bir sonucu açtıysa o arama işe yaramıştır.
    ///
    /// Hatırlanan, kutudaki metin (`searchText`) DEĞİL, satırı bulan sorgu (`resultsQuery`). Debounce sırasında kutuda
    /// bir önek ("ata") ya da hiç sonuç vermeyecek bir metin ("atayz") olabilir; onu yazmak "sonuç vermeyen arama
    /// geçmişe yazılmaz" kuralını bozardı.
    func didSelectBook(id: Book.ID) {
        guard let book = book(withID: id) else { return }
        router.showBookDetail(book)
        interactor.rememberSearch(resultsQuery)
    }

    func didRequestInsights(forBookID id: Book.ID) {
        guard let book = book(withID: id) else { return }
        interactor.loadInsights(for: book)
    }

    func didRequestFavoriteToggle(forBookID id: Book.ID) {
        guard let book = book(withID: id) else { return }
        interactor.toggleFavorite(for: book)
    }

    func didTapRetry() {
        guard !searchText.isEmpty else { return }
        interactor.search(query: searchText, trigger: .submitted)
    }
}

// MARK: - Interactor → Presenter

extension BookSearchPresenter: BookSearchInteractorOutput {
    func didLoadRecentSearches(_ queries: [String]) {
        recentSearches = queries
        // Geç gelen haber: Kullanıcı bu arada yazmaya başladıysa ekrandaki sonuçları geçmişle ezme; sadece sakla.
        guard searchText.isEmpty else { return }
        view?.render(.idle(recentSearches: queries))
    }

    func didStartSearching(query: String) {
        view?.render(.loading)
    }

    func didFindBooks(_ books: [Book], for query: String) {
        results = books
        resultsQuery = query
        view?.render(Self.viewState(for: books, query: query))
    }

    func didRejectQuery(_ error: SearchQueryError) {
        clearResults()
        view?.render(.empty(message: Self.message(for: error)))
    }

    func didFailSearch(_ error: any Error, query: String) {
        clearResults()
        view?.render(Self.errorState(for: error))
    }

    func didLoadInsights(_ insights: BookInsights) {
        router.showInsights(Self.insightsSummary(for: insights))
    }

    func didFailInsights(_ error: any Error, for book: Book) {
        view?.showError(title: "Özet yüklenemedi", message: "“\(book.title)”: \(error.localizedDescription)")
    }

    func didToggleFavorite(_ book: Book, isFavorite: Bool) {
        view?.showStatus(isFavorite ? "“\(book.title)” favorilere eklendi." : "“\(book.title)” favorilerden çıkarıldı.")
    }
}
