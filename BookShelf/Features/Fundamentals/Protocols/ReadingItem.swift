import Foundation

/// Okunabilen (ya da dinlenebilen) her şeyin ortak **sözleşmesi**.
///
/// Protocol bir tipin *ne yapabildiğini* söyler, *nasıl* yaptığını değil. Roman, dergi, sesli kitap ve
/// Core'daki `Book` birbirinden çok farklı tipler (üçü struct, biri class) ama hepsi bu sözleşmeye uyar ve
/// böylece aynı listede, aynı kodla işlenebilir.
///
/// Neden `: Sendable`? Protokole uyan **her** tipin thread'ler arasında güvenle taşınabilir olmasını şart koşar.
/// - Struct'lar için bu genelde bedavadır: Tüm alanları `Sendable` ise derleyici kabul eder.
/// - Class'lar için zordur: Yalnızca `final` ve tüm alanları `let` + `Sendable` olan bir class uyabilir
///   (bkz. `AudioBook`). Bu şart sayesinde `[any ReadingItem]` de `Sendable` olur ve `static let` ile saklanabilir.
protocol ReadingItem: Sendable {
    /// Başlık. `Book`'taki `let title: String` bu gereksinimi olduğu gibi karşılar.
    /// `{ get }`: "En az okunabilir olsun" demek; `let`, `var` ya da hesaplanan (computed) özellik olabilir.
    var title: String { get }

    /// Tahmini okuma/dinleme süresi (dakika).
    var estimatedMinutes: Int { get }

    /// Kullanıcıya gösterilen tür adı ("Roman", "Dergi"...). Varsayılanı YOK: Her tip bunu kendisi yazmak zorunda.
    var kindName: String { get }

    /// Liste satırındaki SF Symbol adı.
    ///
    /// Bu bir **gereksinim** (requirement) ve aşağıdaki extension'da varsayılan bir değeri var.
    /// Gereksinim olduğu için bir **özelleştirme noktasıdır** (customization point): Uyan tip kendi değerini yazarsa,
    /// değer `any ReadingItem` ya da generic bir fonksiyon üzerinden okunduğunda bile tipin kendi değeri kullanılır
    /// (dinamik dispatch, "witness table" üzerinden).
    var symbolName: String { get }
}

extension ReadingItem {
    /// `symbolName` gereksiniminin **varsayılan uygulaması**. `AudioBook` ve `Magazine` kendi değerlerini yazar;
    /// `Novel` ve `Book` bu varsayılanı kullanır.
    var symbolName: String { "book.closed" }

    /// Sadece extension'da tanımlı: **gereksinim DEĞİL**.
    ///
    /// Bu yüzden **statik dispatch** ile çağrılır: Hangi uygulamanın çalışacağına derleyici, değişkenin
    /// *derleme anındaki* tipine bakarak karar verir. Bir tip aynı isimde bir özellik yazarsa bu onu
    /// **gölgeler (shadow)**, ezmez (override etmez). Örnek için `Magazine.shelfSection`'a ve
    /// `ProtocolDispatchDemo`'ya bak. Özelleştirilmesini istediğin bir şeyi mutlaka gereksinim olarak tanımla.
    var shelfSection: String { "Genel raf" }

    /// Süreyi insan dostu biçimde yazar: "45 dk", "4 sa", "4 sa 48 dk".
    ///
    /// Bu da extension'a özel bir yardımcıdır ama burada sorun yok: Hiçbir tipin bunu özelleştirmesi
    /// beklenmiyor. Protocol extension'ları, uyan tüm tiplere **bedava davranış** eklemenin yoludur.
    var formattedDuration: String {
        formattedReadingDuration(minutes: estimatedMinutes)
    }
}

/// Dakika sayısını "45 dk", "4 sa", "4 sa 48 dk" biçiminde yazar.
///
/// Ayrı bir fonksiyon, çünkü toplam süre gibi bir öğeye ait olmayan dakikaları da biçimlendirmemiz gerekiyor.
/// (Sırf bu yardımcıyı kullanmak için sahte bir `ReadingItem` tipi yazmak, protocol'ü amacı dışında kullanmak olurdu.)
func formattedReadingDuration(minutes totalMinutes: Int) -> String {
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return switch (hours, minutes) {
    case (0, _): "\(minutes) dk"
    case (_, 0): "\(hours) sa"
    default: "\(hours) sa \(minutes) dk"
    }
}

