# Struct vs Class: Değer ve Referans Semantiği

## Neden önemli?

Swift'te yazdığın her tip için ilk karar şudur: `struct` mı, `class` mı? Bu seçim yalnızca sözdizimi değildir; verinin **kopyalanınca nasıl davrandığını**, belleğin **ne zaman serbest bırakıldığını** ve tipin **thread'ler arasında güvenle taşınıp taşınamayacağını** belirler.

- Swift standart kütüphanesinin neredeyse tamamı (`Int`, `String`, `Array`, `Dictionary`, `Optional`...) değer tipidir.
- SwiftUI'da view'lar struct'tır. Bu projedeki `Book`, `Review`, `AppDependencies` da struct'tır.
- Swift 6'nın veri yarışı (data race) güvenliği büyük ölçüde değer semantiğine dayanır: Kopyalanan bir değeri iki thread paylaşamaz.
- Mülakatlarda "struct ile class farkı", "copy-on-write", "retain cycle", "weak ile unowned farkı" soruları neredeyse her zaman gelir.

Uygulamada **Temeller → Struct vs Class** ekranındaki üç deney (Kopyalama, CoW, ARC) bu dersin canlı halidir.

## Temel kavramlar

### 1. Değer semantiği ve referans semantiği

Aynı şeyi (bir ayracı) iki şekilde modelleyelim:

```swift
struct BookmarkValue { var page: Int }             // değer tipi
final class BookmarkReference { var page: Int }    // referans tipi (init'i kısaltmak için atlandı)
```

**Değer semantiği:** Atama ya da fonksiyona geçirme, **bağımsız bir kopya** üretir.

```swift
let original = BookmarkValue(page: 10)
var copy = original
copy.page += 10
// original.page == 10, copy.page == 20
```

**Referans semantiği:** Değişken nesnenin kendisini değil, **adresini** tutar. Atama sadece adresi kopyalar; iki değişken **aynı** nesneyi gösterir.

```swift
let original = BookmarkReference(page: 10)
let copy = original
copy.page += 10
// original.page == 20: aynı nesne!
```

Asıl fark "nerede saklandığı" değil, **paylaşılıp paylaşılmadığıdır**. Değer tipinde bir kopyayı değiştirmek başka hiçbir yeri etkilemez; bu da "birisi verimi arkamdan değiştirdi" türü hataları ortadan kaldırır.

### 2. Eşitlik (`==`) ve kimlik (`===`)

- **Eşitlik:** "İçerikleri aynı mı?" `Equatable` ile gelir. Struct ve enum'larda tüm alanlar `Equatable` ise derleyici `==`'yu **kendisi üretir**. Class'larda üretmez; istersen elle yazarsın (bkz. `AudioBook`).
- **Kimlik:** "Bellekteki aynı nesne mi?" `===` yalnızca class (ve actor) örnekleri için vardır. Struct'ların kimliği yoktur; sadece değerleri vardır.

```swift
let a = BookmarkReference(page: 5)
let b = BookmarkReference(page: 5)
a.page == b.page   // true: içerik aynı
a === b            // false: iki ayrı nesne
```

### 3. `let`, `var` ve `mutating`

| | `let` ile | `var` ile |
|---|---|---|
| **struct** | Tamamen sabit: alanlar değişmez, `mutating` metot çağrılamaz | Alanlar değişebilir |
| **class** | Sadece *referans* sabit: başka nesneyi gösteremez, ama nesnenin `var` alanları değişebilir | Referans da değişebilir |

Struct metotlarında `self` varsayılan olarak sabittir. Kendi alanını değiştiren bir metot `mutating` olmak zorundadır ve yalnızca `var` bir değer üzerinde çağrılabilir:

```swift
struct BookmarkValue {
    var page: Int
    mutating func advance(by pages: Int) { page += pages }
}

final class BookmarkReference {
    var page: Int
    init(page: Int) { self.page = page }
    func advance(by pages: Int) { page += pages }   // mutating yok: değişen şey referans değil, nesne
}
```

`mutating` aslında "bu metot `self`'in yerine yeni bir değer yazar" demektir. Bu yüzden `@State` gibi bir yerde tutulan struct'ı `mutating` bir metotla değiştirmek SwiftUI'a "değer değişti" sinyalini verir.

### 4. Stack mı heap mi? Semantik önemli, depolama bir uygulama detayı

