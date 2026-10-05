import Foundation

// MARK: - VIPER sözleşmeleri: Kitap Arama (servis çağrısı yapan modül)
//
// Okuma Notları modülünün (`NotesListContracts.swift`) ikinci örneği. Fark: Bu modül gerçek (taklit edilmiş ağ
// gecikmeli) bir servis çağırır, yazarken arar, eski aramayı iptal eder ve satıra dokununca GERÇEK bir navigasyon yapar.
//
// Bir aramanın yolculuğu ("atay" yazıldı):
//
//   View (BookSearchViewController)          searchBar(_:textDidChange:)
//     │  presenter.didChangeSearchText("atay")                         ▲ render(.loading) … render(.results(rows))
//     ▼                                                                │
//   Presenter (BookSearchPresenter)          interactor.search(query: "atay", trigger: .typing)
//     │                                                                ▲ didStartSearching / didFindBooks(_:for:)
//     ▼                                                                │
//   Interactor (BookSearchInteractor)        Task: önceki aramayı iptal et → 300 ms bekle → await use case
//     │                                                                ▲ [Book] (sıralı)
//     ▼                                                                │
//   Use case (SearchBooksUseCase)            kırp, en az 2 harf → await service.fetchBooks() → eşleştir, sırala
//     ▼
//   Servis (BookServiceProtocol → LocalBookService, 600 ms taklit ağ gecikmesi)
//
//   Satıra dokununca: View → presenter.didSelectBook(id:) → router.showBookDetail(book) → push (UIHostingController)
//                     ve interactor.rememberSearch("atay") → son aramalara yazılır.
//
// Sahiplik notlar modülüyle birebir aynı: VC → presenter → (interactor, router) strong; geri dönenler weak
// (presenter.view, interactor.output, router.viewController). Kanıtı: `BookSearchRouterTests`.
//
// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
// NEDEN HEPSİ @MainActor?
// ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────
// 1. View bir `UIViewController`. UIKit onu SDK'da `@MainActor` işaretler; UI'a yalnızca ana thread'den dokunulur.
//    View protokolü de `@MainActor` olmalı ki presenter `view?.render(...)` çağrısını `await` olmadan yapabilsin.
// 2. Presenter view'ı SENKRON çağırır; interactor da sonucu presenter'a (output) senkron bildirir. Dördü aynı actor'de
//    olunca bu çağrılar düz fonksiyon çağrısıdır: actor değiştirme (hop) yok, `await` yok. Modülün değişen durumu
//    (`searchText`, son sonuçlar, uçuştaki `searchTask`) TEK bir seri yerde yaşar; iki thread aynı anda dokunamaz.
//    Data race olmadığını derleyici derleme anında kanıtlar (Swift 6 dil modu).
// 3. "@MainActor = her şey ana thread'de" DEĞİL. Yavaş iş (servis çağrısı, JSON çözme, filtreleme, sıralama) nonisolated
//    `async` use case'lerde. Interactor `await useCase.execute(...)` dediğinde ana actor'den ÇIKILIR (bu projenin
//    ayarlarıyla nonisolated async fonksiyon global concurrent executor'de çalışır), iş bitince ana actor'e GERİ dönülür.
//    Her `await` bir "askıya alma noktası"dır: ana thread bu sırada dokunuşları, kaydırmayı, çizimi işler.
//    Formül: "durum ve koordinasyon ana actor'de, hesap ve bekleme dışarıda."
// 4. Interactor'ı ayrı bir actor yapmak mümkündü ama kazanç yok: interactor'ın kendi işi hesap değil koordinasyon.
//    Bedeli: Her `output` çağrısı ana actor'e bir `await` (hop) olur. (`MainActor.run` gerekmez: `@MainActor` bir
//    metodu başka bir actor'den çağırmak için `await output?.didFindBooks(...)` yeter; geçişi derleyici yapar.) Daha
//    önemlisi presenter → interactor çağrıları da async olur: presenter senkron kalamaz, durum iki actor arasında
//    bölünür, testler zorlaşır.
// 5. Aynı fikri Xcode 26'nın yeni proje şablonları modül varsayılanı yapar: "Default Actor Isolation = MainActor"
//    (`SWIFT_DEFAULT_ACTOR_ISOLATION`, SE-0466) işaretsiz her şeyi `@MainActor` sayar; "Approachable Concurrency"
//    (`NonisolatedNonsendingByDefault`, SE-0461) nonisolated async fonksiyonları ÇAĞIRANIN actor'ünde çalıştırır.
//    O ayarlarla dışarı çıkmak isteyen kod bunu açıkça söyler: tip/fonksiyon için `nonisolated`, "bu async iş kesinlikle
//    arka planda çalışsın" için `@concurrent`. Bu projede ikisi de kapalı; bu yüzden `@MainActor`'ü açıkça yazıyoruz ve
//    use case'ler kendiliğinden nonisolated.
//
// Bu dosya UIKit import etmiyor: sözleşmeler UI çatısından bağımsız; testler sahte (spy/mock) uygulamalar yazar.

