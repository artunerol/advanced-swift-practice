import Foundation

// ARC (Automatic Reference Counting) kısa özet:
// - Her class örneğinin bir "güçlü referans sayacı" vardır. Bir değişken/özellik nesneyi güçlü (strong,
//   varsayılan) tuttuğunda sayaç artar; o referans ortadan kalkınca azalır.
// - Sayaç 0 olduğu AN nesne yok edilir: önce `deinit` çalışır, sonra nesnenin tuttuğu referanslar bırakılır.
// - Bu bir çöp toplayıcı (garbage collector) DEĞİLDİR: arka planda "ulaşılamayan nesneleri" arayan kimse yok.
//   Bu yüzden A → B ve B → A şeklinde birbirini güçlü tutan iki nesne, dışarıdan kimse onlara ulaşamasa bile
//   sonsuza kadar yaşar. Buna **retain cycle** (güçlü referans döngüsü) denir ve sonucu bellek sızıntısıdır.

/// Karttaki "sahip" referansının türü. Deneyde üç seçeneği karşılaştırıyoruz.
enum ReferenceStrength: String, CaseIterable, Sendable {
    /// Varsayılan. Sayacı artırır. Karşılıklı kullanılırsa döngü oluşur.
    case strong
    /// Sayacı artırmaz. Nesne yok edilince otomatik `nil` olur; bu yüzden her zaman Optional'dır.
    /// (Swift 6.2'ye kadar ayrıca `var` olmak zorundaydı; 6.2 ile `weak let` de yazılabiliyor.)
    case weak
    /// Sayacı artırmaz ve `nil` olmaz. Nesne yok edildikten sonra erişilirse uygulama **çöker**.
    /// Yalnızca "referans verilen nesne en az bu nesne kadar yaşar" garantisi olduğunda kullanılır.
    case unowned
}

/// Deneyde olan biteni sırayla kaydeden olaylar. Enum da bir değer tipidir; ilişkili değerler (associated values)
/// her olayın kendi bilgisini taşımasını sağlar.
enum RetainCycleEvent: Equatable, Sendable, CustomStringConvertible {
    case created(String)
    case linked(ReferenceStrength)
    case deinitialized(String)
    case scopeEnded

    var description: String {
        switch self {
        case .created(let name):
            "\(name) oluşturuldu"
        case .linked(let strength):
            "Bağlandı: üye → kart (strong), kart → üye (\(strength.rawValue))"
        case .deinitialized(let name):
            "deinit: \(name)"
        case .scopeEnded:
            "Kapsam bitti: yerel değişkenler artık yok"
        }
    }
}

/// Olay günlüğü. Nesnelerin `deinit`'i de buraya yazdığı için paylaşılan bir **referans** tipi olmalı.
///
/// Günlük, üyeyi ve kartı tutmaz; onlar günlüğü tutar. Yani ok tek yönlüdür ve yeni bir döngü oluşmaz.
final class RetainCycleLog {
    private(set) var events: [RetainCycleEvent] = []

    func record(_ event: RetainCycleEvent) {
        events.append(event)
    }
}

/// Kütüphane üyesi. Kartına **güçlü** referansla sahiptir (üye yaşadıkça kartı da yaşasın).
final class LibraryMember {
    let name: String
    var card: LibraryCard?
    private let log: RetainCycleLog

    init(name: String, log: RetainCycleLog) {
        self.name = name
        self.log = log
        log.record(.created(displayName))
    }

    var displayName: String {
        "LibraryMember(\(name))"
    }

    /// Sayaç 0 olduğunda çağrılır. Döngü varsa sayaç 0'a hiç inmez ve bu satır HİÇ çalışmaz.
    deinit {
        log.record(.deinitialized(displayName))
    }
}

/// Kütüphane kartı. Sahibine (üyeye) geri bir referans tutar: işte döngü riski burada.
///
/// Normal kodda bu üç özellikten yalnızca biri olur. Burada üç seçeneği yan yana görebilmek için
/// hepsini tanımladık; `attach(to:strength:)` hangisinin kullanılacağını seçer.
final class LibraryCard {
    let number: Int
    private let log: RetainCycleLog

    /// YANLIŞ: Güçlü referans. Üye → kart → üye döngüsü kurar.
    private var strongHolder: LibraryMember?
    /// DOĞRU: `weak` sayacı artırmaz. Üye yok edilince Swift bunu otomatik olarak `nil` yapar.
    private weak var weakHolder: LibraryMember?
    /// DOĞRU (koşullu): `unowned` sayacı artırmaz ama `nil`'e dönmez.
    /// "Kart, sahibinden uzun yaşamaz" garantimiz olduğu için güvenli. Garanti bozulursa erişim çöker.
    private unowned var unownedHolder: LibraryMember?