Sık duyulan "struct stack'te, class heap'te durur" cümlesi **yarı doğrudur**:

- Bir struct değeri **tanımlandığı yerde, satır içinde (inline)** saklanır. Yerel bir değişkense genelde stack'te (ya da register'larda) durur. Ama bir class'ın alanıysa o nesneyle birlikte heap'tedir; bir `Array`'in elemanıysa dizinin heap'teki deposundadır; kaçan (escaping) bir closure'ın yakaladığı `var` ise heap'te bir kutuya alınır. `any P` gibi bir existential kutuya sığmayan büyük bir değer de heap'e taşınır.
- Class örnekleri **heap'te** ayrılır ve referans sayılır. (Optimize edici, fonksiyon dışına hiç kaçmayan bazı nesneleri stack'e alabilir.)

Swift sana depolama yeri hakkında hiçbir **garanti** vermez; verdiği garanti **semantiktir**: Değer tipi kopyalanır, referans tipi paylaşılır. Karar verirken "nerede saklanır?" diye değil, "bu veri paylaşılmalı mı, kimliği var mı?" diye sor.

### 5. Copy-on-write (CoW)

"Struct her atamada kopyalanıyorsa 10.000 elemanlı bir diziyi fonksiyona vermek pahalı olmaz mı?" Olmaz, çünkü `Array`, `String`, `Dictionary` ve `Set` **copy-on-write** kullanır:

1. Elemanlar struct'ın içinde değil, heap'teki bir depo nesnesinde durur.
2. Kopyalamak sadece depo referansını kopyalar (O(1)). İki değer aynı depoyu **paylaşır**.
3. Biri değiştirilmek istendiğinde `isKnownUniquelyReferenced` ile "depoyu başkası da tutuyor mu?" diye bakılır. Tutuyorsa depo **o anda** kopyalanır.

```swift
var a = [1, 2, 3]
var b = a          // kopya yok, depo ortak
b.append(4)        // şimdi kopyalanır; a hâlâ [1, 2, 3]
```

Aynı tekniği kendi tipine uygulamak için depoyu `private` bir `final class` içine koyup her değişiklikten önce benzersizliği kontrol edersin:

```swift
struct PageHistory {
    private final class Storage { var pages: [Int]; init(pages: [Int]) { self.pages = pages } }
    private var storage: Storage

    mutating func record(_ page: Int) {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(pages: storage.pages)   // paylaşılıyor: önce kopyala
        }
        storage.pages.append(page)
    }
}
```

Dikkat: CoW **otomatik bir dil özelliği değildir**. Senin yazdığın `struct Point { var x, y: Double }` her atamada gerçekten kopyalanır (ki bu zaten çok ucuzdur). CoW, büyük heap deposu olan tipler için elle uygulanan bir tekniktir.

### 6. ARC (Automatic Reference Counting)

Class örneklerinin ömrünü ARC yönetir:

- Her nesnenin bir **güçlü referans sayacı** vardır. Bir değişken ya da özellik nesneyi tuttuğunda sayaç artar, bıraktığında azalır.
- Sayaç 0 olduğu an nesne yok edilir: Önce `deinit` çalışır, sonra nesnenin tuttuğu referanslar bırakılır.
- ARC bir **çöp toplayıcı (garbage collector) değildir**. Arka planda "ulaşılamayan nesneleri" arayan kimse yoktur. Sayma işi derleme anında eklenen `retain`/`release` çağrılarıyla yapılır.

Önemli ayrıntı: Swift bir nesnenin ömrünün `}` işaretinde değil, **son kullanıldığı yerde** bitebileceğini söyler. Optimize edici nesneyi daha erken bırakabilir. Bu yüzden `deinit`'in tam olarak hangi satırda çalışacağına güvenen kod yazma. Bu projedeki testler de sadece garanti edilen şeyleri (fonksiyon döndüğünde `deinit`'in çalışmış olması, üyenin karttan önce yok edilmesi) doğrular.

Struct ve enum'ların referans sayacı yoktur ve normalde `deinit` yazamazsın. (İçlerindeki class referansları elbette sayılır. Tek istisna kopyalanamayan `~Copyable` tiplerdir; onlar `deinit` tanımlayabilir, ama bu ileri bir konu.)

### 7. `strong`, `weak`, `unowned`

