# Objective-C ve Swift ile Birlikte Çalışma (Interop)

## Neden önemli?

- **Gerçek projelerde hâlâ Objective-C var.** 10 yılı aşkın iOS uygulamalarında yüz binlerce satır ObjC kodu bulunur. Bu kod bir gecede yeniden yazılmaz; yeni özellikler Swift'te yazılırken eski kodla konuşmak zorundadır. Mülakatlarda "bir ObjC sınıfını Swift'ten, bir Swift sınıfını ObjC'den nasıl kullanırsın?" sorusu bu yüzden çok sık gelir.
- **Apple SDK'larını okumak için gerekli.** UIKit ve Foundation'ın büyük bölümü ObjC header'larıyla tanımlıdır. `NSError **` parametresinin neden Swift'te `throws` olduğunu, bir API'nin neden `String!` döndürdüğünü ya da neden `@unknown default` istendiğini bilmek, bu header'ların Swift'e nasıl aktarıldığını (import) bilmekle ilgilidir.
- **Hata ayıklama.** `unrecognized selector sent to instance` gibi çökme mesajları doğrudan ObjC çalışma zamanından (runtime) gelir. Swift'te yazsan bile `@objc` sınıfların bu dünyada yaşar.

Bu projede Objective-C bilerek küçük tutuldu: iki ObjC sınıfı (`BKISBNValidator`, `BKReadingTimeEstimator`) ve ObjC'ye açılan bir Swift sınıfı (`ReadingPace`). Ama iki yönü de, hata aktarımını, nullability'yi ve concurrency (`Sendable`) boyutunu gösteriyorlar.

## Temel kavramlar

### 1. Swift geliştiricisi için 10 dakikada Objective-C

#### `.h` ve `.m` dosyaları

Objective-C, C'nin üstüne kurulu bir dildir ve C gibi arayüzü (interface) uygulamadan (implementation) ayırır:

| Dosya | İçerik | Swift'teki karşılığı |
|---|---|---|
| `BKISBNValidator.h` | `@interface ... @end`: dışarıya açık metotlar ve property'ler | `internal`/`public` bildirimler |
| `BKISBNValidator.m` | `@implementation ... @end`: gövdeler, `static` yardımcı fonksiyonlar | Gövdeler ve `private` yardımcılar |

Başka bir dosya sınıfı kullanmak istediğinde `.h`'yi `#import` eder; `.m` hiçbir zaman import edilmez. Swift'te böyle bir ayrım yoktur: modüldeki her dosya diğerlerini otomatik görür.

```objc
// BKReadingTimeEstimator.h (sadeleştirilmiş)
@interface BKReadingTimeEstimator : NSObject            // NSObject'ten türeyen sınıf
@property (nonatomic, readonly) double pagesPerHour;     // property
- (instancetype)initWithPagesPerHour:(double)pagesPerHour;
- (NSString *)formattedEstimateForPageCount:(NSInteger)pageCount;
@end
```

#### Mesaj gönderme (message sending)

ObjC'de metot "çağrılmaz", nesneye **mesaj gönderilir**:

```objc
NSString *text = [estimator formattedEstimateForPageCount:320];   // Swift: estimator.formattedEstimate(forPageCount: 320)
BOOL ok = [BKISBNValidator isValidISBN13:@"978-605-000-001-6"];   // sınıfa mesaj
```

- Köşeli parantezin solu alıcı (receiver), sağı **seçici** (selector): `formattedEstimateForPageCount:`. Metodun adı, iki nokta üst üsteler dahil bu seçicinin tamamıdır: `validateISBN13:error:`.
- Derleyici her mesajı `objc_msgSend(alıcı, seçici, argümanlar...)` çağrısına çevirir. Hangi kodun çalışacağına **çalışma anında** seçiciye bakılarak karar verilir (dinamik dağıtım / dynamic dispatch). Method swizzling ve KVO bu dinamizme dayanır; Swift'in varsayılan statik/vtable dağıtımından daha esnek ama daha yavaştır.
- Alıcı o seçiciyi tanımıyorsa uygulama `unrecognized selector sent to instance` hatasıyla çöker.

#### Sınıf (`+`) ve örnek (`-`) metotları

```objc
+ (BOOL)isValidISBN13:(NSString *)isbn;                        // sınıf metodu   -> Swift: class func / static func
- (NSTimeInterval)estimatedSecondsForPageCount:(NSInteger)n;   // örnek metodu   -> Swift: func
```

Bir sınıf metodunun içinde `self`, bir nesne değil **sınıfın kendisidir**. [BKISBNValidator.m](../BookShelf/ObjC/BKISBNValidator.m) içinde `[self normalizedISBN:isbn]` bu yüzden bir sınıf metodu çağrısıdır.

#### Başlatıcı (init) kalıbı

```objc
- (instancetype)initWithPagesPerHour:(double)pagesPerHour {
    self = [super init];          // üst sınıfın init'i nil dönebilir
    if (self) {
        _pagesPerHour = pagesPerHour;   // init içinde setter yerine arka plandaki ivar'a (_pagesPerHour) yazılır
    }
    return self;
}
```

Swift'e `init(pagesPerHour:)` olarak aktarılır (`initWith` öneki atılır). `NS_DESIGNATED_INITIALIZER` Swift'teki "designated init"e, `NS_UNAVAILABLE` ise "bu başlatıcı yok" demeye karşılık gelir.

