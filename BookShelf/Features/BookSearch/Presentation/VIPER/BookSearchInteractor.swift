import Foundation

/// **VIPER → Interactor.** Use case'leri çalıştırır ve sonucu `output`'a (presenter'a) bildirir. UIKit ve metin bilmez.
///
/// Bu modülde interactor'ın asıl işi **zamanlama ve koordinasyon**:
/// - **Senkron → async köprüsü:** Presenter'dan gelen çağrılar senkron (UIKit olayları senkron). Interactor her iş için bir
///   `Task` açar. Task `@MainActor` bağlamını miras alır; `await` sırasında ana thread serbest kalır, use case'ler
///   (nonisolated async) arka planda çalışır, sonuç yine ana actor'de `output`'a iletilir.
/// - **"Son arama kazanır" (iptal):** Uçuştaki arama `searchTask` olarak saklanır. Yeni sorgu gelince önce eskisi
///   `cancel()` edilir. İptal **işbirlikçidir** (cooperative): `cancel()` task'ı zorla durdurmaz, bayrağı kaldırır.
///   Bayrağa tepki veren yerler: `Task.sleep` (debounce sırasında hemen `CancellationError` fırlatır), servisin
///   kendi `Task.sleep`/`checkCancellation`'ı ve bizim `await`'ten sonraki `Task.checkCancellation()` kontrolümüz.
///   Son kontrol kritik: Eski arama tam iptal anında bitmiş olabilir; ana actor'e döndüğünde iptal edildiğini görür ve
///   sonucunu bildirmez. Böylece "ata"nın geç gelen sonucu "atay"ın sonucunu ezemez.
/// - **Debounce:** Yazarken her harfte istek atmamak için `configuration.debounce` kadar bekler. Bekleme bir
///   `Task.sleep`; yeni harf gelince task iptal edilir ve sleep hemen `CancellationError` fırlatır.
/// - **İptal edilmiş bir işin hiçbir sonucu bildirilmez: ne kitaplar ne HATA.** İptal bir hata değildir; kullanıcı yeni
///   bir şey yazdı ya da ekran kapandı. Ama iptal her zaman `CancellationError` olarak gelmez: `URLSession` iptal edilen
///   isteği `URLError(.cancelled)` ile bitirir; servis iptalden hemen önce gerçek bir hata da vermiş olabilir. Bu yüzden
///   ölçüt hatanın TÜRÜ değil task'ın DURUMU: `catch _ where Task.isCancelled` → sessiz. Yoksa her yeni harfte bir an
///   "Arama yapılamadı" görünür ya da eski aramanın hatası yeni aramanın sonuçlarını silerdi.
/// - **Geçmişe yalnızca "taahhüt edilmiş" başarılı aramayı yaz:** Yazarken (`.typing`) yapılan ara aramalar ("t", "tu",
///   "tut"…) yazılmaz; yoksa geçmiş önek çöplüğüne dönerdi (bu hatayı UI testi yakaladı: harf harf silmek her öneki
///   kaydediyordu). Yazılanlar: açık istekle (`.submitted`: Ara, geçmişten seçim, Tekrar dene) yapılıp sonuç veren
///   arama ve sonucundan bir kitabın açıldığı arama (`rememberSearch`). Hata, iptal, kural ihlali ve sonuç vermeyen
///   arama hiçbir zaman yazılmaz. Bu bir koordinasyon kararı: hangi use case, hangi koşulda, hangi sırayla.
///
/// `[weak self]` ve "yerel sabite kopyala" kalıbı (Okuma Notları interactor'ındaki ile aynı):
/// Task'ın ihtiyaç duyduğu değerler (`useCases`'in alanları, `delay`) task açılmadan ÖNCE yerel sabitlere kopyalanır.
/// Hepsi `Sendable`; task onlara ulaşmak için `self`'e muhtaç kalmaz. `self` yalnızca `weak` yakalanır ve yalnızca iş
/// bittikten sonra (`self?.output?...`) kullanılır. Sonuç: 600 ms süren bir ağ çağrısı modülü hayatta TUTMAZ. Ekran
/// kapanırsa interactor serbest kalır, `deinit` uçuştaki aramayı iptal eder, geç gelen sonuç sessizce düşer.
@MainActor
final class BookSearchInteractor {
    /// **weak** + **property injection**: presenter interactor'ı strong tutuyor. `build(...)` atar.
    weak var output: (any BookSearchInteractorOutput)?

    /// **constructor injection**: protokol tipli use case'ler (testte spy'lar) ve zamanlama ayarı.
    private let useCases: BookSearchUseCases
    private let configuration: BookSearchConfiguration

    /// Uçuştaki (in-flight) arama. Yeni arama gelince iptal edilir. `internal` okunabilir: testler iptali gözlesin diye.
    private(set) var searchTask: Task<Void, Never>?
    /// Uçuştaki özet isteği. Aynı ilke: ikinci "Özet" isteği birincisini iptal eder.
    private(set) var insightsTask: Task<Void, Never>?

    init(useCases: BookSearchUseCases, configuration: BookSearchConfiguration = .standard) {
        self.useCases = useCases
        self.configuration = configuration
    }