/// Sayfalardan oluşan okunabilir şeyler. `ReadingItem`'ı **miras alan** (refine eden) bir protocol.
///
/// Buna uyan bir tip otomatik olarak `ReadingItem`'a da uymuş olur. Ek olarak `pageCount` ister ve karşılığında
/// `estimatedMinutes` için bir varsayılan verir. Yani bir üst protokolün gereksinimi, alt protokolün
/// extension'ındaki varsayılanla karşılanabilir.
protocol PagedReadingItem: ReadingItem {
    var pageCount: Int { get }
}

extension PagedReadingItem {
    /// Saatte 40 sayfa, yani sayfa başına 1,5 dakika (tam sayıya aşağı yuvarlanır).
    /// Objective-C tarafındaki `ReadingTimeEstimator`'ın varsayılan hızıyla aynı.
    var estimatedMinutes: Int { pageCount * 3 / 2 }
}

// MARK: - Toplam süre: generic mi, existential mı?

/// **Generic** sürüm. `Item` derleme anında tek, somut bir tiptir (ör. `[Novel]` için `Item == Novel`).
///
/// - Derleyici bu fonksiyonu her somut tip için özelleştirebilir (specialization); çağrılar doğrudan yapılır.
/// - Dizideki tüm elemanlar **aynı** tipte olmak zorundadır.
/// - `[any ReadingItem]` ile çağrılamaz: "type 'any ReadingItem' cannot conform to 'ReadingItem'".
///   Kutunun (existential) kendisi protokole uymaz; generic'e somut bir tip lazım.
///
/// Aynı imza `some` ile de yazılabilir: `func totalReadingMinutes(of items: [some ReadingItem]) -> Int`.
func totalReadingMinutes<Item: ReadingItem>(of items: [Item]) -> Int {
    items.reduce(0) { total, item in total + item.estimatedMinutes }
}

/// **Existential** sürüm. Her eleman `any ReadingItem` adında bir "kutu"; içindeki tip elemandan elemana değişebilir.
///
/// - Farklı tipleri tek bir dizide tutmanın (heterojen koleksiyon) yolu budur.
/// - Bedeli: Her erişimde kutu açılır ve çağrı çalışma anında (dinamik) çözülür; derleyici özelleştiremez.
///   Küçük listelerde fark edilmez, ama varsayılan tercih `some`/generic olmalı.
func totalReadingMinutes(ofMixed items: [any ReadingItem]) -> Int {
    items.reduce(0) { total, item in total + item.estimatedMinutes }
}

/// Tek bir öğe için özet satırı. Parametre `some ReadingItem`: "Bir tip olacak ama hangisi olduğu çağırana kalmış."
///
/// `any ReadingItem` tipinde bir değerle de çağrılabilir: Swift 5.7'den beri kutu otomatik açılır
/// (*implicit existential opening*) ve içindeki somut tip `some` parametresine verilir.
/// (Bu açma işlemi tek değerlerde çalışır; `[any ReadingItem]` dizisi `[some ReadingItem]`'a dönüşmez.)
func readingSummary(for item: some ReadingItem) -> String {
    "\(item.title) · \(item.kindName) · \(item.formattedDuration)"
}

// MARK: - Statik / dinamik dispatch tuzağı

/// Aynı `Magazine` değerini üç farklı "gözle" okuyup `shelfSection` ve `symbolName` sonuçlarını karşılaştırır.
///
/// - `shelfSection` extension'a özel → derleme anındaki tipe göre seçilir:
///   `Magazine` olarak "Süreli yayınlar", `any ReadingItem` veya generic olarak "Genel raf".
/// - `symbolName` gereksinim → her durumda `Magazine`'in kendi değeri: "newspaper".
enum ProtocolDispatchDemo {
    static let magazine = Magazine(title: "Edebiyat Gündemi", issueNumber: 42, articleCount: 6)

    /// Derleme anındaki tip `Magazine` → `Magazine.shelfSection` çağrılır.
    static var viaConcreteType: String {
        magazine.shelfSection
    }

    /// Derleme anındaki tip `any ReadingItem` → derleyici yalnızca protokolü bilir ve extension'daki
    /// uygulamayı seçer. `Magazine`'in kendi `shelfSection`'ı hiç çağrılmaz.
    static var viaExistential: String {
        let item: any ReadingItem = magazine
        return item.shelfSection
    }

    /// Generic fonksiyon içinde de aynısı olur: `T` hakkında bilinen tek şey `ReadingItem` olduğu.
    static var viaGeneric: String {
        shelfSection(of: magazine)
    }

    /// Gereksinim olan `symbolName` ise kutunun içindeki tipe göre (dinamik) seçilir.
    static var requirementViaExistential: String {
        let item: any ReadingItem = magazine
        return item.symbolName
    }

    private static func shelfSection(of item: some ReadingItem) -> String {
        item.shelfSection
    }
}