#### Property'ler ve öznitelikleri (attributes)

`@property` derleyiciye bir getter, (gerekirse) bir setter ve `_ad` biçiminde bir arka plan değişkeni (ivar) ürettirir.

| Öznitelik | Anlamı | Ne zaman? |
|---|---|---|
| `nonatomic` | Erişimciler kilit kullanmaz, hızlıdır. | Neredeyse her zaman (UIKit'teki gibi). |
| `atomic` (**varsayılan**) | Tek bir get/set yarım okunmaz. **Thread-safety değildir**: "oku, değiştir, yaz" dizisini korumaz. | Nadiren; gerçekten gerekiyorsa kilit ya da seri kuyruk kullan. |
| `strong` (nesnelerde varsayılan) | Sahiplik: nesneyi hayatta tutar (retain). | Sahip olduğun nesneler. |
| `weak` | Sahiplik yok; nesne yok olunca otomatik `nil` olur (zeroing). | Delegate'ler, üst nesneye geri referanslar (döngü kırmak için). |
| `copy` | Atanan değerin kopyasını saklar. | `NSString`, `NSArray`, blok (block) property'leri: dışarıdan `NSMutableString` verilip sonradan değiştirilmesine karşı. |
| `assign` (skalerlerde varsayılan) | Düz atama, sahiplik yok. | `double`, `NSInteger`, `BOOL`. Nesnelerde **kullanma**: nesne yok olunca sarkan (dangling) pointer kalır. |
| `readonly` / `readwrite` | Setter üretilsin mi? | Dışarıya `readonly`, `.m` içindeki sınıf uzantısında (class extension) `readwrite` yaygın bir kalıptır. |
| `class` | Sınıf property'si (Swift'teki `static var`/`class var`). | `BKReadingPace.defaultPagesPerHour` gibi. |

Swift'e aktarımda `readonly` → `{ get }`, `weak` → `weak var`, `copy` → Swift'te değer tipleri zaten kopyalandığı için ekstra bir şey görünmez.

#### Literaller

```objc
NSString *s = @"Kitaplık";                 // NSString (C string'i "..." değil!)
NSNumber *n = @42;  NSNumber *b = @YES;    // kutulanmış (boxed) sayılar
NSNumber *pages = @(book.pageCount);       // ifade kutulama
NSArray<NSString *> *list = @[@"a", @"b"];
NSDictionary<NSString *, id> *info = @{NSLocalizedDescriptionKey: @"ISBN boş olamaz."};
```

Foundation koleksiyonları `nil` içeremez: `@[nil]` çalışma anında istisna (exception) fırlatır. "Boş" değer gerekirse `[NSNull null]` kullanılır.

#### `nil`'e mesaj göndermek

ObjC'de `nil` bir nesneye mesaj göndermek **çökmez**; sonuç sıfır değeridir (`nil`, `0`, `NO`):

```objc
NSString *title = nil;
NSUInteger length = [title length];   // 0 — hata yok, uyarı yok
```

Bu, kodu kısaltır ama hataları gizler: yanlışlıkla `nil` kalan bir değişken sessizce "0" üretir. Swift'te aynı davranış yalnızca açıkça yazılan optional chaining ile olur: `title?.count` (sonuç `Int?`).

### 2. Objective-C'de ARC

ARC (Automatic Reference Counting), Swift'tekiyle **aynı mekanizmadır**: derleyici `retain`/`release` çağrılarını derleme anında ekler; çöp toplayıcı (GC) yoktur. ObjC'de sahiplik değişken düzeyinde de yazılabilir:

| Niteleyici | Anlamı | Swift karşılığı |
|---|---|---|
| `__strong` (varsayılan) | Sahip olur. | Normal `var`/`let` |
| `__weak` | Sahip olmaz, nesne ölünce `nil` olur. | `weak var` |
| `__unsafe_unretained` | Sahip olmaz, `nil` olmaz (sarkabilir). | `unowned(unsafe)` |
| `__autoreleasing` | Değer autorelease havuzuna verilir; `NSError **` çıkış parametreleri örtük olarak böyledir. | Karşılığı yok (Swift `throws` kullanır) |

Swift'teki gibi en klasik hata **referans döngüsüdür** (retain cycle). Bloklar (Swift'teki closure'lar) `self`'i güçlü (strong) yakalar:

```objc
__weak typeof(self) weakSelf = self;
self.completion = ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;   // blok çalışırken nesne ölmesin
    [strongSelf reload];
};
```

ARC yalnızca ObjC nesnelerini yönetir; Core Foundation (`CFStringRef` vb.) nesneleri için `__bridge`, `CFBridgingRelease` gibi dönüşümlerle sahipliği açıkça belirtmek gerekir.

### 3. Nullability: `nonnull`, `nullable`, `NS_ASSUME_NONNULL`

ObjC'de her nesne pointer'ı teknik olarak `nil` olabilir. Swift ise `String` ile `String?`'i ayırır. Header bu bilgiyi vermezse Swift, en kötüsünü varsaymak yerine **örtük açılan opsiyonel** (implicitly unwrapped optional, IUO) üretir:

```objc
// Nullability bilgisi olmayan eski bir header
- (NSString *)name;
+ (NSArray *)items;
```