    /// Modül kapandı: uçuştaki işleri iptal et (boşuna ağ ve CPU harcamasın).
    ///
    /// `deinit` nonisolated'dır (sınıf `@MainActor` olsa bile). Ana actor'e bağlı metot çağıramayız; ama `Task` `Sendable`
    /// ve `cancel()` her thread'den güvenle çağrılabilir. `FavoritesViewController.deinit` ile aynı gerekçe.
    deinit {
        searchTask?.cancel()
        insightsTask?.cancel()
    }
}

extension BookSearchInteractor: BookSearchInteractorInput {
    func loadRecentSearches() {
        let recentSearches = useCases.recentSearches
        Task { [weak self] in
            let queries = await recentSearches.load()
            self?.output?.didLoadRecentSearches(queries)
        }
    }

    func search(query rawQuery: String, trigger: BookSearchTrigger) {
        // 1) Son arama kazanır: yeni bir istek geldi, eskisinin sonucu artık kimseyi ilgilendirmiyor.
        cancelSearch()

        // 2) Kural anında, ağa çıkmadan: tek harf için ne bekleriz ne servis çağırırız.
        //    Typed throws sayesinde `catch` içindeki `error` doğrudan `SearchQueryError`.
        let search = useCases.search
        let query: String
        do {
            query = try search.validatedQuery(rawQuery)
        } catch {
            output?.didRejectQuery(error)
            return
        }

        let recentSearches = useCases.recentSearches
        let delay = trigger == .typing ? configuration.debounce : .zero
        let isCommitted = trigger == .submitted

        searchTask = Task { [weak self] in
            do {
                // 3) Debounce. İptal edilirse `Task.sleep` hemen `CancellationError` fırlatır.
                if delay > .zero {
                    try await Task.sleep(for: delay)
                }
                // Gecikme sıfırsa sleep yok; task daha başlamadan iptal edilmiş olabilir (iki arama aynı anda geldi).
                try Task.checkCancellation()
                self?.output?.didStartSearching(query: query)

                // 4) Servis çağrısı: burada ana actor'den çıkılır, use case global executor'de çalışır.
                let books = try await search.execute(query: query)

                // 5) Ana actor'e dönüldü. Bu arada yeni bir arama başladıysa bu sonuç ESKİ: bildirme.
                try Task.checkCancellation()
                self?.output?.didFindBooks(books, for: query)

                // 6) Geçmişe yalnızca açık istekle yapılmış ve sonuç vermiş arama yazılır.
                guard isCommitted, !books.isEmpty else { return }
                let updated = await recentSearches.record(query)
                self?.output?.didLoadRecentSearches(updated)
            } catch is CancellationError {
                // Sessizce yut: Kullanıcı yeni bir şey yazdı ya da ekran kapandı. Bu bir hata değil.
            } catch _ where Task.isCancelled {
                // İptal edilmiş aramanın HATASI da bildirilmez (5. adımdaki kuralın hata tarafı). Gerçek ağda iptal
                // `URLError(.cancelled)` olarak gelir; servis iptalden hemen önce gerçek bir hata da vermiş olabilir.
                // İkisi de artık ESKİ aramaya ait; bildirseydik yeni aramanın ekranını ezerdi.
            } catch let error as SearchQueryError {
                self?.output?.didRejectQuery(error)
            } catch {
                self?.output?.didFailSearch(error, query: query)
            }
        }
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }

    func rememberSearch(_ query: String) {
        let recentSearches = useCases.recentSearches
        Task { [weak self] in
            let updated = await recentSearches.record(query)
            self?.output?.didLoadRecentSearches(updated)
        }
    }

    func loadInsights(for book: Book) {
        insightsTask?.cancel()
        let insights = useCases.insights
        insightsTask = Task { [weak self] in
            do {
                let result = try await insights.execute(for: book)
                try Task.checkCancellation()
                self?.output?.didLoadInsights(result)
            } catch is CancellationError {
                // Yeni bir özet istendi ya da ekran kapandı.
            } catch _ where Task.isCancelled {
                // Aynı kural: iptal edilmiş isteğin hatası da bildirilmez (ör. `URLError(.cancelled)`). Yoksa yeni özetin
                // alert'iyle aynı anda bir "Özet yüklenemedi" alert'i açılmaya çalışırdı.
            } catch {
                self?.output?.didFailInsights(error, for: book)
            }
        }
    }

    /// Favori bir **komut**: İptal etmiyoruz ve task'ı saklamıyoruz. Kullanıcı "favorile" dedi; ekran kapansa bile işlem
    /// tamamlanmalı (Okuma Notları'ndaki "kaydet" ile aynı karar). Task kısa ömürlü ve `self`'i yalnızca weak tutar.
    func toggleFavorite(for book: Book) {
        let toggleFavorite = useCases.toggleFavorite
        Task { [weak self] in
            let isFavorite = await toggleFavorite.execute(bookID: book.id)
            self?.output?.didToggleFavorite(book, isFavorite: isFavorite)
        }
    }
}
