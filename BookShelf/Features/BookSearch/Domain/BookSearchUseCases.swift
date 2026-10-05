import Foundation

/// Kitap arama özelliğinin dört use case'i: dört **farklı tür** use case yan yana.
///
/// | Use case                   | Türü                                   | Kural / politika                                   |
/// |----------------------------|----------------------------------------|----------------------------------------------------|
/// | `SearchBooksUseCase`       | Sorgu + iş kuralı (uzak servis)        | en az 2 harf, Türkçe katlama, önce başlık sıralaması |
/// | `LoadBookInsightsUseCase`  | Birleştirme (iki istek, `async let`)   | yorumlar zorunlu, yazar profili isteğe bağlı       |
/// | `ToggleFavoriteUseCase`    | Komut (paylaşılan durumda yan etki)    | yeni durumu döndür                                 |
/// | `RecentSearchesUseCase`    | Yerel depolama politikası              | en fazla 5, tekrar yok, en yeni başta              |
///
/// Hepsi `nonisolated` ve `Sendable` struct: UI'a dokunmazlar, bu yüzden ana actor'e ihtiyaçları yok. Bu projede
/// (Swift 6 dil modu, Approachable Concurrency kapalı) nonisolated `async` fonksiyonlar global concurrent executor'de
/// çalışır: `@MainActor` interactor `await useCase.execute(...)` dediğinde ana actor serbest kalır, iş arka planda
/// yapılır, sonuç ana actor'e geri döner. (Xcode 26'nın yeni proje şablonlarındaki "Default Actor Isolation = MainActor"
/// açık olsaydı bu struct'lar varsayılan olarak `@MainActor` sayılırdı; `nonisolated` ve `@concurrent` ile dışarı
/// çıkarmak gerekirdi. Ayrıntı: `BookSearchContracts.swift`.)
///
/// ## Neden burada use case'lerin protokolü VAR, Okuma Notları'nda YOK? (bilinçli fark)
///
/// Okuma Notları (`NotesUseCases`) somut struct'lar kullanır; tek test dikişi (seam) depodur (`NotesRepository`).
/// Interactor testleri gerçek use case'leri `InMemoryNotesRepository` ile çalıştırır. Kazancı: daha az dosya, daha az
/// dolaylılık ve testler gerçek kuralları da kapsar (sahte davranış gerçekten sapamaz).
///
/// Bu modülde interactor'ın asıl işi **zamanlama ve koordinasyon**: debounce, "son arama kazanır" iptali, hata ayrımı,
/// yalnızca başarılı aramayı geçmişe yazmak. Bunları test etmek için "birinci sorgu yavaş, ikinci hızlı" gibi
/// senaryoları **sorgu başına** kontrol edebilmek gerekir. Use case protokolü bu kontrolü verir: interactor testleri
/// spy use case'lerle (`BookSearchArchitectureDoubles`) kuralları hiç çalıştırmadan koordinasyonu doğrular; kurallar
/// ise kendi testlerinde (`BookSearchUseCaseTests`) `StubBookService` ile ayrıca doğrulanır.
///
/// Bedeli (trade-off): 4 protokol + 4 test double, bir dolaylılık katmanı daha ve "spy gerçek use case'ten farklı
/// davranırsa interactor testleri yanlış bir dünyada yeşil kalır" riski. Riski, use case testleri ve uçtan uca UI testi
/// (`BookSearchUITests`) azaltır. Kural: Soyutlama, testte **değiştirilmesi gereken** bir sınırda değerlidir.
struct BookSearchUseCases: Sendable {
    let search: any SearchBooksUseCaseProtocol
    let insights: any LoadBookInsightsUseCaseProtocol
    let toggleFavorite: any ToggleFavoriteUseCaseProtocol
    let recentSearches: any RecentSearchesUseCaseProtocol

    /// Testler her alanı ayrı bir double ile doldurur.
    init(
        search: any SearchBooksUseCaseProtocol,
        insights: any LoadBookInsightsUseCaseProtocol,
        toggleFavorite: any ToggleFavoriteUseCaseProtocol,
        recentSearches: any RecentSearchesUseCaseProtocol
    ) {
        self.search = search
        self.insights = insights
        self.toggleFavorite = toggleFavorite
        self.recentSearches = recentSearches
    }

    /// Uygulamanın gerçek use case'leri. Parametreler domain tipleri (servis protokolü, favori actor'ü, depo protokolü);
    /// hangi somut servisin verileceğine composition root karar verir (`BookSearchRouter.build`). Domain `AppDependencies`'i
    /// bilmez: bağımlılık oku içeri bakar.
    init(
        service: any BookServiceProtocol,
        favorites: FavoritesStore,
        recentSearchesStore: any RecentSearchesStore
    ) {
        self.init(
            search: SearchBooksUseCase(service: service),
            insights: LoadBookInsightsUseCase(service: service),
            toggleFavorite: ToggleFavoriteUseCase(store: favorites),
            recentSearches: RecentSearchesUseCase(store: recentSearchesStore)
        )
    }
}
