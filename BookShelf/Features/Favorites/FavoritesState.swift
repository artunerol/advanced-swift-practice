import Foundation

/// Favoriler ekranının o an **ne** göstermesi gerektiğini anlatan değer tipi.
///
/// Neden ayrı bir tip? ("Massive View Controller" sorunu)
/// UIKit'te her şeyi `UIViewController`'ın içine yazmak çok kolaydır: veri yükleme, filtreleme, biçimlendirme,
/// hata yönetimi, navigasyon... Sonunda binlerce satırlık, test edilmesi zor bir sınıf çıkar. Buna şaka yollu
/// *Massive View Controller* denir. Çözüm: UIKit'e bağımlı olmayan mantığı küçük, **saf** (pure) tiplere çıkarmak.
///
/// Bu tip:
/// - `UIKit` import etmez. Testlerde view controller kurmadan, bekleme olmadan test edilir.
/// - `enum` ile **birbirini dışlayan** durumları modeller: ekran aynı anda hem "yükleniyor" hem "hata" olamaz.
///   Aynı şeyi `isLoading: Bool`, `errorMessage: String?`, `books: [Book]` gibi ayrı alanlarla yapsaydık
///   `isLoading == true && errorMessage != nil` gibi **anlamsız kombinasyonlar** yazılabilir olurdu.
/// - View controller bu durumu yalnızca `render(_:)` ile ekrana yansıtır. Bu, UIKit'in emredici (imperative)
///   dünyasında SwiftUI'ın "durum → arayüz" (declarative) fikrini taklit etmenin basit bir yoludur.
///
/// `Equatable` testlerde `XCTAssertEqual(state, .loaded([...]))` yazabilmek için. Tüm yükler (`[Book]`, `String`)
/// `Sendable` olduğu için tip de otomatik olarak `Sendable`'dır.
enum FavoritesState: Equatable {
    /// Kitap kataloğu henüz yüklenmedi.
    case loading
    /// Gösterilecek favori kitaplar. Dizi boşsa ekran "henüz favorin yok" mesajını gösterir.
    case loaded([Book])
    /// Katalog yüklenemedi; kullanıcıya gösterilecek mesaj.
    case failed(message: String)

    /// Tüm kitaplar (katalog) ve favori id'lerinden ekran durumunu üretir.
    ///
    /// Neden satırları kataloğun sırasıyla üretiyoruz?
    /// `Set`'in **sırası yoktur**. Üstelik Swift her süreç (process) başlangıcında hash tohumunu (seed) rastgele
    /// seçtiği için aynı `Set`'i dolaşma sırası bir çalıştırmadan diğerine değişebilir. Satırları `favoriteIDs`
    /// üzerinden dolaşarak üretseydik, favoriler her değiştiğinde satırlar yer değiştirebilirdi.
    /// Bir `Array`'i `filter` ile süzmek ise elemanların göreli sırasını korur (kararlıdır / *stable*).
    ///
    /// Katalogda karşılığı olmayan id'ler (ör. silinmiş bir kitap) sessizce yok sayılır.
    static func from(catalog: [Book], favoriteIDs: Set<Book.ID>) -> FavoritesState {
        .loaded(catalog.filter { favoriteIDs.contains($0.id) })
    }

    /// Tabloda gösterilecek kitaplar. Yükleme ve hata durumlarında tablo boştur.
    var books: [Book] {
        if case .loaded(let books) = self { books } else { [] }
    }

    /// Katalog yüklendi mi? (Boş bir favori listesi de "yüklendi" sayılır.)
    var isLoaded: Bool {
        if case .loaded = self { true } else { false }
    }

    var isLoading: Bool {
        self == .loading
    }

    /// "Henüz favori kitabın yok" mesajı yalnızca yükleme BAŞARIYLA bitti ve liste boşsa görünür.
    /// Yüklenirken göstermek yanıltıcı olurdu: belki favorin vardır ama henüz gelmemiştir.
    var showsEmptyMessage: Bool {
        isLoaded && books.isEmpty
    }

    var errorMessage: String? {
        if case .failed(let message) = self { message } else { nil }
    }

    /// "Tümünü temizle" yalnızca temizlenecek bir şey varken etkin olur.
    var canClearAll: Bool {
        !books.isEmpty
    }
}
