import Foundation

/// Favori kitapların id'lerini tutan **actor**.
///
/// Problem: Favoriler hem SwiftUI detay ekranından hem UIKit favoriler ekranından okunup yazılıyor.
/// Birden çok yerden aynı anda değiştirilen bir `Set` = **paylaşılan değiştirilebilir durum** (shared mutable state).
/// Bunu kilitsiz, sıradan bir `class` ile yapsaydık iki thread aynı anda `insert` çağırdığında *data race* oluşurdu.
///
/// Çözüm: `actor`.
/// - Actor, kendi durumuna (`favoriteIDs`, `observers`) aynı anda **yalnızca bir** görevin erişmesine izin verir.
///   İçeride bir "posta kutusu" (serial executor) varmış gibi düşünebilirsin: istekler sırayla işlenir.
/// - Dışarıdan her erişim `await` gerektirir: `await store.toggle(id)`. Bu `await`, "sıra bana gelene kadar
///   beklemem gerekebilir" demektir.
/// - Actor içindeki kod (ör. `toggle`) ise `await` olmadan senkron çalışır; çünkü zaten actor'ün içindedir.
/// - Actor'ler bir referans tipidir (class gibi) ve otomatik olarak `Sendable`'dır.
actor FavoritesStore {
    private var favoriteIDs: Set<Book.ID>
    /// Değişiklikleri dinleyenler. Her dinleyicinin bir `AsyncStream` devamı (continuation) var.
    private var observers: [UUID: AsyncStream<Set<Book.ID>>.Continuation] = [:]

    init(initialFavorites: Set<Book.ID> = []) {
        favoriteIDs = initialFavorites
    }

    /// Tüm favori id'leri. Dışarıdan okumak için bile `await store.allIDs` yazmak gerekir.
    var allIDs: Set<Book.ID> {
        favoriteIDs
    }

    func contains(_ bookID: Book.ID) -> Bool {
        favoriteIDs.contains(bookID)
    }

    /// Favori durumunu tersine çevirir ve **yeni** durumu döndürür (`true` = artık favori).
    ///
    /// Dikkat: "oku → karar ver → yaz" adımlarının hepsi actor içinde, arada `await` OLMADAN yapılıyor.
    /// Bu sayede işlem *atomik*tir; iki ekran aynı anda toggle etse bile durum tutarlı kalır.
    @discardableResult
    func toggle(_ bookID: Book.ID) -> Bool {
        if favoriteIDs.contains(bookID) {
            favoriteIDs.remove(bookID)
        } else {
            favoriteIDs.insert(bookID)
        }
        notifyObservers()
        return favoriteIDs.contains(bookID)
    }

    func add(_ bookID: Book.ID) {
        guard favoriteIDs.insert(bookID).inserted else { return }
        notifyObservers()
    }

    func remove(_ bookID: Book.ID) {
        guard favoriteIDs.remove(bookID) != nil else { return }
        notifyObservers()
    }

    /// Favori listesindeki değişiklikleri dinlemek için bir `AsyncStream` döndürür.
    ///
    /// Kullanım: `for await ids in await store.changes() { ... }`
    /// - Akış, abone olunduğu anda mevcut durumu hemen bir kez yayınlar; sonra her değişiklikte yeni kümeyi yayınlar.
    /// - `bufferingNewest(1)`: Dinleyici yavaş kalırsa sadece EN SON durumu saklarız; ara durumlar önemli değil.
    /// - Dinleyen task iptal edilince (`Task.cancel()`) `onTermination` çağrılır ve dinleyiciyi temizleriz.
    func changes() -> AsyncStream<Set<Book.ID>> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Set<Book.ID>.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let observerID = UUID()
        observers[observerID] = continuation
        continuation.yield(favoriteIDs)

        // `onTermination` actor'ün DIŞINDA, herhangi bir thread'de çağrılabilir. Actor'ün durumuna
        // doğrudan dokunamayız; bu yüzden yeni bir Task açıp `await` ile actor'e geri "sıraya giriyoruz".
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(observerID) }
        }
        return stream
    }

    private func removeObserver(_ observerID: UUID) {
        observers[observerID] = nil
    }

    private func notifyObservers() {
        for continuation in observers.values {
            continuation.yield(favoriteIDs)
        }
    }
}
