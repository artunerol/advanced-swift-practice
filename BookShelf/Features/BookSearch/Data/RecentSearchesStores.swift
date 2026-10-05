import Foundation

/// **Data katmanı:** `RecentSearchesStore`'un UserDefaults uygulaması. Uygulama bunu kullanır.
///
/// Neden UserDefaults? Beş kısa metin = küçük bir kullanıcı tercihi; tam olarak UserDefaults'un işi.
/// (Büyüyen ya da hassas veri için uygun değildir; bkz. docs/14-kalicilik.md.)
///
/// Neden `actor`? İki sebep:
/// 1. `update(_:)`'in oku → değiştir → yaz adımları atomik olmalı. Actor içinde, arada `await` olmadan çalışırlar.
/// 2. `UserDefaults` Swift 6'da `Sendable` değil (SDK işaretlemiyor). Sendable bir struct onu alan olarak tutamazdı
///    (`PersistenceLocation` bu yüzden yalnızca suite **adını** saklıyor). Actor ise Sendable olmayan bir değeri kendi
///    izole durumunda güvenle tutabilir: ona yalnızca actor'ün içinden, sırayla erişilir.
///
/// **Enjekte edilebilir suite:** `suiteName` `nil` ise `.standard`. Uygulama `PersistenceLocation.current`'in suite'ini
/// verir (UI testlerinde her açılışta sıfırlanan ayrı bir alan); birim testleri kendi geçici suite'ini verir ve siler.
actor UserDefaultsRecentSearchesStore: RecentSearchesStore {
    /// Kayıt anahtarı. Ad alanı (`bookSearch.`) başka özelliklerin anahtarlarıyla çakışmayı önler.
    static let storageKey = "bookSearch.recentQueries"

    private let defaults: UserDefaults

    init(suiteName: String? = nil) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    func load() -> [String] {
        defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    @discardableResult
    func update(_ transform: @Sendable ([String]) -> [String]) -> [String] {
        let updated = transform(load())
        defaults.set(updated, forKey: Self.storageKey)
        return updated
    }
}

/// **Data katmanı:** Bellekte tutan uygulama. Uygulama kapanınca unutulur.
///
/// Birim testlerinde **fake** olarak kullanılır: gerçekten çalışan ama basitleştirilmiş bir depo (disk yok, temizlik yok).
/// `RecentSearchesUseCase` testleri kuralı bununla, gerçek bir depo üzerinden doğrular.
actor InMemoryRecentSearchesStore: RecentSearchesStore {
    private var queries: [String]

    init(queries: [String] = []) {
        self.queries = queries
    }

    func load() -> [String] {
        queries
    }

    @discardableResult
    func update(_ transform: @Sendable ([String]) -> [String]) -> [String] {
        queries = transform(queries)
        return queries
    }
}
