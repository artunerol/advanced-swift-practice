import Foundation

// "Bellek" deneyinin saf mantığı: MemoryLayout ile satır içi (inline) boyutlar ve adres karşılaştırmaları.
//
// Önce doğru cümle: Swift sana bir değerin stack'te mi heap'te mi duracağını GARANTİ ETMEZ; garanti ettiği şey
// semantiktir (değer tipi kopyalanır, referans tipi paylaşılır). Ama nasıl saklandığını bilmek, "class neden daha
// pahalı?" ve "struct'lar stack'te mi?" sorularını doğru cevaplamanı sağlar:
//
// - Bir değer tipi, BULUNDUĞU YERDE satır içi saklanır. Yerel bir değişkense genelde stack'te (ya da register'da),
//   bir class'ın alanıysa o nesnenin içinde (heap), bir Array'in elemanıysa dizinin heap'teki deposunda durur.
//   Kaçan (escaping) bir closure'ın yakaladığı `var` heap'te bir kutuya taşınır; `any P` kutusunun 3 kelimelik
//   tamponuna sığmayan bir değer de heap'e konur.
// - Bir class örneği heap'te ayrılır ve referans sayılır (ARC). Değişkende duran şey yalnızca 8 baytlık adrestir.
//   (Optimize edici, fonksiyondan hiç kaçmayan bazı nesneleri stack'e alabilir; bu bir garanti değil, optimizasyondur.)
//
// Değerler 64-bit platformlar içindir (bugünkü tüm iPhone'lar ve simülatörler). Bir "kelime" (word) = 8 bayt.

/// Class'a bağlı (`AnyObject`) bir protocol. Existential'ı, sıradan bir protocol'ünkinden küçüktür:
/// İçindeki değer zaten bir referans olduğu için 3 kelimelik tampona ve tip bilgisine gerek yoktur.
protocol PageTracking: AnyObject {
    var page: Int { get }
}

extension BookmarkReference: PageTracking {}

/// Hizalama (alignment) farkını göstermek için: 8 + 1 bayt veri, ama dizide her eleman 16 bayt yer kaplar.
struct BookmarkPosition {
    var page: Int
    var isFavorite: Bool
}

enum MemoryLayoutDemo {
    /// `MemoryLayout` tablosundaki bir satır.
    struct Row: Identifiable, Equatable, Sendable {
        /// Kısa anahtar; erişilebilirlik kimliğinde kullanılır ("struct", "class"...).
        let id: String
        /// Ekranda gösterilen tip adı.
        let typeName: String
        /// Bu tipin bir değerinin satır içi kapladığı bayt.
        let size: Int
        /// Aynı tipten ardışık iki değer arasındaki mesafe (dizideki eleman başına yer). Hizalama için `size`'dan büyük olabilir.
        let stride: Int
        let note: String
    }

    static func row<T>(_ type: T.Type, id: String, name: String, note: String) -> Row {
        Row(id: id, typeName: name, size: MemoryLayout<T>.size, stride: MemoryLayout<T>.stride, note: note)
    }

    static let rows: [Row] = [
        row(BookmarkValue.self, id: "struct", name: "BookmarkValue (struct)",
            note: "Tek alanı olan struct: değerin kendisi, tam 1 Int."),
        row(BookmarkPosition.self, id: "padding", name: "BookmarkPosition (Int + Bool)",
            note: "size 9 ama stride 16: Sonraki Int 8'in katında başlamalı (hizalama)."),
        row(BookmarkReference.self, id: "class", name: "BookmarkReference (class)",
            note: "Değişkende yalnızca adres (referans) durur; nesnenin kendisi heap'te."),
        row(BookmarkReference?.self, id: "optionalClass", name: "BookmarkReference?",
            note: "Optional referans da 8 bayt: nil, boş adresle (0) temsil edilir."),
        row([Int].self, id: "array", name: "[Int]",
            note: "Array de bir struct ama içinde tek bir referans var; elemanlar heap'teki depoda."),
        row(String.self, id: "string", name: "String",
            note: "16 bayt: kısa metinler satır içi, uzunlar heap'teki bir depoda."),
        row((any ReadingItem).self, id: "existential", name: "any ReadingItem",
            note: "Existential kutu: 3 kelimelik değer tamponu + tip bilgisi + witness table = 5 kelime."),
        row((any PageTracking).self, id: "classExistential", name: "any PageTracking (AnyObject)",
            note: "Class'a bağlı protocol: referans + witness table = 2 kelime."),
    ]
}