/// **View** ← Presenter. Pasif: karar vermez, söyleneni çizer.
@MainActor
protocol BookSearchViewProtocol: AnyObject {
    func render(_ state: BookSearchViewState)
    /// Kısa bilgi satırı, ör. "“Huzur” favorilere eklendi."
    func showStatus(_ message: String)
    func showError(title: String, message: String)
}

/// **Presenter** ← View. Kullanıcı olayları. Kitaplar `id` ile gelir: View `Book` tutmaz, yalnızca satırları (`BookSearchRow`).
@MainActor
protocol BookSearchPresenterProtocol {
    func viewDidLoad()
    /// Arama kutusundaki metin değişti (her harfte).
    func didChangeSearchText(_ text: String)
    /// Klavyedeki "Ara" düğmesi: beklemeden ara.
    func didSubmitSearch(_ text: String)
    func didSelectRecentSearch(_ query: String)
    func didSelectBook(id: Book.ID)
    func didRequestInsights(forBookID id: Book.ID)
    func didRequestFavoriteToggle(forBookID id: Book.ID)
    func didTapRetry()
}

/// Bir aramayı neyin başlattığı. Zamanlamayı da (debounce) geçmişe yazılıp yazılmayacağını da bu belirler.
enum BookSearchTrigger: Equatable, Sendable {
    /// Kullanıcı yazıyor: kısa bir süre (`BookSearchConfiguration.debounce`) bekle; o sürede yeni harf gelirse bu arama
    /// hiç yapılmaz. Sonuç geçmişe YAZILMAZ: "t", "tu", "tut"… gibi ara aramalar geçmişi kirletirdi.
    case typing
    /// Açık istek (Ara düğmesi, geçmişten seçim, Tekrar dene): beklemeden ara; sonuç veren arama geçmişe yazılır.
    case submitted
}

/// **Interactor girişi** ← Presenter. Metotlar sonuç döndürmez; sonuç `BookSearchInteractorOutput` ile **sonra** gelir.
@MainActor
protocol BookSearchInteractorInput {
    func loadRecentSearches()
    /// Önceki aramayı iptal eder ve yenisini başlatır ("son arama kazanır").
    func search(query: String, trigger: BookSearchTrigger)
    /// Uçuştaki aramayı iptal eder (ör. kutu temizlendi). Sonuç gelmez.
    func cancelSearch()
    /// Sorguyu son aramalara yazar. Kullanıcı yazarak bulduğu sonuçlardan birini AÇTIĞINDA: arama işe yaradı demektir.
    func rememberSearch(_ query: String)
    func loadInsights(for book: Book)
    func toggleFavorite(for book: Book)
}

/// **Interactor çıkışı** → Presenter. Interactor bunu uygulayan nesneyi (presenter'ı) `weak` tutar.
@MainActor
protocol BookSearchInteractorOutput: AnyObject {
    func didLoadRecentSearches(_ queries: [String])
    /// Debounce bitti, servis çağrısı başlıyor (yükleniyor göstermek için doğru an).
    func didStartSearching(query: String)
    func didFindBooks(_ books: [Book], for query: String)
    /// İş kuralı ihlali (ör. tek harf). Bir hata değil, kullanıcıya ipucu.
    func didRejectQuery(_ error: SearchQueryError)
    func didFailSearch(_ error: any Error, query: String)
    func didLoadInsights(_ insights: BookInsights)
    func didFailInsights(_ error: any Error, for book: Book)
    func didToggleFavorite(_ book: Book, isFavorite: Bool)
}

/// **Router** ← Presenter. Navigasyon: hangi ekran, nasıl açılır. Modülü kuran `build(...)` da router'da.
@MainActor
protocol BookSearchRouterProtocol {
    /// Kitap detayını açar (gerçek push).
    func showBookDetail(_ book: Book)
    /// Kitap özetini gösterir. Metin presenter'da hazırlanır; router yalnızca "nasıl gösterilir"i bilir.
    func showInsights(_ summary: BookInsightsSummary)
}

/// Presenter'ın View'a verdiği **hazır** durum. Tüm metinler hazır; View biçimlendirme yapmaz.
enum BookSearchViewState: Equatable, Sendable {
    /// Arama kutusu boş: son aramaları göster (en yeni başta).
    case idle(recentSearches: [String])
    /// Servis çağrısı sürüyor.
    case loading
    case results(rows: [BookSearchRow])
    /// Sonuç yok ya da sorgu kurala uymuyor; açıklayan bir mesaj.
    case empty(message: String)
    /// Servis hatası. `canRetry`: "Tekrar dene" düğmesi gösterilsin mi? (Tekrar denemenin işe yaramayacağı hatalarda hayır.)
    case error(message: String, canRetry: Bool)
}

/// Sonuç listesindeki bir satırın hazır metinleri.
struct BookSearchRow: Identifiable, Hashable, Sendable {
    let id: Book.ID
    let title: String
    /// "Oğuz Atay · 1972"
    let detail: String
}

/// Kitap özetinin ekrana hazır hali (başlık + satırlar). Presenter üretir, router gösterir.
struct BookInsightsSummary: Equatable, Sendable {
    let title: String
    let lines: [String]

    /// Alert mesajı: satırlar alt alta.
    var message: String { lines.joined(separator: "\n") }
}
