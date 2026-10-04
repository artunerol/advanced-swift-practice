import Foundation

/// Okunan sayfaların geçmişi: **copy-on-write (CoW)** tekniğini elle uygulayan küçük bir değer tipi.
///
/// "Struct her atamada kopyalanıyorsa 10.000 elemanlı bir `Array`'i fonksiyona vermek pahalı olmaz mı?"
/// Olmaz, çünkü `Array`, `String`, `Dictionary` ve `Set` içeride tam olarak bu tekniği kullanır:
///
/// 1. Elemanlar struct'ın içinde değil, heap'teki bir **depo nesnesinde** (class) durur.
/// 2. Kopyalamak = sadece depo referansını kopyalamak (O(1)). İki değer aynı depoyu **paylaşır**.
/// 3. Biri değiştirilmek istendiğinde önce "depoyu benden başka tutan var mı?" diye sorulur
///    (`isKnownUniquelyReferenced`). Varsa depo **o anda** kopyalanır, sonra değişiklik yapılır.
///
/// Sonuç: Dışarıdan bakınca tam bir değer tipi (kopyalar birbirini etkilemez), içeride ise gereksiz kopya yok.
/// Bu tip mekanizmayı görünür kılmak için var; gerçek kodda `Array` zaten bunu senin için yapar.
struct PageHistory: Equatable {
    /// Paylaşılan depo. `private`: Dışarıdan kimse depoya doğrudan dokunamaz; tüm değişiklikler
    /// `record(_:)` üzerinden, yani CoW kontrolünden geçerek yapılır. Değer semantiğini koruyan şey bu kapsüllemedir.
    private final class Storage {
        var pages: [Int]

        init(pages: [Int]) {
            self.pages = pages
        }
    }

    private var storage: Storage

    init(pages: [Int] = []) {
        storage = Storage(pages: pages)
    }

    var pages: [Int] {
        storage.pages
    }

    /// Yeni bir sayfa ekler. Depo paylaşılıyorsa önce kendi kopyasını oluşturur (copy-on-write).
    mutating func record(_ page: Int) {
        // `isKnownUniquelyReferenced(&storage)`: Bu nesneye başka güçlü (strong) referans yoksa `true`.
        // `&` gerekiyor çünkü fonksiyon, sonucun güvenilir olması için değişkene özel (inout) erişim ister.
        // Bu yüzden yalnızca `mutating` bir bağlamda, `var` bir depo alanı üzerinde çağrılabilir.
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(pages: storage.pages)
        }
        storage.pages.append(page)
    }

    /// İki değer aynı depoyu mu paylaşıyor? (Depo bir class olduğu için `===` ile kimlik karşılaştırması yapılabilir.)
    func sharesStorage(with other: PageHistory) -> Bool {
        storage === other.storage
    }

    /// Deponun kimliği. Testlerde "değişiklik yerinde mi yapıldı, yoksa depo mu kopyalandı?" sorusunu yanıtlar.
    var storageIdentifier: ObjectIdentifier {
        ObjectIdentifier(storage)
    }

    /// Değer eşitliği **içeriğe** bakar, depoya değil: Farklı depolarda duran aynı sayfalar eşittir.
    static func == (lhs: PageHistory, rhs: PageHistory) -> Bool {
        lhs.pages == rhs.pages
    }
}

/// Ekrandaki "CoW" deneyinin durumu.
struct CopyOnWriteDemo {
    static let firstPage = 10
    static let step = 10

    private(set) var original: PageHistory
    private(set) var copy: PageHistory

    init() {
        original = PageHistory(pages: [Self.firstPage])
        copy = original    // `var copy = original` → henüz hiçbir şey kopyalanmadı; depo ortak.
    }

    var sharesStorage: Bool {
        original.sharesStorage(with: copy)
    }

    /// Kopyaya bir sonraki sayfayı ekler. İlk çağrıda depo ayrılır; `original` hiç etkilenmez.
    mutating func recordNextPageOnCopy() {
        copy.record((copy.pages.last ?? 0) + Self.step)
    }
}
