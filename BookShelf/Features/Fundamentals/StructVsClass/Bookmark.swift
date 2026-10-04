import Foundation

// Aynı şeyi (bir kitap ayracını) iki farklı şekilde modelliyoruz. Tek fark: biri `struct`, diğeri `class`.
// Ekrandaki "Kopyalama" deneyi bu iki tipin `var copy = original` satırına verdiği farklı tepkiyi gösterir.

/// Ayraç — **değer tipi** (value type).
///
/// Değer semantiği: Bir değişkene atamak ya da fonksiyona geçirmek **bağımsız bir kopya** üretir.
/// `var copy = original` dedikten sonra `copy`'yi ne kadar değiştirsen de `original` etkilenmez.
///
/// - `Equatable`: Tüm alanları `Equatable` olduğu için derleyici `==`'yu kendisi üretir (synthesized).
///   Değer tiplerinde "eşitlik" = "içerik aynı mı?" sorusudur. Kimlik (`===`) kavramı yoktur.
/// - `Sendable`: Yalnızca `Int` taşıdığı için derleyici bu struct'ı **otomatik** olarak `Sendable` sayar
///   (modül içi tiplerde çıkarım yapılır). Kopyalandığı için iki thread aynı belleği paylaşmaz.
struct BookmarkValue: Equatable {
    var page: Int

    /// Struct'ın kendi alanını değiştiren metotlar `mutating` olmak zorundadır.
    ///
    /// Neden? Bir struct metodu içinde `self` varsayılan olarak **sabittir** (`let` gibi).
    /// `mutating`, "bu metot `self`'in yerine yeni bir değer yazar" demektir ve derleyici bunu yalnızca
    /// `var` ile tutulan değerler üzerinde çağırmana izin verir:
    ///
    ///     let fixed = BookmarkValue(page: 1)
    ///     fixed.advance(by: 5)   // HATA: derlenmez, 'fixed' bir 'let' sabiti
    mutating func advance(by pages: Int) {
        page += pages
    }
}

/// Ayraç — **referans tipi** (reference type).
///
/// Referans semantiği: Değişken nesnenin kendisini değil, **nesnenin adresini** (referansı) tutar.
/// `var copy = original` sadece adresi kopyalar; iki değişken **aynı** nesneyi gösterir.
/// Bu yüzden `copy` üzerinden yapılan değişiklik `original`'dan da görünür.
///
/// - `final`: Bu sınıftan alt sınıf türetilemez. Derleyici metot çağrılarını doğrudan (statik) yapabilir
///   ve "bir alt sınıf bu davranışı değiştirir mi?" sorusu ortadan kalkar. Kalıtıma ihtiyacın yoksa `final` yaz.
/// - `Sendable` DEĞİL: Değiştirilebilir (`var`) bir alanı olan sınıf, iki thread'den aynı anda
///   değiştirilebilir. Swift 6 böyle bir nesneyi başka bir actor'e/task'a ancak gönderen taraf ona bir daha
///   dokunmuyorsa gönderebilmene izin verir (region-based isolation); iki taraf da kullanmaya devam ederse derleme hatası verir.
/// - `Equatable` değil: Class'larda `==` otomatik üretilmez. Burada "aynı nesne mi?" sorusunu `===` ile soruyoruz.
final class BookmarkReference {
    var page: Int

    /// Class'lar struct'lar gibi otomatik "memberwise" başlatıcı almaz; `init`'i kendimiz yazarız.
    init(page: Int) {
        self.page = page
    }

    /// `mutating` YOK: Class metotları nesnenin alanlarını serbestçe değiştirebilir, çünkü değişen şey
    /// değişkenin tuttuğu referans değil, referansın gösterdiği nesnedir.
    func advance(by pages: Int) {
        self.page += pages
    }
}

/// "Kopyalama" deneyinin durumu. Ekran bunu `@State` içinde tutar.
///
/// Dikkat: Bu struct iki `BookmarkReference` (class) taşıyor. Yani kendisi **saf bir değer tipi değil**:
/// `CopySemanticsDemo`'nun bir kopyasını alırsan, `structOriginal`/`structCopy` kopyalanır ama class alanları
/// hâlâ AYNI nesneleri gösterir. (`AppDependencies` içindeki actor referansı da aynı şekilde davranır.)
/// Burada bu bilinçli bir tercih: amaç zaten iki semantiği yan yana göstermek.
struct CopySemanticsDemo {
    static let startPage = 10
    static let step = 10

    private(set) var structOriginal: BookmarkValue
    private(set) var structCopy: BookmarkValue
    let classOriginal: BookmarkReference
    let classCopy: BookmarkReference

    init(startPage: Int = CopySemanticsDemo.startPage) {
        let original = BookmarkValue(page: startPage)
        structOriginal = original
        structCopy = original          // `var copy = original` → içerik kopyalanır; iki ayrı değer.

        let reference = BookmarkReference(page: startPage)
        classOriginal = reference
        classCopy = reference          // `var copy = original` → sadece adres kopyalanır; tek nesne.
    }

    /// Yalnızca KOPYALARI değiştirir. Sonuç:
    /// - struct: `structOriginal` aynı kalır, `structCopy` ilerler.
    /// - class: `classCopy` ile `classOriginal` aynı nesne olduğu için ikisi birden ilerlemiş görünür.
    mutating func advanceCopies(by pages: Int = CopySemanticsDemo.step) {
        structCopy.advance(by: pages)
        classCopy.advance(by: pages)
    }

    /// Değer eşitliği: içerikler aynı mı? (Struct'lar için anlamlı olan soru budur.)
    var structsAreEqual: Bool {
        structOriginal == structCopy
    }

    /// Kimlik (identity): İki referans bellekteki **aynı** nesneyi mi gösteriyor?
    /// `===` yalnızca class (ve actor) örnekleri için vardır; struct'larda kimlik kavramı yoktur.
    var classesAreIdentical: Bool {
        classOriginal === classCopy
    }

    /// `let` davranışını gösteren örnek.
    ///
    /// - `let` bir **struct** değişkenini tamamen dondurur: ne kendisi yeniden atanabilir ne de alanları
    ///   değiştirilebilir, `mutating` metotlar da çağrılamaz.
    /// - `let` bir **class** değişkeninde yalnızca *referansı* dondurur: değişken başka bir nesneyi gösteremez,
    ///   ama gösterdiği nesnenin `var` alanları değiştirilebilir.
    ///
    /// - Returns: `let` ile tutulan referans üzerinden ilerletilmiş sayfa numarası.
    static func pageAfterAdvancingThroughLet(startPage: Int, by pages: Int) -> Int {
        let reference = BookmarkReference(page: startPage)
        reference.advance(by: pages)          // Derlenir: nesne değişiyor, referans değil.
        // reference = BookmarkReference(page: 0)   // HATA: derlenmez, 'let' referans yeniden atanamaz.

        // let value = BookmarkValue(page: startPage)
        // value.advance(by: pages)                  // HATA: derlenmez, 'let' struct üzerinde mutating çağrılamaz.
        return reference.page
    }
}