/// İki şeyin bellekteki adreslerini karşılaştırma sonucu.
struct AddressComparison: Equatable, Sendable {
    let first: UInt
    let second: UInt

    var isSameAddress: Bool { first == second }

    static func hex(_ address: UInt) -> String {
        "0x" + String(address, radix: 16)
    }
}

/// Adres deneyleri. Adreslerin kendisi her çalıştırmada değişir; değişmeyen şey "aynı mı, farklı mı?" sonucudur.
enum MemoryAddressDemo {
    /// `var copy = original` ile kopyalanan iki STRUCT: iki ayrı değer, iki ayrı adres.
    ///
    /// İki değişkenin işaretçisini AYNI ANDA (iç içe) alıyoruz: Bu süre boyunca ikisi de bellekte gerçek bir konumda
    /// durmak zorunda ve birine yazmak diğerini etkilememeli. Bu yüzden iki ayrı değişken aynı adreste olamaz.
    /// (İşaretçi yalnızca closure içinde geçerlidir; dışarı taşımıyoruz, sadece sayısal değerini okuyoruz.)
    static func structCopies() -> AddressComparison {
        var original = BookmarkValue(page: 10)
        var copy = original
        return withUnsafeMutablePointer(to: &original) { originalPointer in
            withUnsafeMutablePointer(to: &copy) { copyPointer in
                AddressComparison(first: UInt(bitPattern: originalPointer), second: UInt(bitPattern: copyPointer))
            }
        }
    }

    /// `let copy = original` ile kopyalanan iki CLASS referansı: kopyalanan şey adres; ikisi de aynı nesneyi gösterir.
    static func sharedReference() -> AddressComparison {
        let original = BookmarkReference(page: 10)
        let copy = original
        // `withExtendedLifetime`: Adresi okurken nesnenin yaşadığından emin ol. (Adresi okuduktan sonra nesneyi
        // kullanmıyoruz; ARC onu son kullanımdan hemen sonra bırakabilirdi.)
        return withExtendedLifetime(original) {
            AddressComparison(first: address(of: original), second: address(of: copy))
        }
    }

    /// İçeriği aynı, ama AYRI oluşturulmuş iki nesne: `==` anlamında eşit olabilirler, kimlikleri (`===`) farklıdır.
    static func separateObjects() -> AddressComparison {
        let first = BookmarkReference(page: 10)
        let second = BookmarkReference(page: 10)
        // İkisini de aynı anda canlı tutuyoruz; yoksa ilki bırakılıp ikincisi aynı adrese yerleşebilirdi.
        return withExtendedLifetime((first, second)) {
            AddressComparison(first: address(of: first), second: address(of: second))
        }
    }

    /// Nesnenin heap'teki adresi. `passUnretained`: Referans sayacını artırmadan, sadece adrese bakıyoruz.
    /// (`ObjectIdentifier(object)` da aynı adresten türetilir; "aynı nesne mi?" sorusunun güvenli cevabı `===`'dir.)
    static func address(of object: AnyObject) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(object).toOpaque())
    }
}

/// Ekranın gösterdiği tek bir ölçüm. Değer tipi: Ekran onu `@State`'te tutar, "Yeniden ölç" yenisini üretir.
struct MemoryAddressReport: Equatable, Sendable {
    let structCopies: AddressComparison
    let sharedReference: AddressComparison
    let separateObjects: AddressComparison

    static func measure() -> MemoryAddressReport {
        MemoryAddressReport(
            structCopies: MemoryAddressDemo.structCopies(),
            sharedReference: MemoryAddressDemo.sharedReference(),
            separateObjects: MemoryAddressDemo.separateObjects()
        )
    }
}
