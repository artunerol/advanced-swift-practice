import Foundation

/// **Domain → depo sözleşmesi.** Son aramaların nerede tutulduğunu soyutlar (DIP: protokolün sahibi domain).
/// Uygulamaları `Data/RecentSearchesStores.swift` içinde: UserDefaults (uygulama) ve bellek (testler, önizleme).
///
/// Bilerek "aptal": Kural bilmez, yalnızca bir `[String]` saklar. Kural (en fazla 5, tekrar yok, en yeni başta)
/// `RecentSearchesUseCase`'te.
protocol RecentSearchesStore: Sendable {
    /// Kayıtlı liste (kaydedildiği sırayla).
    func load() async -> [String]

    /// Listeyi **tek adımda** oku → değiştir → yaz ve yeni listeyi döndür.
    ///
    /// Neden `load` + `save` değil? İki ayrı çağrı arasında başka bir kayıt araya girebilir (ikisi de eski listeyi okur,
    /// biri diğerinin yazdığını ezer: "lost update"). Uygulamalar actor olduğu için `transform` actor'ün içinde, arada
    /// `await` olmadan çalışır; işlem atomiktir. `FavoritesStore.toggle(_:)` ile aynı fikir.
    @discardableResult
    func update(_ transform: @Sendable ([String]) -> [String]) async -> [String]
}

/// Son aramalar use case'inin sözleşmesi.
protocol RecentSearchesUseCaseProtocol: Sendable {
    /// Son aramalar, en yeni başta.
    func load() async -> [String]
    /// Sorguyu geçmişe ekler (politikaya göre) ve güncel listeyi döndürür.
    @discardableResult
    func record(_ query: String) async -> [String]
}

/// **Use case türü: Yerel depolama politikası.** "Neyi, ne kadar, hangi sırayla saklarız?" kararı.
///
/// Politika:
/// 1. Sorgu kırpılır; boş sorgu kaydedilmez.
/// 2. **Tekrar yok:** Aynı arama ikinci kez yapılırsa eskisi silinir, yenisi başa gelir. "Aynı" demek: arama anahtarı
///    aynı (`SearchBooksUseCase.searchKey(for:)`). Yani büyük/küçük harf (Türkçe kurallarıyla) ve aksan farkı yok
///    sayılır: "ATAY" ile "atay", "oğuz" ile "oguz" aynı aramadır, çünkü aynı sonucu verirler. Listede en son yazılan
///    biçim kalır.
/// 3. **En yeni başta, en fazla `limit` (5) kayıt.** Fazlası sondan (en eskiden) atılır.
///
/// Neden use case? Bu kurallar ne depoya aittir (UserDefaults ya da bellek, ikisi de aynı kuralı uygulamalı) ne de
/// presenter'a (ekran yalnızca listeyi gösterir). Depo değişse kural değişmez; kural değişse depo değişmez.
/// Kuralın kendisi saf bir fonksiyon (`applying(_:to:)`): depo olmadan, milisaniyede test edilir.
struct RecentSearchesUseCase: RecentSearchesUseCaseProtocol {
    static let limit = 5

    private let store: any RecentSearchesStore

    init(store: any RecentSearchesStore) {
        self.store = store
    }

    func load() async -> [String] {
        await store.load()
    }

    @discardableResult
    func record(_ query: String) async -> [String] {
        await store.update { existing in
            Self.applying(query, to: existing)
        }
    }

    /// Politikanın tamamı. Saf: aynı girdi → aynı çıktı.
    static func applying(_ rawQuery: String, to existing: [String]) -> [String] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return existing }
        let key = SearchBooksUseCase.searchKey(for: query)
        let others = existing.filter { SearchBooksUseCase.searchKey(for: $0) != key }
        return Array(([query] + others).prefix(limit))
    }
}
