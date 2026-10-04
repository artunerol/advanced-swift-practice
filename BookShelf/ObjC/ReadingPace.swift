import Foundation

/// Okuma temposuyla ilgili sabitler. **Swift → Objective-C** yönünün örneği.
///
/// Bu sınıf Swift'te yazıldı ama Objective-C'den kullanılıyor: `BKReadingTimeEstimator.m`,
/// `#import "BookShelf-Swift.h"` satırıyla bu sınıfı görür ve `BKReadingPace.defaultPagesPerHour` diye çağırır.
///
/// Objective-C'nin bir Swift tipini görebilmesi için üç şart var:
/// 1. **`NSObject`'ten türemeli.** ObjC'de her nesne bir ObjC sınıfıdır; mesaj gönderme (`objc_msgSend`),
///    `alloc`/`init`, `respondsToSelector:` gibi temel davranışlar `NSObject`'ten gelir.
///    `NSObject`'ten türemeyen bir sınıfa `@objc` yazarsan derleyici hata verir:
///    "only classes that inherit from NSObject can be declared '@objc'".
/// 2. **`@objc` ile işaretlenmeli.** Swift 4'ten beri `NSObject` alt sınıflarının üyeleri bile otomatik olarak
///    ObjC'ye açılmaz; açmak istediğin her üyeye `@objc` yazarsın. Hepsini açmak istersen sınıfa
///    `@objcMembers` yazabilirsin (ama ikili boyutu büyütür ve niyeti bulanıklaştırır; biz tek tek seçiyoruz).
/// 3. **Tipleri ObjC'de temsil edilebilmeli.** `Double`, `Int`, `String`, `[String]`, `NSObject` alt sınıfları,
///    `Int` ham değerli `@objc enum`'lar olur; struct'lar, ilişkili değerli (associated value) enum'lar,
///    tuple'lar, generic tipler, `Int?` gibi opsiyonel değer tipleri olmaz.
///
/// `@objc(BKReadingPace)`: ObjC tarafındaki adı açıkça veriyoruz. Vermeseydik ObjC'deki sınıf adı yine
/// `ReadingPace` olurdu ama çalışma zamanı (runtime) adı modül adıyla karışık, "mangle" edilmiş bir ad
/// (`_TtC9BookShelf11ReadingPace`) olurdu. Açık ad hem ObjC'deki "BK" önek geleneğine uyar hem de
/// `NSStringFromClass`, arşivleme (`NSCoding`) gibi ada bağlı yerlerde kararlı bir ad verir.
///
/// `final`: Swift'te alt sınıf beklemiyoruz (derleyici çağrıları statik dağıtabilir). ObjC tarafı ise zaten
/// HİÇBİR Swift sınıfından türetemez: üretilen header her Swift sınıfını `objc_subclassing_restricted` ile işaretler.
@objc(BKReadingPace)
final class ReadingPace: NSObject {
    /// Varsayılan okuma hızı: saatte 40 sayfa.
    ///
    /// ObjC'de sınıf özelliği (class property) olarak görünür:
    /// `@property (nonatomic, class, readonly) double defaultPagesPerHour;`
    /// Böylece ObjC'de nokta sözdizimiyle okunur: `BKReadingPace.defaultPagesPerHour`.
    ///
    /// Swift 6'da statik (global) değişkenler data race kaynağı olabileceği için denetlenir.
    /// `let` + `Sendable` bir tip (`Double`) olduğundan güvenli: kimse değiştiremez, herkes okuyabilir.
    @objc static let defaultPagesPerHour: Double = 40

    /// Verilen hızı doğrular: pozitif ve sonlu (finite) ise aynen döndürür; `0`, negatif, `NaN` veya
    /// sonsuz ise `defaultPagesPerHour` döndürür.
    ///
    /// `@objc(resolvedPagesPerHour:)` ile ObjC seçicisini (selector) kendimiz belirliyoruz. Belirtmeseydik
    /// Swift adından türetilen `resolvedWithPagesPerHour:` gibi daha hantal bir ad oluşurdu.
    /// ObjC'de: `[BKReadingPace resolvedPagesPerHour:value]`
    @objc(resolvedPagesPerHour:)
    static func resolved(pagesPerHour: Double) -> Double {
        // `NaN > 0` her zaman false olduğu için NaN de varsayılana düşer; `isFinite` sonsuzu eler.
        pagesPerHour.isFinite && pagesPerHour > 0 ? pagesPerHour : defaultPagesPerHour
    }

    /// Önerilen okuma hızı aralığı (saatte sayfa). **Yalnızca Swift'ten görünür.**
    ///
    /// `ClosedRange<Double>` generic bir Swift struct'ı; ObjC'de karşılığı yok. Bu yüzden `@objc` yazmadık.
    /// Yazsaydık derleyici "property cannot be marked '@objc' because its type cannot be represented
    /// in Objective-C" hatası verirdi. Aynı sınıfta hem ObjC'ye açık hem Swift'e özel üyeler olabilir.
    static let typicalRange: ClosedRange<Double> = 20...60

    /// Bu sınıf yalnızca sabitler için bir "isim alanı" (namespace); örnek (instance) oluşturmanın anlamı yok.
    /// `private` başlatıcı, üretilen header'da `init`'i `SWIFT_UNAVAILABLE` yapar; yani ObjC'de
    /// `[[BKReadingPace alloc] init]` yazmak da derleme hatasıdır. (ObjC'deki `NS_UNAVAILABLE`'ın Swift'teki karşılığı.)
    private override init() {
        super.init()
    }
}