| | Sayacı artırır mı? | Nesne yok olunca | Tipi | Ne zaman? |
|---|---|---|---|---|
| `strong` (varsayılan) | Evet | Yok olmaz; sen tuttukça yaşar | Her şey | Sahiplik |
| `weak` | Hayır | Otomatik `nil` olur | Her zaman Optional | Karşı taraf senden önce yok olabilir (delegate, geri referans) |
| `unowned` | Hayır | `nil` olmaz; erişirsen **çöker** | Optional olabilir de, olmayabilir de | Karşı taraf en az senin kadar yaşayacaksa |

`weak` Swift 6.2'ye kadar yalnızca `var` olabiliyordu; Swift 6.2 ile `weak let` de yazılabiliyor. `unowned(unsafe)` ise hiçbir kontrol yapmaz: Yok olmuş nesneye erişim çökmek yerine tanımsız davranıştır. Neredeyse hiç gerekmez.

### 8. Retain cycle (güçlü referans döngüsü)

İki nesne birbirini güçlü tutarsa sayaçları hiçbir zaman 0'a inmez; dışarıdan kimse onlara ulaşamasa bile bellekte kalırlar:

```swift
final class LibraryMember { var card: LibraryCard? }
final class LibraryCard   { var holder: LibraryMember? }   // YANLIŞ: güçlü geri referans

let member = LibraryMember()
let card = LibraryCard()
member.card = card
card.holder = member
// Kapsam bitti: ikisinin de deinit'i ÇALIŞMAZ, sızıntı.
```

Çözüm, oklardan birini zayıflatmaktır. "Sahip" olan taraf (üye) güçlü tutar, geri referans zayıftır:

```swift
final class LibraryCard { weak var holder: LibraryMember? }
```

Uygulamadaki ARC deneyi bu üç durumu (`strong`, `weak`, `unowned`) çalıştırıp `deinit` günlüğünü gösterir. `strong` senaryosu her dokunuşta **gerçekten** iki nesne sızdırır; Xcode'da uygulama çalışırken **Debug Memory Graph** düğmesine basarak bu nesneleri görebilirsin. Instruments'taki **Leaks** aracı da aynı şeyi yakalar.

**Closure'larda döngü.** Closure'lar da referans tipidir ve yakaladıkları nesneleri güçlü tutar. Bir nesne bir closure'ı özellik olarak saklıyor ve closure da `self`'i yakalıyorsa döngü oluşur:

```swift
final class ReadingTimer {
    var onTick: (() -> Void)?
    var seconds = 0

    func start() {
        onTick = { self.seconds += 1 }             // YANLIŞ: self → onTick → self
        onTick = { [weak self] in self?.seconds += 1 }   // DOĞRU: yakalama listesi (capture list)
    }
}
```