```swift
// Swift'teki görünümü
open func name() -> String!
open class func items() -> [Any]!     // generic bilgisi de yok: [String] değil [Any]
```

`String!` tehlikelidir: değer gerçekten `nil` gelirse ve sen onu `String` gibi kullanırsan uygulama çöker. Ayrıca `let n = legacy.name()` yazınca `n`'nin tipi `String?` olur, `let n: String = legacy.name()` yazınca ise zorla açılır.

Çözüm: header'ı "denetlenmiş" (audited) hale getirmek:

```objc
NS_ASSUME_NONNULL_BEGIN
+ (NSString *)normalizedISBN:(NSString *)isbn;                                  // nonnull  -> String
+ (nullable NSString *)checkDigitForFirst12Digits:(NSString *)digits;            // nullable -> String?
+ (BOOL)validateISBN13:(NSString *)isbn error:(NSError * _Nullable * _Nullable)error;
NS_ASSUME_NONNULL_END
```

- `NS_ASSUME_NONNULL_BEGIN/END` arasındaki pointer'lar varsayılan olarak `nonnull` olur; yalnızca istisnaları `nullable` diye işaretlersin.
- `nullable`/`nonnull` metot ve property konumlarında; `_Nullable`/`_Nonnull` ise her pointer konumunda (ör. `NSError * _Nullable * _Nullable`'daki iki ayrı pointer için) yazılır.
- Nullability bir **sözdür**, çalışma anı denetimi değildir. `nonnull` dediğin metot yine de `nil` döndürürse ObjC derleyicisi bunu çoğu zaman yakalayamaz; Swift ise söze güvenir ve sonuç çökme ya da tanımsız davranış olabilir.

### 4. `NS_SWIFT_NAME`: Swift'e doğal ad vermek

ObjC'de isim alanı (namespace) olmadığı için sınıflara önek konur (`BK`, `NS`, `UI`). Swift'te modüller isimleri ayırdığı için bu önekler gereksizdir. `NS_SWIFT_NAME` Swift tarafındaki adı belirler:

```objc
NS_SWIFT_NAME(ISBNValidator)
@interface BKISBNValidator : NSObject
+ (nullable NSString *)checkDigitForFirst12Digits:(NSString *)digits NS_SWIFT_NAME(checkDigit(forFirst12Digits:));
@end
```

```swift
ISBNValidator.checkDigit(forFirst12Digits: "978605000008")   // "5"
```

Ad vermezsen Swift, ObjC adından kendi kurallarıyla bir ad türetir (ör. `initWithPagesPerHour:` → `init(pagesPerHour:)`, `estimatedSecondsForPageCount:` → `estimatedSeconds(forPageCount:)` gibi "akıllı" bölmeler). Sonuç her zaman güzel olmadığı için önemli API'lerde adı açıkça vermek iyi bir alışkanlıktır. Benzer araçlar: `NS_SWIFT_UNAVAILABLE("...")` (Swift'ten gizle), `NS_REFINED_FOR_SWIFT` (adın başına `__` koyup Swift'te daha güzel bir sarmalayıcı yazmana izin verir).

### 5. Hatalar: `NSError **` → `throws`, `NS_ERROR_ENUM`

ObjC'de fonksiyon tek değer döndürür; hata ayrıntısı için **çıkış parametresi** (out-parameter) kullanılır:

```objc
+ (BOOL)validateISBN13:(NSString *)isbn error:(NSError * _Nullable * _Nullable)error;

// Çağıran taraf
NSError *error = nil;
if (![BKISBNValidator validateISBN13:text error:&error]) {   // değişkenin ADRESİNİ veriyoruz
    NSLog(@"%@", error.localizedDescription);
}
```

Uygulayan taraf iki kurala uyar (bkz. [BKISBNValidator.m](../BookShelf/ObjC/BKISBNValidator.m) içindeki `BKISBNFail`):

```objc
if (error != NULL) {                // 1) Çağıran NULL verdiyse yazma (yoksa EXC_BAD_ACCESS)
    *error = [NSError errorWithDomain:BKISBNValidatorErrorDomain
                                 code:BKISBNValidatorErrorChecksumMismatch
                             userInfo:@{NSLocalizedDescriptionKey: @"Kontrol hanesi (son hane) hatalı."}];
}
return NO;                          // 2) Başarısızlığı DÖNÜŞ DEĞERİYLE bildir
```

Swift bu kalıbı tanır ve metodu `throws` yapar:

```swift
open class func validateISBN13(_ isbn: String) throws   // BOOL kayboldu, error: parametresi kayboldu
```

Kurallar: son parametre `NSError **` olmalı; dönüş tipi `BOOL` ise Swift'te `Void`, `nullable` bir nesne ise opsiyonel olmayan tipe dönüşür. `NO` dönüp `*error`'u doldurmamak bir sözleşme ihlalidir; Swift yine de hata fırlatır ama elinde anlamlı bir hata olmaz.

**`NS_ERROR_ENUM`** hata kodlarını **tipli** hale getirir. Swift'e (kabaca) şöyle aktarılır:

```swift
public struct BKISBNValidatorError: CustomNSError, Hashable, Error {
    public static var errorDomain: String { get }
    public enum Code: Int, @unchecked Sendable, Equatable {
        case empty = 1, invalidLength = 2, invalidCharacters = 3, checksumMismatch = 4
    }
    public static var checksumMismatch: BKISBNValidatorError.Code { get }   // desen eşleştirme için
    // ...
}
```

Böylece `NSError`'ın `domain`/`code` tamsayılarıyla uğraşmak yerine:

```swift
do {
    try ISBNValidator.validateISBN13(input)
} catch let error as BKISBNValidatorError {
    switch error.code {
    case .empty, .invalidCharacters, .invalidLength: ...
    case .checksumMismatch: ...
    @unknown default: ...           // Swift 6'da ZORUNLU
    }
} catch {
    ...                             // tipsiz throws: her Error gelebilir
}
// ya da kısaca: catch BKISBNValidatorError.checksumMismatch { ... }
```

`@unknown default` neden zorunlu? C enum'ları "donmamış" (non-frozen) kabul edilir: ObjC kütüphanesi ileride yeni bir kod ekleyebilir. Swift 6 dil modunda `@unknown default` olmadan bu `switch` derlenmez ("switch covers known cases, but ... may have additional unknown values"). `default` yerine `@unknown default` yazmanın farkı: bilinen bir vakayı unutursan derleyici yine uyarır. Kesinlikle genişlemeyecek enum'lar için ObjC'de `NS_CLOSED_ENUM` kullanılır.

Ters yönde de çalışır: `@objc` bir Swift fonksiyonu `throws` ise ObjC'de sonuna `error:` (ya da `AndReturnError:`) parametresi eklenmiş bir `BOOL` metot olarak görünür: `func check() throws` → `- (BOOL)checkAndReturnError:(NSError **)error`.

### 6. Concurrency: `NS_SWIFT_SENDABLE`

Swift 6'da bir değer task'lar ya da actor'ler arasında geçerken `Sendable` olmalıdır. Swift, bir ObjC sınıfının thread-safe olup olmadığını **denetleyemez**, bu yüzden ObjC sınıflarını varsayılan olarak `Sendable` saymaz:

```swift
let legacy = Legacy()                          // işaretsiz bir ObjC sınıfı
let task = Task.detached { legacy.name() }
_ = legacy.name()                              // HATA: sending ... risks causing data races
```

`BKReadingTimeEstimator` değişmez (tek property'si `readonly` ve init'ten sonra değişmiyor). Bunu Swift'e söylemek için:

```objc
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(ReadingTimeEstimator)
@interface BKReadingTimeEstimator : NSObject
```

Swift bunu `open class ReadingTimeEstimator: NSObject, @unchecked Sendable` olarak içe aktarır. **`@unchecked`** kelimesi önemli: bu senin sözündür, derleyici ObjC kodunu denetlemez. Sınıfa ileride değişken bir property eklersen ve işareti kaldırmazsan, data race'ler derleyiciden habersiz geri gelir. İlgili diğer işaretler: `NS_SWIFT_NONSENDABLE` (açıkça Sendable değil), `NS_SWIFT_UI_ACTOR` (Swift'te `@MainActor`). Bu projedeki kanıt testi: [ObjCSendableInteropTests.swift](../BookShelfTests/ObjC/ObjCSendableInteropTests.swift).

