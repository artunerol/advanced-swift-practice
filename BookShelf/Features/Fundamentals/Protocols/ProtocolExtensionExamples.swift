import Foundation

// "Protocol + extension" demosunun (ProtocolExtensionDemoView) arkasındaki saf mantık. SwiftUI içermez; birim testlerle
// doğrulanır. Protocol'ün kendisi (ReadingItem, PagedReadingItem) ve varsayılanlar ReadingItem.swift'te.

// MARK: - 1. Dispatch: aynı değer, üç farklı derleme anı tipi

/// Değişkenin **derleme anındaki** tipi. Dispatch tuzağının tek değişkeni budur: Değer hep aynı dergi.
enum DispatchViewpoint: CaseIterable, Identifiable, Sendable {
    /// `let item: Magazine` → derleyici somut tipi biliyor.
    case concrete
    /// `let item: any ReadingItem` → derleyici yalnızca protocol'ü biliyor (existential kutu).
    case existential
    /// `func read(_ item: some ReadingItem)` → generic; içeride bilinen tek şey yine protocol.
    case generic

    var id: Self { self }

    /// Seçicideki kısa etiket.
    var label: String {
        switch self {
        case .concrete: "Magazine"
        case .existential: "any"
        case .generic: "some"
        }
    }

    /// Ekranda gösterilen kod satırı.
    var declaration: String {
        switch self {
        case .concrete: "let item: Magazine = magazine"
        case .existential: "let item: any ReadingItem = magazine"
        case .generic: "func read(_ item: some ReadingItem)"
        }
    }
}

/// Bir bakış açısından okunan iki üyenin sonucu.
struct DispatchObservation: Equatable, Sendable {
    /// `symbolName`: protocol **gereksinimi** → dinamik dispatch, her zaman `Magazine`'in kendi değeri.
    let requirement: String
    /// `shelfSection`: yalnızca **extension**'da → statik dispatch, derleme anındaki tipe göre seçilir.
    let extensionOnly: String
}

extension ProtocolDispatchDemo {
    /// Aynı `magazine` değerini verilen bakış açısıyla okur.
    ///
    /// Üç dalda da çalışan kod BİREBİR aynı (`item.symbolName`, `item.shelfSection`); değişen tek şey `item`'ın
    /// derleme anındaki tipi. Sonucun yine de değişmesi, extension'a özel üyelerin statik dispatch edildiğinin kanıtı.
    static func observe(from viewpoint: DispatchViewpoint) -> DispatchObservation {
        switch viewpoint {
        case .concrete:
            let item: Magazine = magazine
            return DispatchObservation(requirement: item.symbolName, extensionOnly: item.shelfSection)
        case .existential:
            let item: any ReadingItem = magazine
            return DispatchObservation(requirement: item.symbolName, extensionOnly: item.shelfSection)
        case .generic:
            return read(magazine)
        }
    }

    private static func read(_ item: some ReadingItem) -> DispatchObservation {
        DispatchObservation(requirement: item.symbolName, extensionOnly: item.shelfSection)
    }
}

// MARK: - 2. Varsayılan uygulamalar, protocol kalıtımı, retroactive conformance

/// "Varsayılan" bölümündeki bir satır: bir tipin `ReadingItem` üyeleri NEREDEN geliyor?
///
/// Değerler (`symbolName`, `estimatedMinutes`) gerçek örneklerden okunur; "nereden geldiği" açıklaması ise elle
/// yazılmıştır (çalışma anında "bu değer varsayılandan mı geldi?" diye sormanın bir yolu yok; zaten amaç bu:
/// Çağıran fark etmez, tip ister kendi yazar ister varsayılanı kullanır).
struct ConformanceSummary: Identifiable, Sendable {
    /// Tip adı: "Novel", "Magazine", "AudioBook", "Book".
    let id: String
    /// Uygunluğun yazıldığı yer, ör. "struct Novel: PagedReadingItem".
    let declaration: String
    let symbolName: String
    let symbolSource: String
    let minutes: Int
    let minutesSource: String
}

enum ProtocolDefaultsDemo {
    static let summaries: [ConformanceSummary] = {
        let novel = ReadingSamples.shelfNovels[0]
        let magazine = ProtocolDispatchDemo.magazine
        let audioBook = AudioBook(title: "Çalıkuşu", narrator: "Gönüllü seslendirme", durationMinutes: 840)
        let book = Book(
            id: 2,
            title: "Kürk Mantolu Madonna",
            author: "Sabahattin Ali",
            year: 1943,
            isbn: "978-605-000-002-3",
            pageCount: 160,
            summary: ""
        )

        return [
            ConformanceSummary(
                id: "Novel",
                declaration: "struct Novel: PagedReadingItem",
                symbolName: novel.symbolName,
                symbolSource: "varsayılan (extension ReadingItem)",
                minutes: novel.estimatedMinutes,
                minutesSource: "PagedReadingItem varsayılanı: sayfa × 1,5"
            ),
            ConformanceSummary(
                id: "Magazine",
                declaration: "struct Magazine: ReadingItem",
                symbolName: magazine.symbolName,
                symbolSource: "kendi uygulaması (gereksinimi özelleştiriyor)",
                minutes: magazine.estimatedMinutes,
                minutesSource: "kendi uygulaması: makale × 8"
            ),
            ConformanceSummary(
                id: "AudioBook",
                declaration: "final class AudioBook: ReadingItem",
                symbolName: audioBook.symbolName,
                symbolSource: "kendi uygulaması",
                minutes: audioBook.estimatedMinutes,
                minutesSource: "kendi uygulaması: kayıt süresi"
            ),
            ConformanceSummary(
                id: "Book",
                declaration: "extension Book: PagedReadingItem (retroactive)",
                symbolName: book.symbolName,
                symbolSource: "varsayılan; Book'un kaynağına hiç dokunulmadı",
                minutes: book.estimatedMinutes,
                minutesSource: "PagedReadingItem varsayılanı: sayfa × 1,5"
            ),
        ]
    }()
}

// MARK: - 3. Koşullu (constrained) extension

/// Yalnızca elemanları **sayfalı** olan dizilerde var olan bir üye.
///
/// `where Element: PagedReadingItem` bir koşul: `[Novel]` ve `[Book]` bu üyeyi alır, `[Magazine]` almaz (dergi
/// sayfalı değil), `[any ReadingItem]` da almaz (kutunun kendisi protocol'e uymaz). Bu iki durumda
/// `items.totalPageCount` yazmak "derleme hatası" olur; çalışma anında bir kontrol yapılmaz.
///
/// Aynı fikir `Shelf.sortedItems`'ta da var: `extension Shelf where Item: Comparable` (Shelf.swift).
extension Sequence where Element: PagedReadingItem {
    var totalPageCount: Int {
        reduce(0) { total, item in total + item.pageCount }
    }
}

enum ConstrainedExtensionDemo {
    /// `[Novel]` → toplam sayfa (192 + 240 + 420).
    static var novelPages: Int {
        ReadingSamples.shelfNovels.totalPageCount
    }

    /// `ReadingShelf<Novel>` için `sortedItems` (Item: Comparable) ile başlığa göre ilk roman.
    static var firstNovelOnSortedShelf: String? {
        ReadingShelf(items: ReadingSamples.shelfNovels).sortedItems.first?.title
    }
}
