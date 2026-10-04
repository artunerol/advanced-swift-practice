import Foundation

/// `typealias` örnekleri. Tek cümlelik özet: **typealias var olan bir tipe ikinci bir isim verir, yeni bir tip
/// oluşturmaz.** Derleyici için `BookID` ile `Int` birebir aynı şeydir; çalışma anında alias hiç yoktur.
///
/// Hepsi bu enum'un İÇİNDE tanımlı (iç içe typealias). Neden? `BookID` gibi kısa, genel isimleri tüm modüle
/// yaymamak için. Kullanımı: `TypealiasExamples.BookID`. Aynı tekniği dosya içinde `private typealias ID = ...` ile
/// de görebilirsin (ör. `StructVsClassView`): uzun bir iç içe tip adı yalnızca o dosyada kısaltılır.
enum TypealiasExamples {

    // MARK: - 1. Closure tipine isim vermek

    /// Bir kitabın sonuca girip girmeyeceğine karar veren süzgeç.
    ///
    /// Alias olmasaydı her imzada `@Sendable (Book) -> Bool` yazardık; isim, closure'ın NE İŞE YARADIĞINI da anlatır.
    /// (`@Sendable`: Süzgeçler `static let` içinde saklanıyor; Swift 6'da global sabitlerin `Sendable` olması gerekir.)
    typealias BookFilter = @Sendable (Book) -> Bool

    struct NamedFilter: Identifiable, Sendable {
        /// Seçicide görünen ad.
        let id: String
        let matches: BookFilter
    }

    static let filters: [NamedFilter] = [
        NamedFilter(id: "Tümü") { _ in true },
        NamedFilter(id: "< 200 sayfa") { $0.pageCount < 200 },
        NamedFilter(id: "1950 öncesi") { $0.year < 1950 },
    ]

    static func titles(of books: [Book], matching filter: BookFilter) -> [String] {
        books.filter(filter).map(\.title)
    }

    // MARK: - 2. Protocol birleşimine isim vermek

    /// "Hem okunabilir hem kimlikli" öğe. Apple'ın standart kütüphanedeki tanımı da tam olarak böyle:
    /// `public typealias Codable = Decodable & Encodable`.
    typealias ShelfItem = ReadingItem & Identifiable

    /// `<Item: ReadingItem & Identifiable>` yerine `<Item: ShelfItem>` yazabiliyoruz.
    static func identifiers<Item: ShelfItem>(of items: [Item]) -> [Item.ID] {
        items.map(\.id)
    }

    // MARK: - 3. Generic alias

    /// Kitap kimliğinden bir değere sözlük. `BookMap<Int>`, `[Int: Int]` ile aynı tiptir.
    typealias BookMap<Value> = [Book.ID: Value]

    static func pageCounts(of books: [Book]) -> BookMap<Int> {
        Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0.pageCount) })
    }

    // MARK: - 4. Tuzak: typealias yeni bir tip DEĞİL

    typealias BookID = Int
    typealias MemberID = Int

    /// Derlenir ve sessizce yanlıştır: Bir üye kimliği, kitap kimliğinin yerine geçti. Derleyici uyarmaz, çünkü
    /// ikisi de sadece `Int`. (Ayrıca `extension BookID { ... }` yazsaydın aslında TÜM `Int`'leri genişletirdin.)
    static func bookID(mistakenlyFrom member: MemberID) -> BookID {
        member
    }

    // MARK: - 5. Tip güvenliği gerekiyorsa: sarmalayıcı struct

    /// Ayrı bir TİP: `Int` beklenen yere verilemez, `Int` de bunun yerine geçemez. Karıştırmak derleme hatasıdır:
    /// `lookUpCard(42)` → "cannot convert value of type 'Int' to expected argument type 'LibraryCardNumber'".
    ///
    /// Bedeli yok denecek kadar azdır: Tek alanlı bir struct'ın bellekteki boyutu, içindeki tipinkiyle aynıdır (8 bayt).
    /// `RawRepresentable`: `rawValue` ile ham değere dönmenin standart yolu (enum'ların `rawValue`'su da budur).
    struct LibraryCardNumber: RawRepresentable, Hashable, Sendable {
        let rawValue: Int
    }

    static func cardLabel(for number: LibraryCardNumber) -> String {
        "Kart #\(number.rawValue)"
    }

    // MARK: - 6. associatedtype'ı typealias ile karşılamak

    /// `Shelf`'in `associatedtype Item`'ını burada AÇIKÇA `typealias Item = Novel` ile karşılıyoruz.
    ///
    /// Çoğu zaman buna gerek yoktur: Derleyici `add(_ item: Novel)` imzasından `Item == Novel` sonucunu kendisi
    /// çıkarır (`Book`'un `Identifiable.ID`'si de `let id: Int`'ten çıkarılır). Açık typealias okunabilirlik için ya da
    /// çıkarımın mümkün olmadığı durumlar için yazılır.
    struct ClassicsShelf: Shelf {
        typealias Item = Novel

        private(set) var items: [Item] = []

        @discardableResult
        mutating func add(_ item: Item) -> Bool {
            guard !items.contains(item) else { return false }
            items.append(item)
            return true
        }
    }

    // MARK: - Çalışma anında alias yok

    /// Bir tipin çalışma anındaki adı. Alias'lar burada görünmez: `typeName(of: BookID.self)` → "Int".
    static func typeName<T>(of type: T.Type) -> String {
        String(describing: type)
    }

    // MARK: - Örnek veri

    static let sampleBooks: [Book] = [
        Book(id: 1, title: "Tutunamayanlar", author: "Oğuz Atay", year: 1972, isbn: "", pageCount: 724, summary: ""),
        Book(id: 2, title: "Kürk Mantolu Madonna", author: "Sabahattin Ali", year: 1943, isbn: "", pageCount: 160, summary: ""),
        Book(id: 3, title: "Aylak Adam", author: "Yusuf Atılgan", year: 1959, isbn: "", pageCount: 192, summary: ""),
        Book(id: 4, title: "Çalıkuşu", author: "Reşat Nuri Güntekin", year: 1922, isbn: "", pageCount: 544, summary: ""),
    ]
}