Async tarafında da otomatik köprü var: ObjC'deki `- (void)fetchWithCompletionHandler:(void (^)(NSString *))completionHandler` gibi metotlar Swift'te **ayrıca** `func fetch() async -> String` olarak görünür; `@objc` bir Swift `async` fonksiyonu da ObjC'ye tamamlama bloklu (completion handler) bir metot olarak açılır.

### 7. İki yön: köprü başlığı ve üretilen `-Swift.h`

```
ObjC  ──►  Swift :  BookShelf-Bridging-Header.h   (sen yazarsın, Swift derlenmeden ÖNCE okunur)
Swift ──►  ObjC  :  BookShelf-Swift.h             (Xcode üretir, Swift derlendikten SONRA oluşur)
```

**Köprü başlığı (bridging header)** — [BookShelf-Bridging-Header.h](../BookShelf/ObjC/BookShelf-Bridging-Header.h): Buraya `#import` edilen ObjC header'ları, uygulama hedefindeki tüm Swift dosyalarında `import` yazmadan görünür. Hangi dosya olduğu Build Settings'teki `SWIFT_OBJC_BRIDGING_HEADER` ayarındadır. Köprü başlıkları uygulama ve test hedefleri içindir; framework hedeflerinde desteklenmez (orada modül haritası / umbrella header kullanılır). Test hedefimiz ObjC sınıflarını `@testable import BookShelf` ile görür; uygulama modülünü import etmek onun köprü başlığını da beraberinde getirir.

**Üretilen header** — `<ModülAdı>-Swift.h`: Swift derleyicisi `@objc` bildirimlerden bir ObjC header'ı üretir. Bu projede `ReadingPace.swift`'ten şu çıkıyor (sadeleştirilmiş):

```objc
SWIFT_CLASS_NAMED("ReadingPace")
@interface BKReadingPace : NSObject
SWIFT_CLASS_PROPERTY(@property (nonatomic, class, readonly) double defaultPagesPerHour;)
+ (double)resolvedPagesPerHour:(double)pagesPerHour;
- (nonnull instancetype)init SWIFT_UNAVAILABLE;      // private init'in sonucu
@end
```