Her closure döngü yaratmaz:
- **Kaçmayan (non-escaping)** closure'lar (`map`, `filter`, `sorted(by:)`, `withAnimation`) fonksiyon bitince yok olur; `[weak self]` gerekmez.
- `Task { ... }` `self`'i görev bitene kadar tutar. Görev biterse sorun yok. Ama bitmeyen bir görev (ör. sonsuz bir `for await` döngüsü) `self`'i sonsuza kadar tutar; görevi bir özellikte sakla ve işin bitince `cancel()` et.
- SwiftUI view'ları struct olduğu için bir view içindeki closure'da `[weak self]` yazamazsın bile: `weak` yalnızca class (ve class'a bağlı protocol) tiplerine uygulanabilir. `self` bir değerdir; closure onun bir kopyasını yakalar.

Bu projede gerçek bir örnek: [FavoritesStore.swift](../BookShelf/Core/Stores/FavoritesStore.swift) içindeki `onTermination` closure'ı actor'ü `[weak self]` ile yakalar. Akış (stream) actor'den uzun yaşayabilir; güçlü yakalasaydı actor'ü gereksiz yere hayatta tutardı.

### 9. Hangisini ne zaman seçmeli?

Apple'ın "Choosing Between Structures and Classes" rehberinin özeti:

1. **Varsayılan olarak struct kullan.**
2. Objective-C ile birlikte çalışman gerekiyorsa class kullan (ör. `NSObject` alt sınıfı).
3. Modellediğin verinin **kimliğini** kontrol etmen gerekiyorsa class kullan (bir dosya tanıtıcısı, bir ağ bağlantısı, bir pencere: "aynı" olanı paylaşmak istersin).
4. Davranış paylaşmak için kalıtım yerine **struct + protocol** kullan.

Pratik kural: Paylaşılan, değişebilir bir durum gerçekten gerekiyorsa önce `actor` ya da `@MainActor` bir class düşün; kilitli sıradan bir class en son seçenektir.

### 10. Enum'lar değer tipidir, actor'ler referans tipidir

- `enum` da bir **değer tipidir**: kopyalanır, `mutating` metotları olabilir. İlişkili değerler (associated values) içeren enum'lar "şunlardan tam olarak biri" durumlarını modellemenin en temiz yoludur (bkz. `RetainCycleEvent`).
- `actor` bir **referans tipidir**: class gibi paylaşılır, `===` ile karşılaştırılabilir, `deinit`'i vardır. Farkı, durumunu aynı anda yalnızca bir görevin değiştirebilmesi ve bu yüzden otomatik `Sendable` olmasıdır. [FavoritesStore](../BookShelf/Core/Stores/FavoritesStore.swift) bir actor'dür; [AppDependencies](../BookShelf/App/AppDependencies.swift) struct'ı onu kopyalanınca paylaşılan bir referans olarak taşır.

### 11. Sendable ile ilişkisi

`Sendable`, "bu değer başka bir thread'e/actor'e güvenle gönderilebilir" demektir. Swift 6 dil modunda bunu derleyici denetler.

| Tip | Ne zaman `Sendable`? |
|---|---|
| struct / enum | Tüm alanları `Sendable` ise. Modül içi (public olmayan) tiplerde bu **otomatik çıkarılır**. |
| `final class` | Yalnızca tüm alanları `let` ve `Sendable` ise (bkz. `AudioBook`). |
| `final` olmayan class | Normal yolla olamaz. `@unchecked Sendable` gerekir: "Güvenliği ben sağlıyorum" sözü (kilit, `Mutex` vb.). |
| `actor`, `@MainActor` class | Her zaman. Durum izole edildiği için. |

Değer tipleri bu yüzden eşzamanlılıkta (concurrency) çok rahattır: Göndermek = kopyalamak. [Book](../BookShelf/Core/Models/Book.swift) tüm alanları `Sendable` bir struct olduğu için view model'den servise, task'tan actor'e serbestçe geçer. [BookmarkReference](../BookShelf/Features/Fundamentals/StructVsClass/Bookmark.swift) ise değiştirilebilir bir class olduğu için `Sendable` değildir. Swift 6 onu başka bir task'a ya da actor'e yalnızca gönderen taraf ona bir daha dokunmayacaksa göndermene izin verir (*region-based isolation*: nesne tek bir sahipten diğerine devredilir). İki taraf da kullanmaya devam ederse derleme hatası alırsın:

```swift
func startReading() {
    let bookmark = BookmarkReference(page: 1)
    Task.detached { bookmark.advance(by: 1) }   // HATA: "sending value of non-Sendable type ... risks causing data races"
    print(bookmark.page)                        // çünkü bookmark burada hâlâ kullanılıyor
}
```

`print` satırını silersen kod derlenir: Nesne artık tamamen yeni göreve devredilmiştir. Dikkat: `@MainActor` bir yerde (ör. bir SwiftUI view'unda) `Task.detached` yerine `Task { }` yazsaydın hata almazdın; `Task { }` çağıranın actor'ünü miras alır, yani iki taraf da ana actor'de çalışır ve ortada bir sınır geçişi yoktur.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [Bookmark.swift](../BookShelf/Features/Fundamentals/StructVsClass/Bookmark.swift) | `BookmarkValue`, `BookmarkReference` | Aynı modelin değer ve referans hali, `mutating` farkı |
| [Bookmark.swift](../BookShelf/Features/Fundamentals/StructVsClass/Bookmark.swift) | `CopySemanticsDemo.advanceCopies(by:)`, `classesAreIdentical`, `pageAfterAdvancingThroughLet(startPage:by:)` | `var copy = original` sonrası davranış, `===`, `let` ile class |
| [PageHistory.swift](../BookShelf/Features/Fundamentals/StructVsClass/PageHistory.swift) | `PageHistory.record(_:)`, `sharesStorage(with:)`, `CopyOnWriteDemo` | Elle yazılmış copy-on-write, `isKnownUniquelyReferenced` |
| [RetainCycleDemo.swift](../BookShelf/Features/Fundamentals/StructVsClass/RetainCycleDemo.swift) | `LibraryMember`, `LibraryCard`, `ReferenceStrength`, `RetainCycleDemo.run(_:)` | ARC, `deinit`, strong/weak/unowned, retain cycle |
| [StructVsClassView.swift](../BookShelf/Features/Fundamentals/StructVsClass/StructVsClassView.swift) | `StructVsClassView` | Deneylerin SwiftUI ekranı, `@State` ile struct durumu |
| [Book.swift](../BookShelf/Core/Models/Book.swift) | `Book` | Değişmez, `Sendable` bir model struct'ı |
| [AppDependencies.swift](../BookShelf/App/AppDependencies.swift) | `AppDependencies` | Referans (actor) taşıyan struct: kopyalar aynı actor'ü paylaşır |
| [FavoritesStore.swift](../BookShelf/Core/Stores/FavoritesStore.swift) | `FavoritesStore.changes()` | Actor = referans tipi; closure'da `[weak self]` |
| [FundamentalsStructVsClassTests.swift](../BookShelfTests/Fundamentals/FundamentalsStructVsClassTests.swift) | `FundamentalsStructVsClassTests` | Değer/referans semantiği ve CoW testleri |
| [FundamentalsRetainCycleTests.swift](../BookShelfTests/Fundamentals/FundamentalsRetainCycleTests.swift) | `FundamentalsRetainCycleTests` | Sızıntı var/yok, `weak`'in `nil` olması |

## Sık yapılan hatalar

**1. Struct'ın içine değiştirilebilir bir class koyup değer semantiği beklemek.**

```swift
// YANLIŞ: Kopyalar aynı Settings nesnesini paylaşır.
final class Settings { var fontSize = 14 }
struct ReaderState { var settings = Settings() }

var a = ReaderState()
let b = a
a.settings.fontSize = 20      // b.settings.fontSize da 20 oldu!

// DOĞRU: Alanı da değer tipi yap (ya da deposu private olan bir CoW tipi kullan).
struct Settings { var fontSize = 14 }
```

**2. Closure'da `self`'i güçlü yakalayıp saklamak.**

```swift
// YANLIŞ
onTick = { self.seconds += 1 }

// DOĞRU
onTick = { [weak self] in
    guard let self else { return }
    self.seconds += 1
}
```

**3. `nil` olabilecek bir şeyi `unowned` tutmak.**

```swift
// YANLIŞ: Delegate senden önce yok olabilir; erişim çöker.
unowned var delegate: ReaderDelegate

// DOĞRU
weak var delegate: ReaderDelegate?
```

**4. `let` bir class örneğini değişmez sanmak.**

```swift
let bookmark = BookmarkReference(page: 1)
bookmark.page = 99     // Derlenir! let sadece referansı sabitler.
```

**5. `deinit` zamanlamasına güvenmek.**

```swift
// YANLIŞ: FileHandleWrapper dosyayı deinit'te kapatıyor ve "}" işaretinde kapanacağı varsayılıyor.
// Ama file'ın son kullanımı init satırı; optimize edici onu hemen bırakabilir.
do {
    let file = FileHandleWrapper(path)
    startWriting()          // dosya çoktan kapanmış olabilir
}

// DOĞRU: Ömrü açıkça yönet (ör. açıkça close() çağır ya da defer kullan).
let file = FileHandleWrapper(path)
defer { file.close() }
```

**6. `final` olmayan bir class'ı `Sendable` yapmaya çalışmak.**

```swift
// YANLIŞ: "non-final class 'Cache' cannot conform to 'Sendable'"
class Cache: Sendable { let limit = 10 }

// DOĞRU: final + değişmez alanlar; paylaşılan değiştirilebilir durum gerekiyorsa actor.
final class Cache: Sendable { let limit = 10 }
actor MutableCache { var items: [String: Data] = [:] }
```

## Mülakatta sorulabilecekler

**1. Struct ile class arasındaki temel farklar neler?**
Struct değer tipidir (kopyalanır), class referans tipidir (paylaşılır). Class'larda kalıtım, `deinit`, kimlik (`===`) ve ARC ile referans sayma vardır. Struct'lar otomatik memberwise `init` alır, kendi alanını değiştiren metotları `mutating` olmalıdır ve tüm alanları `Sendable` ise kolayca `Sendable` olur.

**2. Copy-on-write nedir? Her struct CoW mudur?**
Kopyalamayı, değişiklik anına kadar erteleyen tekniktir: Kopyalar depoyu paylaşır, biri değişince `isKnownUniquelyReferenced` ile benzersizlik kontrol edilip gerekirse depo kopyalanır. `Array`, `String`, `Dictionary`, `Set` böyle çalışır. Senin yazdığın sıradan bir struct CoW değildir; alanları doğrudan kopyalanır. CoW'u istersen elle uygularsın.

**3. Struct'lar stack'te mi tutulur?**
Her zaman değil. Struct tanımlandığı yerde satır içi saklanır: yerel değişkense genelde stack'te, bir class'ın alanıysa heap'te, bir dizinin elemanıysa dizinin deposunda. Kaçan closure'ın yakaladığı `var`'lar da heap'e kutulanır. Swift'in garantisi depolama değil semantiktir.

**4. `weak` ile `unowned` farkı nedir?**
İkisi de sayacı artırmaz. `weak` Optional'dır ve nesne yok olunca otomatik `nil` olur. `unowned` `nil` olmaz; yok olmuş nesneye erişim programı durdurur. Karşı taraf senden önce yok olabiliyorsa `weak`, en az senin kadar yaşayacağı kesinse `unowned`.

**5. Retain cycle'ı nasıl bulursun?**
`deinit`'e log koyup çağrılmadığını görmek; Xcode'un Debug Memory Graph'ında sızan nesnelerin yanındaki mor ünlem işaretleri; Instruments'ın Leaks aracı. Çözüm: Oklardan birini `weak`/`unowned` yapmak, closure'larda yakalama listesi kullanmak ya da tasarımı döngü yerine ağaç olacak şekilde değiştirmek.

**6. Actor bir değer tipi mi, referans tipi mi?**
Referans tipidir: paylaşılır, kimliği ve `deinit`'i vardır. Farkı, durumuna aynı anda yalnızca bir görevin erişebilmesidir (izolasyon); dışarıdan erişim `await` ister ve actor'ler her zaman `Sendable`'dır.

**7. SwiftUI view'ları neden struct?**
View'lar ekranın o anki durumunun ucuz, değişmez tarifleridir; SwiftUI onları sık sık yeniden oluşturup karşılaştırır. Değer tipleri bunun için ucuz ve güvenlidir. Kalıcı durum `@State`/`@Observable` ile view'un dışında, SwiftUI'ın yönettiği depoda tutulur.

**8. `let` ile tanımlı bir class örneğinin özelliği değiştirilebilir mi?**
Evet, özellik `var` ise. `let` yalnızca referansı sabitler; değişken başka bir nesneyi gösteremez ama nesnenin kendisi değişebilir. Struct'ta ise `let` her şeyi dondurur.

## Alıştırmalar

**1. Closure senaryosu ekle.**
`ReferenceStrength`'e benzer şekilde ARC deneyine bir "closure" senaryosu ekle: `LibraryCard` bir `var onExpire: (() -> Void)?` saklasın ve closure üyeyi yakalasın. Önce güçlü yakalayıp sızıntıyı, sonra düzeltip `deinit`'leri gör. `FundamentalsRetainCycleTests`'e iki test ekle.
*İpucu:* Döngü `card → closure → member → card` şeklinde. Düzeltme için closure'ın başına `[weak member]` yakalama listesi yeter.

**2. `PageHistory`'ye `removeLast()` ekle.**
Değer semantiği korunmalı: Bir kopyadan son sayfayı silmek diğer kopyayı etkilememeli. Bunu doğrulayan bir test yaz.
*İpucu:* `record(_:)` içindeki `isKnownUniquelyReferenced` kontrolünü `private mutating func makeStorageUnique()` adında bir yardımcıya taşı ve her iki metotta çağır.

**3. `BookmarkReference`'ı `Sendable` yapmayı dene.**
Önce sadece `: Sendable` ekle ve derleyicinin verdiği hatayı oku. Sonra iki farklı şekilde derlenir hale getir: (a) `page`'i `let` yapıp `advance(by:)`'ı yeni bir nesne döndüren bir metoda çevirerek, (b) tipi bir `actor`'e çevirerek. İki çözümde çağıran kodun nasıl değiştiğini karşılaştır.
*İpucu:* Hata mesajı "stored property 'page' of 'Sendable'-conforming class 'BookmarkReference' is mutable" olacak. Actor çözümünde `advance(by:)` dışarıdan `await` ile çağrılır.
