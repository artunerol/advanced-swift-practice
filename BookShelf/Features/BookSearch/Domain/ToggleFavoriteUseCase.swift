import Foundation

/// Favori komutunun sözleşmesi.
protocol ToggleFavoriteUseCaseProtocol: Sendable {
    /// Kitabın favori durumunu tersine çevirir ve **yeni** durumu döndürür (`true` = artık favori).
    func execute(bookID: Book.ID) async -> Bool
}

/// **Use case türü: Komut (command), paylaşılan durumda yan etki.** Bir şeyi *değiştirir*; okumak için değil, yapmak
/// için çağrılır. Sonuç olarak yeni durumu döndürür ki çağıran ikinci bir "şimdi ne durumda?" sorusu sormak zorunda kalmasın
/// (ikinci soru, araya başka bir ekranın değişikliği girerse yanlış cevap verebilirdi).
///
/// Neden use case? Kullanıcının niyeti ("bu kitabı favorile / çıkar") bir uygulama işlemidir; hangi depoda, nasıl
/// tutulduğu ayrıntıdır. Interactor yalnızca bu protokolü görür: testte bir spy verilir, gerçek actor gerekmez.
/// Yarın "en fazla 50 favori" ya da "favorilemek için giriş yap" kuralı gelirse eklenecek yer burası olur.
///
/// Dürüst not: Bugün tek satır. Asıl iş kuralı (oku → karar ver → yaz, arada `await` olmadan, yani atomik) zaten
/// `FavoritesStore.toggle(_:)`'ın içinde. Bu use case'in değeri politikada değil, **sınırda** (test dikişi + tek giriş noktası).
/// Neden presenter doğrudan actor'ü çağırmıyor? Presenter senkron ve UI'a yakın kalmalı; actor çağrısı `await` ister ve
/// paylaşılan durumu bilmek demektir. Bunlar interactor'ın (ve use case'in) işi.
///
/// Paylaşılan durum: Aynı `FavoritesStore` Kitaplar sekmesi, kitap detayı ve Favoriler (UIKit) ekranıyla ortak. Aramadan
/// favorilediğin kitap detay ekranında dolu kalple, Favoriler sekmesinde listede görünür.
struct ToggleFavoriteUseCase: ToggleFavoriteUseCaseProtocol {
    private let store: FavoritesStore

    init(store: FavoritesStore) {
        self.store = store
    }

    func execute(bookID: Book.ID) async -> Bool {
        await store.toggle(bookID)
    }
}