Dosyayı görmek için bir build aldıktan sonra [BKReadingTimeEstimator.m](../BookShelf/ObjC/BKReadingTimeEstimator.m) içindeki `#import "BookShelf-Swift.h"` satırına Cmd+tıkla (dosya DerivedData altındadır, projede görünmez).

Bir Swift tipini ObjC'ye açmanın şartları:

1. **Sınıf `NSObject`'ten (ya da başka bir ObjC sınıfından) türemeli.** Aksi halde: "only classes that inherit from NSObject can be declared '@objc'". ObjC nesne modeli (alloc/init, `objc_msgSend`, `respondsToSelector:`) `NSObject` üzerinden gelir.
2. **Üyeler `@objc` ile işaretlenmeli.** Swift 4'ten (SE-0160) beri `NSObject` alt sınıflarının üyeleri bile otomatik açılmaz. Tüm üyeleri açmak için sınıfa `@objcMembers` yazılabilir; ObjC'de temsil edilemeyen üyeleri ise sessizce atlar.
3. **Görünürlük:** Uygulama hedefinde köprü başlığı olduğu için `internal` bildirimler de üretilen header'a girer; `private`/`fileprivate` olanlar girmez.
4. `@objc(BKReadingPace)` ObjC'deki adı belirler. Swift sınıfları varsayılan olarak modül adını içeren "mangle" edilmiş bir çalışma anı adı alır; açık ad, `NSStringFromClass` ve arşivleme gibi ada bağlı yerlerde kararlı bir ad sağlar.
5. KVO ya da swizzling için `@objc dynamic` gerekir: `dynamic`, çağrının her zaman ObjC mesajıyla (`objc_msgSend`) yapılmasını zorunlu kılar.

ObjC'nin göremedikleri (`@objc` yazarsan derleme hatası alırsın):

| Swift özelliği | Neden? |
|---|---|
| `struct` (ör. `Book`) | ObjC'de değer tipi nesne yok. |
| İlişkili değerli enum'lar, `String` ham değerli enum'lar | ObjC enum'u tamsayıdır. Yalnızca `@objc enum X: Int` açılabilir. |
| Generic tipler/fonksiyonlar (ör. `ClosedRange<Double>`) | ObjC'nin "hafif generic"leri (lightweight generics) yalnızca koleksiyon ipuçlarıdır. |
| Tuple'lar, `Int?` gibi opsiyonel değer tipleri | Karşılığı yok (`NSNumber *` elle kullanılabilir). |
| `NSObject`'ten türemeyen sınıflar | Yukarıdaki 1. madde. |
| Protocol extension'ları, `@objc` olmayan protocol'ler | ObjC protokolleri yalnızca `@objc protocol` ile. |
| `AsyncStream`, `Duration`, `Result` gibi Swift'e özgü tipler | Yine struct/generic/enum. |

`async` fonksiyonlar ise görünür (tamamlama bloklu metot olarak); `throws` fonksiyonlar da görünür (`NSError **` ile). Swift `String`, `[T]`, `[K: V]` tipleri `NSString`, `NSArray`, `NSDictionary`'ye köprülenir.

### 8. Neden ekipler hâlâ Objective-C kullanıyor?