    init(number: Int, log: RetainCycleLog) {
        self.number = number
        self.log = log
        log.record(.created(displayName))
    }

    var displayName: String {
        "LibraryCard(#\(number))"
    }

    /// Kartın sahibi, hangi referans türüyle bağlandıysa oradan okunur.
    /// Not: `unowned` ile bağlanmış ve sahibi yok edilmiş bir kartta bunu okumak çöker; demo bunu yapmaz.
    var holder: LibraryMember? {
        strongHolder ?? weakHolder ?? unownedHolder
    }

    func attach(to member: LibraryMember, strength: ReferenceStrength) {
        switch strength {
        case .strong: strongHolder = member
        case .weak: weakHolder = member
        case .unowned: unownedHolder = member
        }
        log.record(.linked(strength))
    }

    deinit {
        log.record(.deinitialized(displayName))
    }
}

/// Deneyin sonucu: sadece değerlerden oluşur, bu yüzden `Sendable` ve kolayca test edilebilir.
struct RetainCycleReport: Equatable, Sendable {
    let strength: ReferenceStrength
    let events: [RetainCycleEvent]

    var createdObjects: [String] {
        events.compactMap { event in
            if case .created(let name) = event { name } else { nil }
        }
    }

    var deinitializedObjects: [String] {
        events.compactMap { event in
            if case .deinitialized(let name) = event { name } else { nil }
        }
    }

    /// Oluşturulup hiç yok edilmemiş (sızan) nesne sayısı.
    var leakedObjectCount: Int {
        createdObjects.count - deinitializedObjects.count
    }

    var hasLeak: Bool {
        leakedObjectCount > 0
    }
}

/// "ARC ve retain cycle" deneyini çalıştıran saf (pure) fonksiyonlar.
///
/// Neden saf fonksiyon? Ekran kodu (SwiftUI) olmadan, birim testte doğrudan çağırıp sonucu doğrulayabilmek için.
/// Deney tamamen senkron ve tek thread'de çalışır; sonuç her seferinde aynıdır.
enum RetainCycleDemo {
    static let memberName = "Ayşe"
    static let cardNumber = 42

    /// Bir üye ve bir kart oluşturur, onları verilen referans türüyle birbirine bağlar ve kapsam biter.
    ///
    /// Olayların sırası deterministiktir:
    /// 1. Üye ve kart oluşturulur, bağlanır.
    /// 2. (Döngü yoksa) `makeLinkedPair` dönmeden ÖNCE iki nesne de yok edilir. Önce üye: Kart üyeyi güçlü
    ///    tutmadığı için üyenin tek sahibi yerel değişkendir. Üyenin `deinit`'inden sonra üyenin `card`
    ///    özelliği bırakılır ve kart da yok edilir. (Kart ise üye yaşadığı sürece üye tarafından tutulur.)
    /// 3. `.scopeEnded` en son yazılır.
    ///
    /// `strong` seçilirse 2. adım hiç olmaz: iki nesne birbirini tuttuğu için sayaçları 1'de kalır ve
    /// **gerçekten sızarlar**. (Xcode'da Debug Memory Graph ile bu nesneleri görebilirsin.)
    static func run(_ strength: ReferenceStrength) -> RetainCycleReport {
        let log = RetainCycleLog()
        makeLinkedPair(strength, log: log)
        log.record(.scopeEnded)
        return RetainCycleReport(strength: strength, events: log.events)
    }

    /// Ayrı bir fonksiyon = ayrı bir kapsam. Yerel `member` ve `card` değişkenleri en geç bu fonksiyon
    /// dönerken bırakılır. (Swift yalnızca şunu garanti eder: nesne **son kullanıldığı yere kadar** yaşar.
    /// `}`'e kadar yaşayacağının garantisi yoktur; derleyici onu son kullanımdan hemen sonra, yani kapsam
    /// bitmeden de bırakabilir. Bu yüzden `deinit`'in tam olarak ne zaman çalışacağına güvenen kod yazma.
    /// Bu deneyin sonucu ise zamanlamaya değil yalnızca döngünün olup olmamasına bağlı: her iki sırada da
    /// üyenin `deinit`'i kartınkinden önce çalışır ve ikisi de `.scopeEnded`'den önce gelir.)
    private static func makeLinkedPair(_ strength: ReferenceStrength, log: RetainCycleLog) {
        let member = LibraryMember(name: memberName, log: log)
        let card = LibraryCard(number: cardNumber, log: log)
        member.card = card                           // üye → kart: her zaman güçlü (sahiplik)
        card.attach(to: member, strength: strength)  // kart → üye: deneyin değişkeni
    }
}
