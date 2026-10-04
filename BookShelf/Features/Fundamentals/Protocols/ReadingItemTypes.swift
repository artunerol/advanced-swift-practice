import Foundation

// MARK: - Novel (struct)

/// Roman. `PagedReadingItem` sayesinde `estimatedMinutes` yazmasına gerek yok; `symbolName` için de varsayılanı kullanır.
///
/// Tek satırda birden fazla protocol'e uyuluyor. Her birinin buradaki anlamı:
/// - `Identifiable`: Rafın aynı romanı iki kez eklememesi için `id` ile karşılaştırıyoruz.
/// - `Hashable` (Equatable'ı da içerir): Tüm alanlar `Hashable`, derleyici `==` ve `hash(into:)`'u üretir.
/// - `Comparable`: `<` operatörünü yazınca `sorted()`, `min()`, `max()` bedavaya gelir.
/// - `CustomStringConvertible`: `"\(novel)"` ve `print(novel)` bu `description`'ı kullanır.
struct Novel: PagedReadingItem, Identifiable, Hashable, Comparable, CustomStringConvertible {
    let id: Int
    let title: String
    let author: String
    let pageCount: Int

    var kindName: String { "Roman" }

    var description: String {
        "\(title) (\(author), \(pageCount) sayfa)"
    }

    /// Önce başlığa (Türkçe alfabe kurallarıyla), eşitse yazara, o da eşitse sayfa sayısına göre sıralar.
    ///
    /// `Comparable` sözleşmesi, `<`'nun `==` ile tutarlı olmasını ister: İkisi de diğerinden küçük değilse
    /// eşit olmalılar. Sadece başlığa baksaydık, aynı başlıklı iki farklı roman bu kuralı bozardı.
    static func < (lhs: Novel, rhs: Novel) -> Bool {
        let byTitle = TurkishCollation.compare(lhs.title, rhs.title)
        if byTitle != .orderedSame { return byTitle == .orderedAscending }
        let byAuthor = TurkishCollation.compare(lhs.author, rhs.author)
        if byAuthor != .orderedSame { return byAuthor == .orderedAscending }
        return lhs.pageCount < rhs.pageCount
    }
}

// MARK: - Magazine (struct)

/// Dergi. Süresi sayfadan değil makale sayısından hesaplanır, bu yüzden `PagedReadingItem` değil.
struct Magazine: ReadingItem {
    let title: String
    let issueNumber: Int
    let articleCount: Int

    /// Makale başına ortalama 8 dakika.
    var estimatedMinutes: Int { articleCount * 8 }
    var kindName: String { "Dergi" }

    /// Gereksinimi özelleştiriyor → her yerden (any / generic) bu değer görünür.
    var symbolName: String { "newspaper" }

    /// DİKKAT, TUZAK: `shelfSection` protokolde gereksinim değil, sadece extension'da var.
    /// Bu özellik extension'dakini **gölgeler**, ezmez. Yalnızca derleme anındaki tip `Magazine` iken görünür;
    /// `any ReadingItem` ya da generic bir fonksiyon üzerinden okunduğunda "Genel raf" döner.
    var shelfSection: String { "Süreli yayınlar" }
}

// MARK: - AudioBook (final class)

/// Sesli kitap. Protocol'lere class'lar da uyabilir.
///
/// Neden `final` ve neden tüm alanlar `let`? `ReadingItem` `Sendable` istiyor. Derleyici bir class'ı ancak
/// alt sınıfı olamıyorsa (`final`) ve tüm alanları değişmez + `Sendable` ise `Sendable` kabul eder.
/// Tek bir `var` alan eklersen derleme hatası alırsın.
final class AudioBook: ReadingItem {
    let title: String
    let narrator: String
    let durationMinutes: Int

    init(title: String, narrator: String, durationMinutes: Int) {
        self.title = title
        self.narrator = narrator
        self.durationMinutes = durationMinutes
    }

    var estimatedMinutes: Int { durationMinutes }
    var kindName: String { "Sesli kitap" }
    var symbolName: String { "headphones" }
}

/// Class'lar `Equatable`'ı otomatik almaz; `==`'yu kendimiz yazarız.
/// Burada "eşitlik" içeriğe bakar. "Aynı nesne mi?" sorusu ise hâlâ `===` ile sorulur; ikisi farklı kavramlardır.
extension AudioBook: Equatable {
    static func == (lhs: AudioBook, rhs: AudioBook) -> Bool {
        lhs.title == rhs.title && lhs.narrator == rhs.narrator && lhs.durationMinutes == rhs.durationMinutes
    }
}

// MARK: - Book (Core) → retroactive conformance