- **Maliyet ve risk:** Büyük, çalışan bir kod tabanını yeniden yazmak aylar sürer ve yeni hata üretir. Kademeli geçiş (yeni kod Swift, eski kod dokunulmadıkça ObjC) daha güvenlidir.
- **Üçüncü parti ve ikili (binary) SDK'lar:** Reklam, analitik, ödeme SDK'larının bir kısmı hâlâ ObjC API'si sunar.
- **C/C++ ile köprü:** Objective-C++ (`.mm`) uzun yıllar C++ kütüphanelerini sarmanın tek yoluydu. Swift 5.9 doğrudan C++ birlikte çalışabilirliği getirdi, ama mevcut `.mm` katmanları hâlâ yaygın.
- **Çalışma zamanı dinamizmi:** Method swizzling, `forwardInvocation:`, `NSProxy` gibi teknikler ObjC runtime'ına dayanır.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [BKISBNValidator.h](../BookShelf/ObjC/BKISBNValidator.h) | `BKISBNValidator`, `BKISBNValidatorError`, `BKISBNValidatorErrorDomain` | `NS_ASSUME_NONNULL`, `NS_SWIFT_NAME`, `NS_ERROR_ENUM`, `nullable` dönüş, `FOUNDATION_EXPORT` |
| [BKISBNValidator.m](../BookShelf/ObjC/BKISBNValidator.m) | `validateISBN13:error:`, `BKISBNFail`, `BKISBNNonDigitCharacterSet` | `NSError **` + NULL denetimi, erken dönüş, `dispatch_once`, `NSCharacterSet`, `static` C yardımcıları |
| [BKReadingTimeEstimator.h](../BookShelf/ObjC/BKReadingTimeEstimator.h) | `BKReadingTimeEstimator` | `NS_SWIFT_SENDABLE`, `readonly` property, `NS_DESIGNATED_INITIALIZER`, `NS_UNAVAILABLE` |
| [BKReadingTimeEstimator.m](../BookShelf/ObjC/BKReadingTimeEstimator.m) | `initWithPagesPerHour:`, `formattedEstimateForPageCount:` | `#import "BookShelf-Swift.h"`, ObjC'den Swift çağırmak, init kalıbı, locale'den bağımsız biçimleme |
| [ReadingPace.swift](../BookShelf/ObjC/ReadingPace.swift) | `ReadingPace` (`BKReadingPace`) | `@objc(Ad)`, `NSObject` şartı, `@objc static let` → sınıf property'si, ObjC'ye kapalı `typicalRange`, `private init` |
| [BookShelf-Bridging-Header.h](../BookShelf/ObjC/BookShelf-Bridging-Header.h) | — | ObjC → Swift köprüsü |
| [ISBNCheckOutcome.swift](../BookShelf/Features/ISBNChecker/ISBNCheckOutcome.swift) | `ISBNCheckOutcome.evaluate(_:)`, `hint(for:normalized:)` | `try` ile ObjC çağırmak, `catch let error as BKISBNValidatorError`, `switch error.code` + `@unknown default` |
| [ISBNCheckerView.swift](../BookShelf/Features/ISBNChecker/ISBNCheckerView.swift) | `ISBNCheckerView` | ObjC mantığını kullanan SwiftUI ekranı (Mülakat sekmesi → Objective-C sorusu → Demo) |
| [ObjCISBNValidatorTests.swift](../BookShelfTests/ObjC/ObjCISBNValidatorTests.swift) | `ObjCISBNValidatorTests` | ObjC kodunu Swift'ten XCTest ile test etmek; tipli hata, domain ve code |
| [ObjCReadingTimeEstimatorTests.swift](../BookShelfTests/ObjC/ObjCReadingTimeEstimatorTests.swift) | `ObjCReadingTimeEstimatorTests` | Biçimlendirme kuralları; `NSClassFromString("BKReadingPace")`, `class_getClassMethod` ile runtime görünürlüğü |
| [ObjCSendableInteropTests.swift](../BookShelfTests/ObjC/ObjCSendableInteropTests.swift) | `ObjCSendableInteropTests` | `NS_SWIFT_SENDABLE`'ın derleme anı kanıtı |
| [ISBNCheckOutcomeTests.swift](../BookShelfTests/ObjC/ISBNCheckOutcomeTests.swift) | `ISBNCheckOutcomeTests` | ObjC hatasını ekran modeline çeviren mantığın testi |
| [BookDetailViewModel.swift](../BookShelf/Features/BookDetail/BookDetailViewModel.swift) | `BookDetailViewModel.init(book:service:favorites:)` | Aynı ObjC sınıflarının başka bir özellikte, `import` yazmadan kullanımı: `ISBNValidator.isValidISBN13(_:)` ve `ReadingTimeEstimator(pagesPerHour:).formattedEstimate(forPageCount:)` |
| [BookDetailView.swift](../BookShelf/Features/BookDetail/BookDetailView.swift) | `BookDetailISBNBadge` | ObjC sonucunu yeşil "Geçerli" / kırmızı "Geçersiz" rozetle gösteren SwiftUI view'ı |

Bu iki ObjC sınıfı kitap detay ekranında da kullanılıyor: `BookDetailViewModel` ISBN durumunu ve tahmini okuma süresini init'te BİR kez, senkron olarak hesaplar (ikisi de hızlı, saf hesaplar; `await` gerekmez). Kitaplar sekmesinde "Huzur"u (8. kitap) aç: `books.json`'daki ISBN'inin kontrol hanesi bilerek yanlış yazıldı (978-605-000-008-**6**; doğrusu 5), bu yüzden rozet kırmızı "Geçersiz" görünür. Diğer yedi kitabın rozeti yeşildir.

## Sık yapılan hatalar

**1. Nullability'siz header yazmak**

```objc
// YANLIŞ: Swift'te String! ve [Any]! olur; nil gelirse çöker.
@interface BKLegacy : NSObject
- (NSString *)title;
- (NSArray *)tags;
@end
```

```objc
// DOĞRU: Neyin nil olabileceği açık; koleksiyonun eleman tipi belli.
NS_ASSUME_NONNULL_BEGIN
@interface BKLegacy : NSObject
- (nullable NSString *)title;             // String?
- (NSArray<NSString *> *)tags;            // [String]
@end
NS_ASSUME_NONNULL_END
```

**2. `-Swift.h`'yi bir header'da import etmek**

```objc
// YANLIŞ: BKShelf.h köprü başlığındaysa döngü oluşur. Swift derlenmek için köprü başlığını okur,
// köprü başlığı BookShelf-Swift.h'yi ister, o da ancak Swift derlendikten sonra var olur.
// BKShelf.h
#import "BookShelf-Swift.h"
@interface BKShelf : NSObject
- (double)paceFor:(BKReadingPace *)pace;
@end
```

```objc
// DOĞRU: Header'da ileri bildirim (forward declaration), import yalnızca .m'de.
// BKShelf.h
@class BKReadingPace;
@interface BKShelf : NSObject
- (double)paceFor:(BKReadingPace *)pace;
@end

// BKShelf.m
#import "BKShelf.h"
#import "BookShelf-Swift.h"
```

**3. `NSError **`'a NULL denetimi yapmadan yazmak**

```objc
// YANLIŞ: Çağıran error:NULL verirse (ör. isValidISBN13:) uygulama EXC_BAD_ACCESS ile çöker.
*error = [NSError errorWithDomain:BKISBNValidatorErrorDomain code:1 userInfo:nil];
return NO;
```

```objc
// DOĞRU
if (error != NULL) {
    *error = [NSError errorWithDomain:BKISBNValidatorErrorDomain code:1 userInfo:nil];
}
return NO;
```

**4. Başarıyı `error`'a bakarak anlamaya çalışmak**

```objc
// YANLIŞ: Sözleşme, başarıyı DÖNÜŞ DEĞERİYLE bildirir. Başarılı bir çağrı error'a dokunmak zorunda değildir.
NSError *error;                     // başlatılmamış!
[BKISBNValidator validateISBN13:text error:&error];
if (error) { ... }
```

```objc
// DOĞRU
NSError *error = nil;
if (![BKISBNValidator validateISBN13:text error:&error]) { ... }
```

**5. İçe aktarılan C enum'unda `@unknown default` unutmak**

```swift
// YANLIŞ: Swift 6'da derleme hatası ("may have additional unknown values").
switch error.code {
case .empty, .invalidLength, .invalidCharacters, .checksumMismatch: break
}
```

```swift
// DOĞRU
switch error.code {
case .empty, .invalidLength, .invalidCharacters, .checksumMismatch: break
@unknown default: break
}
```

**6. Değişebilen bir sınıfı `NS_SWIFT_SENDABLE` ile işaretlemek**

```objc
// YANLIŞ: readwrite property + kilit yok. Swift bunu @unchecked Sendable sayar, data race'e kapı açılır.
NS_SWIFT_SENDABLE
@interface BKCounter : NSObject
@property (nonatomic) NSInteger count;
@end
```

```objc
// DOĞRU: Ya değişmez yap (readonly, init'te bir kez ata) ya da işaretleme; Swift'te bir actor'ün arkasına koy.
NS_SWIFT_SENDABLE
@interface BKCounterSnapshot : NSObject
@property (nonatomic, readonly) NSInteger count;
- (instancetype)initWithCount:(NSInteger)count NS_DESIGNATED_INITIALIZER;
@end
```

**7. `NSString` property'sini `strong` yapmak**

```objc
// YANLIŞ: Dışarıdan NSMutableString verilirse, sonradan değişince bizim "title"ımız da değişir.
@property (nonatomic, strong) NSString *title;
```

```objc
// DOĞRU
@property (nonatomic, copy) NSString *title;
```

**8. Swift'in `catch`'inin ObjC istisnalarını (NSException) yakaladığını sanmak**

```swift
// YANLIŞ: NSRangeException bir Swift hatası değildir; bu catch ona hiç ulaşmaz, uygulama çöker.
do {
    let item = try fetchItem(at: 10)   // içeride [array objectAtIndex:10] istisna fırlatıyor
} catch {
    print("yakaladım")                 // çalışmaz
}
```

```swift
// DOĞRU: ObjC'de istisnalar programcı hatası içindir; önce koşulu denetle. Kurtarılabilir hatalar NSError ile gelmeli.
guard index < items.count else { return nil }
```

**9. `NSInteger`'ı `%d` ile biçimlemek**

```objc
// YANLIŞ: 64 bit'te NSInteger long'dur; %d int bekler (uyarı, yanlış çıktı riski).
NSString *s = [NSString stringWithFormat:@"%d sayfa", pageCount];
```

```objc
// DOĞRU
NSString *s = [NSString stringWithFormat:@"%ld sayfa", (long)pageCount];
```

## Mülakatta sorulabilecekler

1. **ObjC'deki `- (BOOL)doThing:(NSError **)error` Swift'te nasıl görünür?**
   `func doThing() throws`. Son parametre `NSError **` ve dönüş `BOOL` (ya da `nullable` nesne) ise Swift bunu `throws`'a çevirir; `BOOL` kaybolur (nesne dönüşü opsiyonel olmaktan çıkar). ObjC tarafının sözleşmesi: başarısızlıkta `NO` döndür ve `error != NULL` ise `*error`'u doldur. `NS_ERROR_ENUM` ile tanımlanan kodlar Swift'e tipli bir hata (`XError`, `XError.Code`) olarak gelir.

2. **Bridging header ile `ModülAdı-Swift.h` arasındaki fark nedir? `-Swift.h`'yi neden `.h` dosyasında import etmeyiz?**
   Köprü başlığı ObjC → Swift yönüdür; elle yazılır ve Swift derlenmeden önce okunur. `-Swift.h` Swift → ObjC yönüdür; derleyici `@objc` bildirimlerden üretir ve Swift derlendikten sonra var olur. Bir header'da (özellikle köprü başlığına giren bir header'da) import etmek döngü yaratır; bu yüzden `.m`'de import edilir, `.h`'de `@class`/`@protocol` ileri bildirimi kullanılır.

3. **Bir Swift sınıfını ObjC'den kullanmak için ne gerekir? `@objc`, `@objcMembers`, `dynamic` farkı?**
   Sınıf `NSObject`'ten türemeli; üyeler `@objc` olmalı ve tipleri ObjC'de temsil edilebilmeli. `@objc` tek bir üyeyi açar; `@objcMembers` sınıftaki (ve alt sınıflarındaki) temsil edilebilen tüm üyeleri açar. `dynamic` ise çağrının her zaman ObjC mesaj gönderimiyle yapılmasını zorlar; KVO ve swizzling için gerekir (`@objc dynamic var`).