/// Core'daki `Book` tipine dokunmadan, ona buradan yeni bir protocol uygunluğu ekliyoruz (*retroactive conformance*).
///
/// `title` ve `pageCount` zaten `Book`'ta var; `estimatedMinutes` `PagedReadingItem`'dan, `symbolName`
/// varsayılandan geliyor. Eksik olan tek şey `kindName`. Protocol'lerin gücü: Mevcut bir tipi, kaynak koduna
/// dokunmadan yeni bir sözleşmeye bağlayabiliyoruz.
///
/// Not: Aynı modüldeki bir tipe bunu yapmak tamamen güvenli. Başka bir modülün tipini başka bir modülün
/// protocol'üne uydurmak (ör. `extension Int: SomeLibraryProtocol`) ise çakışma riski taşır; Swift 6 bunun için
/// uyarı verir ve bilerek yaptığını `@retroactive` ile belirtmeni ister.
extension Book: PagedReadingItem {
    var kindName: String { "Kitap" }
}

// MARK: - Örnek veri

/// Ekranda ve testlerde kullanılan örnek içerik.
enum ReadingSamples {
    /// Rafa eklenecek romanlar (bu sırayla). Başlık sırası (Aylak, Sinekli, Yaban) ekleme sırasından farklı;
    /// böylece `Comparable` ile sıralamanın etkisi görülebiliyor.
    static let shelfNovels: [Novel] = [
        Novel(id: 101, title: "Aylak Adam", author: "Yusuf Atılgan", pageCount: 192),
        Novel(id: 102, title: "Yaban", author: "Yakup Kadri Karaosmanoğlu", pageCount: 240),
        Novel(id: 103, title: "Sinekli Bakkal", author: "Halide Edib Adıvar", pageCount: 420),
    ]

    /// Dört farklı tip, tek dizi: `[any ReadingItem]`. Generic bir `[T]` bunu tutamazdı.
    ///
    /// Başlığa göre: Aylak Adam, Çalıkuşu, Edebiyat Gündemi, Kürk Mantolu Madonna.
    /// Süreye göre: Edebiyat Gündemi (48), Kürk Mantolu Madonna (240), Aylak Adam (288), Çalıkuşu (840).
    static let mixedItems: [any ReadingItem] = [
        shelfNovels[0],
        ProtocolDispatchDemo.magazine,
        AudioBook(title: "Çalıkuşu", narrator: "Gönüllü seslendirme", durationMinutes: 840),
        Book(
            id: 2,
            title: "Kürk Mantolu Madonna",
            author: "Sabahattin Ali",
            year: 1943,
            isbn: "978-605-000-002-3",
            pageCount: 160,
            summary: "Raif Efendi'nin defterinden, Berlin'de tanıdığı Maria Puder'e duyduğu sessiz aşkın hikâyesi."
        ),
    ]

    /// **Opaque dönüş tipi** (`some`): Fonksiyon her zaman AYNI somut tipi döndürür (burada `Novel`) ama
    /// çağıran bunu bilmez, sadece "bir `ReadingItem`" olduğunu bilir. Derleyici ise gerçek tipi bilir ve
    /// optimize edebilir. SwiftUI'daki `var body: some View` de tam olarak budur.
    /// (Bir dalda `Novel`, diğerinde `Magazine` döndürmeye çalışsaydık derlenmezdi; o durumda `any` gerekir.)
    static func featuredItem() -> some ReadingItem {
        shelfNovels[0]
    }
}

// MARK: - Sıralama

/// Karışık listenin sıralama seçenekleri.
enum ReadingSortOrder: CaseIterable, Identifiable, Sendable {
    case title
    case duration

    var id: Self { self }

    /// Seçicideki görünen etiket. UI testleri aynı sabitle segmenti bulur.
    var label: String {
        switch self {
        case .title: AccessibilityID.Fundamentals.Protocols.sortByTitleLabel
        case .duration: AccessibilityID.Fundamentals.Protocols.sortByDurationLabel
        }
    }

    /// Heterojen listeyi sıralar. `any ReadingItem` üzerinde yalnızca protokolün sunduğu özellikleri
    /// (`title`, `estimatedMinutes`) kullanabiliriz; bu yeterli.
    func sorted(_ items: [any ReadingItem]) -> [any ReadingItem] {
        items.sorted { lhs, rhs in
            switch self {
            case .title:
                TurkishCollation.compare(lhs.title, rhs.title) == .orderedAscending
            case .duration:
                // Süreler eşitse başlığa göre sırala; böylece sonuç her zaman aynı olur (deterministik).
                if lhs.estimatedMinutes != rhs.estimatedMinutes {
                    lhs.estimatedMinutes < rhs.estimatedMinutes
                } else {
                    TurkishCollation.compare(lhs.title, rhs.title) == .orderedAscending
                }
            }
        }
    }
}

/// Türkçe alfabe sırasıyla metin karşılaştırma (Ç, C'den sonra; İ, I'dan sonra gelir).
///
/// Yerel ayarı (locale) açıkça veriyoruz: Cihazın diline bağlı olsaydı aynı liste İngilizce bir
/// simülatörde farklı sıralanabilir, testler de makineden makineye farklı sonuç verebilirdi.
enum TurkishCollation {
    static let locale = Locale(identifier: "tr_TR")

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, locale: locale)
    }
}