4. **`nonnull`, `nullable`, `null_unspecified` Swift'te neye dönüşür? Hiç yazmazsan ne olur?**
   Sırasıyla `T`, `T?`, `T!`. Hiç yazılmamış pointer'lar `null_unspecified` sayılır ve `T!` (IUO) olur: değer `nil` gelip opsiyonel olmayan bir yerde kullanılırsa çöker. `NS_ASSUME_NONNULL_BEGIN/END` bölgesinde varsayılan `nonnull` olur. Bu annotation'lar çalışma anında denetlenmez.

5. **ObjC'de `nil`'e mesaj göndermek ne olur? Swift'te `do/catch` bir `NSException`'ı yakalar mı?**
   `nil`'e mesaj çökmez, sıfır değeri (`nil`/`0`/`NO`) döner; hataları gizleyebilir. `NSException` Swift hatası değildir; Swift'in `catch`'i onu yakalayamaz ve uygulama çöker. ObjC'de istisnalar programcı hataları içindir; kurtarılabilir hatalar `NSError` ile bildirilir.

6. **`atomic` bir property thread-safe midir? Neden NSString property'leri `copy` olur?**
   Hayır. `atomic` yalnızca tek bir get ya da set'in yarım kalmamasını garanti eder; "oku-değiştir-yaz" dizisini korumaz. `copy`, dışarıdan verilen bir `NSMutableString`'in sonradan değiştirilip nesnemizin durumunu arkamızdan bozmasını engeller.

7. **`NS_SWIFT_SENDABLE` ne yapar, derleyici neyi garanti eder?**
   ObjC sınıfının Swift'e `@unchecked Sendable` olarak aktarılmasını sağlar; böylece task/actor sınırlarından geçebilir. Derleyici ObjC kodunu denetlemez; garanti tamamen yazana aittir. İşaretsiz ObjC sınıfları Swift 6'da `Sendable` sayılmaz.

8. **`@objc` bir Swift `async` fonksiyonu ObjC'de nasıl görünür? Tersi?**
   Tamamlama bloklu bir metot olarak: `func fetch() async -> String` → `- (void)fetchWithCompletionHandler:(void (^)(NSString *))completionHandler`. Tersi de geçerli: ObjC'deki tamamlama bloklu metotlar Swift'te ek olarak `async` bir sürümle görünür.

## Alıştırmalar

**1. ISBN-10 desteği ekle.**
`BKISBNValidator`'a `+ (BOOL)validateISBN10:(NSString *)isbn error:(NSError **)error` ekle (başlıkta `NS_SWIFT_NAME` ile Swift adını da ver) ve [ObjCISBNValidatorTests.swift](../BookShelfTests/ObjC/ObjCISBNValidatorTests.swift) içine testlerini yaz. Son olarak [ISBNCheckOutcome.swift](../BookShelf/Features/ISBNChecker/ISBNCheckOutcome.swift) içindeki `switch`'e yeni bir hata kodu eklediğinde ne olduğunu gözlemle.
*İpucu:* ISBN-10'da ağırlıklar soldan sağa 10, 9, ..., 1'dir ve toplam 11'e tam bölünmelidir; son hane `X` (=10) olabilir, bu yüzden "yalnızca rakam" kuralı son hane için değişir. `NS_ERROR_ENUM`'a yeni bir vaka eklediğinde, `@unknown default` sayesinde derleme bozulmaz ama derleyici eksik vaka için uyarı verir. `default` ile `@unknown default` arasındaki farkı burada görürsün.

**2. Swift → ObjC yönünü genişlet.**
[ReadingPace.swift](../BookShelf/ObjC/ReadingPace.swift) sınıfına `@objc static func pagesPerHour(forMinutesPerPage minutes: Double) -> Double` ekle ve bunu [BKReadingTimeEstimator.m](../BookShelf/ObjC/BKReadingTimeEstimator.m) içinden çağır. Ardından `typicalRange`'e `@objc` yazıp aldığın hatayı oku ve geri al.
*İpucu:* Build aldıktan sonra `.m`'deki `#import "BookShelf-Swift.h"` satırına Cmd+tıklayıp üretilen header'da yeni metodun hangi seçiciyle (`pagesPerHourForMinutesPerPage:`) göründüğüne bak. Beğenmezsen `@objc(istediğinAd:)` ile değiştirebilirsin.

**3. Nullability deneyi.**
[BKISBNValidator.h](../BookShelf/ObjC/BKISBNValidator.h) içindeki `NS_ASSUME_NONNULL_BEGIN`/`END` satırlarını geçici olarak sil ve build al. Hangi Swift kodunun bozulduğunu ve nedenini açıkla, sonra geri al.
*İpucu:* Header açıkken Xcode'da sol üstteki "Related Items" (dört kare) menüsünden **Generated Interface**'i seç: `normalizedISBN(_:)` artık `String!` döndürür. [ISBNCheckOutcome.swift](../BookShelf/Features/ISBNChecker/ISBNCheckOutcome.swift) içinde `let normalized = ISBNValidator.normalizedISBN(input)` satırında tip çıkarımı `String?` verir; `.valid(normalized:)` bir `String` beklediği için derleme hatası alırsın. IUO'nun tip çıkarımıyla `Optional`'a dönüştüğünü burada görürsün.
