# Protocol'ler ve Protocol Odaklı Programlama

## Neden önemli?

Swift'te soyutlamanın ana aracı class kalıtımı değil **protocol**'lerdir. Standart kütüphane baştan sona protocol'ler üzerine kuruludur (`Equatable`, `Collection`, `Codable`, `Sendable`...), SwiftUI'daki her view bir `View` protocol'üne uyar ve bağımlılık enjeksiyonu (dependency injection) ile test edilebilir kod yazmanın en yaygın yolu protocol'lerdir.

Bu derste şunları öğreneceksin: protocol tanımlamak ve uymak, extension ile varsayılan davranış eklemek, statik/dinamik dispatch tuzağı, `associatedtype` ve generic'ler, `some` ile `any` farkı, protocol birleşimi, standart protocol'ler, protocol ile bağımlılık enjeksiyonu, "olur mu, olmaz mı?" sorularının cevapları ve `typealias`.

Uygulamada **Mülakat** sekmesinin "Swift Temelleri" bölümündeki üç konu bu dersin canlı halidir. Her konuda **Cevap** (30 saniyelik mülakat cevabı, ek sorular, tuzaklar), **Demo** ve **Kod** (bakman gereken dosyalar) bölümleri var:
- **"Protocol ve extension birlikte nasıl kullanılır?"** → Demo: Dispatch / Varsayılan / Koşullu ([ProtocolExtensionDemoView](../BookShelf/Features/Interview/Demos/SwiftBasics/ProtocolExtensionDemoView.swift)).
- **"Protocol'ü tip olarak kullanmak"** → Demo: 16 soruluk quiz ([SwiftQuizView](../BookShelf/Features/Interview/Demos/SwiftBasics/SwiftQuizView.swift)); altındaki bağlantı, `[any ReadingItem]` listesini ve `Shelf<Novel>` rafını gösteren [ProtocolsView](../BookShelf/Features/Fundamentals/Protocols/ProtocolsView.swift)'u açar.
- **"typealias nedir, nerede işe yarar?"** → Demo: [TypealiasDemoView](../BookShelf/Features/Interview/Demos/SwiftBasics/TypealiasDemoView.swift).

## Temel kavramlar

### 1. Protocol bir sözleşmedir

Protocol, bir tipin **ne yapabildiğini** söyler; nasıl yaptığını söylemez. İçindeki her üyeye **gereksinim (requirement)** denir:

```swift
protocol ReadingItem: Sendable {
    var title: String { get }            // en az okunabilir olmalı (let, var ya da computed olabilir)
    var estimatedMinutes: Int { get }
    var kindName: String { get }
    var symbolName: String { get }
}
```

Gereksinimler özellik (`{ get }` ya da `{ get set }`), metot, `mutating` metot, `static` üye, `init` ya da `associatedtype` olabilir. Struct, enum, class ve actor, hepsi protocol'lere uyabilir:

```swift
struct Magazine: ReadingItem { ... }        // struct
final class AudioBook: ReadingItem { ... }  // class
```

`: Sendable` gibi bir üst protocol yazmak, uyan **her** tipe o şartı da yükler. `ReadingItem` `Sendable` olduğu için `AudioBook` `final` olmak ve yalnızca `let` alanlar taşımak zorundadır.

### 2. Var olan bir tipi sonradan uydurmak

Bir tipin kaynak koduna dokunmadan ona bir extension ile yeni bir protocol uygunluğu ekleyebilirsin. Core'daki `Book`'a hiç dokunmadan:

```swift
extension Book: PagedReadingItem {
    var kindName: String { "Kitap" }
}
```

`title` ve `pageCount` zaten `Book`'ta var; `estimatedMinutes` ve `symbolName` varsayılanlardan geliyor. Eksik olan tek şey `kindName`.

Aynı modüldeki bir tip için bu tamamen güvenlidir. **Başka bir modülün** tipini **başka bir modülün** protocol'üne uydurursan (ör. `extension Date: Identifiable`) Swift 6 derleyicisi uyarır: O modülün sahibi ileride aynı uygunluğu eklerse davranış belirsizleşir. Bilerek yapıyorsan `extension Date: @retroactive Identifiable` yazarsın.

### 3. Protocol extension ve varsayılan uygulamalar

Protocol extension'ları, protocol'e uyan **tüm** tiplere davranış ekler:

```swift
extension ReadingItem {
    var symbolName: String { "book.closed" }       // bir gereksinimin varsayılan uygulaması
    var formattedDuration: String {                // extension'a özel yardımcı
        formattedReadingDuration(minutes: estimatedMinutes)
    }
}
```

- `symbolName` bir gereksinim; extension ona **varsayılan** veriyor. `Novel` ve `Book` bunu kullanır, `AudioBook` (`"headphones"`) ve `Magazine` (`"newspaper"`) kendi değerini yazar.
- `formattedDuration` gereksinim değil; tüm uyan tiplere **bedava gelen** bir yardımcı.

Protocol'ler başka protocol'leri **miras alabilir** (refine). Alt protocol'ün extension'ı, üst protocol'ün gereksinimini karşılayabilir:

```swift
protocol PagedReadingItem: ReadingItem {
    var pageCount: Int { get }
}

extension PagedReadingItem {
    var estimatedMinutes: Int { pageCount * 3 / 2 }   // ReadingItem'ın gereksinimi burada karşılandı
}
```

**"Optional" gereksinim yok, varsayılan uygulama var.** Saf Swift protocol'lerinde `optional` gereksinim yoktur; yalnızca `@objc` protocol'lerde `@objc optional` vardır (UIKit delegate'lerindeki isteğe bağlı metotlar böyledir). Swift'teki karşılığı varsayılan uygulamadır: Tip yazmazsa extension'daki gövde çalışır.

**Extension'ların sınırları.** Extension; computed property, metot, `init`, iç içe tip ve protocol uygunluğu ekleyebilir. Şunları yapamaz (mesajlar bu projenin derleyicisinden):

```swift
extension Novel { var rating = 0 }
// error: extensions must not contain stored properties
// (Tipin bellek düzeni tanımında sabitlenir; başka bir dosyadaki extension onu değiştiremez.)

class Base {}
extension Base { func greet() {} }
class Sub: Base { override func greet() {} }
// error: non-'@objc' instance method 'greet()' is declared in extension of 'Base' and cannot be overridden

extension ReadingItem: CustomStringConvertible {}
// error: extension of protocol 'ReadingItem' cannot have an inheritance clause
```

### 4. Gereksinim mi, extension'a özel üye mi? Dispatch tuzağı

Bu, protocol'lerle ilgili en önemli ve en çok sorulan inceliktir.

- **Gereksinim** → **dinamik dispatch**. Çağrı, "witness table" denen bir tablo üzerinden **gerçek tipin** uygulamasına gider. Değişkenin tipi `any ReadingItem` ya da generic `T` olsa bile.
- **Sadece extension'da tanımlı üye** → **statik dispatch**. Hangi uygulamanın çalışacağına derleyici, değişkenin **derleme anındaki tipine** bakarak karar verir. Uyan tip aynı isimde bir üye yazarsa bu onu **gölgeler (shadow)**, ezmez (override etmez).

```swift
extension ReadingItem {
    var shelfSection: String { "Genel raf" }        // gereksinim DEĞİL
}

struct Magazine: ReadingItem {
    var shelfSection: String { "Süreli yayınlar" }  // gölgeler
    var symbolName: String { "newspaper" }          // gereksinimi özelleştirir
}

let magazine = Magazine(...)
let item: any ReadingItem = magazine

magazine.shelfSection   // "Süreli yayınlar": derleme anındaki tip Magazine
item.shelfSection       // "Genel raf": derleyici sadece ReadingItem'ı biliyor
item.symbolName         // "newspaper": gereksinim, gerçek tipe gider
```

Generic bir fonksiyon içinde de aynısı olur: `func f(_ x: some ReadingItem) { x.shelfSection }` her zaman `"Genel raf"` döndürür. "Protocol + extension" demosunun **Dispatch** bölümünde değişkenin derleme anındaki tipini (Magazine / any / some) değiştirip iki üyenin sonucunu canlı görebilirsin ([ProtocolDispatchDemo.observe(from:)](../BookShelf/Features/Fundamentals/Protocols/ProtocolExtensionExamples.swift)).

Aynı tuzağın class kalıtımıyla birleşen hali için "Sık yapılan hatalar"daki 2. maddeye bak. Ve bir uyarı: Gereksinimin imzasını birebir tutturamazsan (`summary(short:)` ya da yazım hatası `summery()`), yazdığın metot ayrı bir metot olur ve gereksinimi varsayılan karşılar. Swift 6.2 bu örneklerde uyarı bile vermez.

**Kural:** Tiplerin özelleştirebilmesini istediğin her şeyi **gereksinim** olarak tanımla. Extension'a özel üyeleri yalnızca kimsenin özelleştirmeyeceği yardımcılar için kullan.

### 5. Generic'ler ve kısıtlar

Generic kod, bir protocol'e uyan **herhangi bir somut tiple** çalışır:

```swift
func totalReadingMinutes<Item: ReadingItem>(of items: [Item]) -> Int {
    items.reduce(0) { $0 + $1.estimatedMinutes }
}

totalReadingMinutes(of: novels)    // Item == Novel
totalReadingMinutes(of: books)     // Item == Book
```

Derleyici her çağrıda `Item`'ın ne olduğunu bilir; kodu o tip için özelleştirebilir (specialization). Kısıtlar extension'lara da yazılabilir; o üye yalnızca kısıt sağlandığında var olur (*koşullu extension*). Standart kütüphane tiplerine de yazılabilir:

```swift
extension Sequence where Element: PagedReadingItem {
    var totalPageCount: Int { reduce(0) { $0 + $1.pageCount } }
}
ReadingSamples.shelfNovels.totalPageCount   // 852: [Novel] sayfalı
// [Magazine]().totalPageCount              → derlenmez: Magazine sayfalı değil
// mixedItems.totalPageCount                → derlenmez: any ReadingItem kutusu protocol'e uymaz
```

Aynı fikir protocol'ün kendi extension'ında:

```swift
extension Shelf where Item: Comparable {
    var sortedItems: [Item] { items.sorted() }
}
// ReadingShelf<Novel>().sortedItems   → derlenir (Novel Comparable)
// ReadingShelf<Book>().sortedItems    → derlenmez (Book Comparable değil)
```

### 6. `associatedtype` ve primary associated type

Bazı protocol'ler bir "yer tutucu tip" ister. Hangi tip olduğuna uyan tip karar verir:

```swift
protocol Shelf<Item> {
    associatedtype Item: ReadingItem
    var items: [Item] { get }
    mutating func add(_ item: Item) -> Bool
}

struct ReadingShelf<Item: ReadingItem & Identifiable>: Shelf { ... }   // Item'ı generic parametre belirliyor
```

`protocol Shelf<Item>` içindeki köşeli parantez, `Item`'ı bir **primary associated type** yapar (Swift 5.7+). Böylece "Novel tutan bir raf" diyebilirsin:

```swift
func makeShelf() -> some Shelf<Novel> { ReadingShelf<Novel>() }
var shelf: any Shelf<Novel> = ReadingShelf<Novel>()
shelf.add(novel)                    // derlenir: Item'ın Novel olduğu biliniyor
let items: [Novel] = shelf.items
```

Ama `Item` belirtilmeden `any Shelf` yazarsan `add(_:)` çağrılamaz; derleyici kutunun içindeki rafın hangi tipi kabul ettiğini bilemez:

```
error: member 'add' cannot be used on value of type 'any Shelf'; consider using a generic constraint instead
```

(Not: `any Shelf<Novel>` gibi kısıtlı existential'ların tip bilgisi çalışma anında gerektiğinde, ör. `[any Shelf<Novel>]` dizisinde ya da `as? any Shelf<Novel>` dönüşümünde, iOS 16+ çalışma anı desteği gerekir; daha eski hedeflerde derleyici "runtime support for parameterized protocol types is only available in iOS 16.0.0 or newer" hatası verir. Bu projenin hedefi iOS 17.)

### 7. `some` ve `any`

İkisi de "bu protocol'e uyan bir tip" demek gibi görünür ama çok farklıdırlar:

| | `some ReadingItem` (opaque) | `any ReadingItem` (existential) |
|---|---|---|
| Somut tip | **Tek ve sabit**; derleyici bilir, sen görmezsin | Değerden değere **değişebilir**; bir "kutu" |
| Tipi kim seçer? | Parametrede çağıran, dönüş tipinde fonksiyon | Kutuya ne konduysa |
| Dispatch | Statik; derleyici özelleştirebilir | Dinamik; çalışma anında kutu açılır |
| Heterojen dizi (`[Novel, Magazine]`) | Olmaz | Olur: `[any ReadingItem]` |
| Maliyet | Yok denecek kadar az | Kutu (3 kelimelik satır içi tampon; sığmayan değerler heap'e taşınır) + dolaylı çağrı |
| associatedtype ilişkileri | Korunur | Üst sınırına silinir (`any Shelf` üzerinde `add` çağrılamaz) |

**Ne zaman hangisi?**
- Varsayılan olarak `some` (ya da `<T: P>` generic) yaz.
- Farklı tipleri **aynı koleksiyonda** tutman ya da tipi çalışma anında değiştirmen gerektiğinde `any`'ye geç.
- `any` **zorunludur**: heterojen koleksiyonlar (`[any ReadingItem]`), bir özelliğin çalışma anında farklı tiplerde değer tutabilmesi (`let bookService: any BookServiceProtocol`).
- `some` **zorunludur** ya da tek çaredir: Bir fonksiyon karmaşık ya da adı yazılamayan bir tip döndürüyorsa (SwiftUI'da `var body: some View`).

**`[any P]` bir generic fonksiyona verilemez:**

```swift
let mixed: [any ReadingItem] = [novel, magazine]
totalReadingMinutes(of: mixed)
// error: type 'any ReadingItem' cannot conform to 'ReadingItem'
```

Kutunun kendisi protocol'e uymaz; generic'e somut bir tip lazım. Bu yüzden projede existential diziler için ayrı bir fonksiyon var: `totalReadingMinutes(ofMixed:)`.

**Tek bir `any` değer ise `some` parametresine verilebilir.** Swift 5.7'den beri kutu otomatik açılır (*implicit existential opening*):

```swift
func readingSummary(for item: some ReadingItem) -> String { ... }

let boxed: any ReadingItem = magazine
readingSummary(for: boxed)   // derlenir: kutu açılır, içindeki Magazine verilir
```

`any` yazmazsan ne olur? Bu projenin derleyicisinde (Swift 6.2, Swift 6 dil modu):
- `associatedtype` ya da `Self` gereksinimi **olmayan** bir protocol için (`let x: ReadingItem`) uyarısız derlenir.
- Olanlar için (`let x: Equatable`, `let s: Shelf`) derlenir ama "use of protocol 'Equatable' as a type must be written 'any Equatable'" **uyarısı** verir.
- `ExistentialAny` upcoming feature açılırsa (Xcode'da `SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES`) ilk durum için de aynı uyarı gelir. Bu derleyicide bu bir uyarı, hata değil.

Uyarıların metni bunun gelecekteki bir dil modunda hata olacağını söylüyor. Her zaman `any` yaz: Kodu okuyan, bunun bir kutu olduğunu ve bir bedeli olduğunu görür. (Bu kuralların hepsi quiz'de derleyiciyle doğrulanıyor; bkz. 12. bölüm.)

Kutunun boyutu: 64-bit'te `MemoryLayout<any ReadingItem>.size == 40` (3 kelimelik değer tamponu + tip bilgisi + bir witness table). Her ek protocol bir witness table daha ekler (`any P & Q` → 48); `Sendable` gibi marker protocol'ler tablo eklemez. `AnyObject`'e bağlı bir protocol'ün existential'ı 16 bayttır: referans + witness table.

### 8. Protocol birleşimi (composition)

`&` ile birden fazla protocol'ü tek bir şart olarak birleştirebilirsin; yeni bir "birleşik protocol" tanımlamana gerek kalmaz:

```swift
struct ReadingShelf<Item: ReadingItem & Identifiable>: Shelf {
    mutating func add(_ item: Item) -> Bool {
        guard !items.contains(where: { $0.id == item.id }) else { return false }   // id, Identifiable'dan
        items.append(item)
        return true
    }
}
```

Aynı sözdizimi `some ReadingItem & Identifiable` ve `any ReadingItem & Identifiable` olarak da kullanılır.

### 9. Standart protocol'ler

Core'daki [Book](../BookShelf/Core/Models/Book.swift) tek satırda beş protocol'e uyar: `Identifiable, Hashable, Codable, Sendable` (Hashable, Equatable'ı da içerir).

| Protocol | Ne sağlar? | Otomatik (synthesized) ne zaman? |
|---|---|---|
| `Equatable` | `==` | Struct/enum'da tüm alanlar `Equatable` ise. Class'ta **asla**; elle yazılır. |
| `Hashable` | `hash(into:)`; `Set`, `Dictionary` anahtarı, diffable data source | Struct/enum'da tüm alanlar `Hashable` ise |
| `Comparable` | `<`, bununla `sorted()`, `min()`, `max()` | Yalnızca enum'larda (ilişkili değerleri yoksa ya da hepsi `Comparable` ise). Struct'ta elle yazılır. |
| `Codable` | JSON vb. ile dönüşüm (`Encodable & Decodable`) | Tüm alanlar `Codable` ise |
| `Identifiable` | `id`; SwiftUI `List`/`ForEach` satırları ayırt eder | Class'larda (`AnyObject`) varsayılan `id` = `ObjectIdentifier(self)` |
| `Sendable` | Concurrency sınırlarını güvenle geçebilme | Modül içi struct/enum'da tüm alanlar `Sendable` ise çıkarılır |
| `CustomStringConvertible` | `description`; `"\(x)"` ve `print(x)` bunu kullanır | Hiçbir zaman |

`Comparable` yazarken `<`'nun `==` ile tutarlı olmasına dikkat et: İki değer için ne `a < b` ne de `b < a` doğruysa, `a == b` de doğru olmalı. Bu yüzden `Novel.<` sadece başlığa değil, eşitlikte yazara ve sayfa sayısına da bakar.

### 10. Protocol ile bağımlılık enjeksiyonu ve test dublörleri

Bu projenin veri katmanı protocol odaklı tasarımın en önemli faydasını gösterir:

```swift
protocol BookServiceProtocol: Sendable {
    func fetchBooks() async throws -> [Book]
    ...
}

struct AppDependencies: Sendable {
    let bookService: any BookServiceProtocol    // somut tipe değil, sözleşmeye bağımlı
}
```

- Uygulamada [LocalBookService](../BookShelf/Core/Services/LocalBookService.swift) verilir (`AppDependencies.makeForLaunch(arguments:)`).
- Testlerde [StubBookService](../BookShelfTests/Support/StubBookService.swift) verilir: Sonucu önceden belirlenmiş, anında cevap veren ya da bilerek hata fırlatan, kaç kez çağrıldığını sayan bir actor.
- Ekran ve view model kodu **hiç değişmez**. `bookService.fetchBooks()` bir gereksinim olduğu için çağrı dinamik dispatch ile o an verilen tipe gider.

Buna *Dependency Inversion* denir: Üst seviye kod (ekran) alt seviye bir ayrıntıya (JSON dosyası, ağ) değil, bir soyutlamaya bağlıdır. Yarın gerçek bir `URLSession` servisi yazarsan sadece `makeForLaunch` değişir.

### 11. Protocol odaklı programlama (POP) ve class kalıtımı

Class kalıtımı:
- **Tek** üst sınıf; bir tip iki hiyerarşiden birden davranış alamaz.
- Üst sınıfın tüm saklanan özelliklerini ve `init` karmaşıklığını devralırsın.
- Yalnızca class'lar kullanabilir; struct ve enum'lar dışarıda kalır.

Protocol'ler:
- Bir tip istediği kadar protocol'e uyabilir; davranışlar küçük parçalar halinde birleştirilir.
- Struct, enum, class ve actor, hepsi uyabilir; değer semantiğinden vazgeçmen gerekmez.
- Var olan tiplere (hatta başka modüllerin tiplerine) sonradan uygunluk eklenebilir.

Yine de ölçülü ol: **Her şey için protocol yazma.** Önce somut tipi yaz; aynı kodu birden fazla tipte tekrarladığını ya da bir bağımlılığı testte değiştirmen gerektiğini gördüğünde protocol'e çıkar.

### 12. Protocol tip olarak: "Olur mu, olmaz mı?" quiz'i

Mülakatlarda sık gelen bir soru biçimi: Ekrana birkaç satır kod konur ve "Bu derlenir mi?" diye sorulur. Uygulamadaki **Mülakat → "Protocol'ü tip olarak kullanmak"** konusunun Demo bölümü tam olarak bu: 16 soru, her birinde "Olur ✓" ya da "Olmaz ✗" dersin, ardından doğru cevap, derleyicinin **birebir** mesajı ve açıklama açılır.

**Tek doğruluk kaynağı.** Örnekler Swift kodunun içine gömülü değil; her biri ayrı bir dosya:
[QuizSnippets/](../BookShelf/Features/Interview/Demos/SwiftBasics/QuizSnippets/quiz-prelude.swift.txt) klasöründe `quiz-NN-ad.swift.txt`. Uygulama bu dosyaları paketten okuyup gösterir; [check-swift-quiz.sh](../scripts/check-swift-quiz.sh) ise **aynı dosyaları** ortak tanımlarla (`quiz-prelude.swift.txt`) birleştirip gerçekten derler ve beklenen sonucu doğrular. Her dosyanın başında şu başlıklar var:

```
// TITLE: İki any Equatable'ı == ile karşılaştırmak
// EXPECT: error: binary operator '==' cannot be applied to two 'any Equatable' operands
// EXPLAIN: == iki tarafın da AYNI somut tip (Self) olmasını ister...
```

`EXPECT` üç biçimde olabilir: `compiles` (uyarısız derlenir), `warning: <mesaj>` (derlenir ama uyarır) ve `error: <mesaj>` (derlenmez). İsteğe bağlı `FLAGS:` satırı derleyici ayarı ekler. Dosya uzantısı bilerek `.swift.txt`: `.swift` olsaydı Xcode bu dosyaları uygulamanın kaynak kodu sanıp derlemeye çalışırdı ve derlenmeyen örnekler uygulamayı da derletmezdi.

```bash
./scripts/check-swift-quiz.sh     # 16 örnek, 0 uyuşmazlık → çıkış kodu 0
```

Derleyici sürümü değişir ve bir mesaj ya da davranış farklılaşırsa betik kırmızıya döner; quiz'i güncellemen gerektiğini söyler. Aşağıdaki tablo bu projenin derleyicisiyle (Swift 6.2, Swift 6 dil modu) doğrulandı:

| # | Kod (özet) | Sonuç | Neden? |
|---|---|---|---|
| 1 | `let items: [any ReadingItem] = [Novel(...), Magazine(...)]` | Derlenir | Heterojen koleksiyon için `any` gerekir |
| 2 | `let value: Equatable = 42` | Derlenir, uyarı verir | Swift 5.7'den beri (SE-0309) mümkün; `any Equatable` yazılmalı ("must be written 'any Equatable'") |
| 3 | `lhs == rhs` (ikisi de `any Equatable`) | Derlenmez | `==` iki tarafın aynı somut tip olmasını ister |
| 4 | `Set<any Hashable>` | Derlenmez | Kutu `Hashable`'a uymaz; çözüm `Set<AnyHashable>` |
| 5 | `-> some ReadingItem`, iki dalda farklı tip | Derlenmez | Opaque tip TEK bir somut tiptir |
| 6 | `-> any ReadingItem`, iki dalda farklı tip | Derlenir | Kutu her tipi taşıyabilir |
| 7 | `describe(boxed)` (`<T: ReadingItem>(_: T)`, `boxed: any ReadingItem`) | Derlenir | Tek değerde kutu otomatik açılır (SE-0352) |
| 8 | `describeAll(items)` (`<T>(_: [T])`, `items: [any ReadingItem]`) | Derlenmez | "type 'any ReadingItem' cannot conform to 'ReadingItem'" |
| 9 | `printSummary(_ item: some ReadingItem)` iki farklı tiple | Derlenir | Parametrede `some` = generic (SE-0341); tipi çağıran seçer |
| 10 | `let shelf: Shelf = NovelShelf()` (associatedtype'lı) | Derlenir, uyarı verir | 5.6 ve öncesinde hataydı; artık `any Shelf` yazılmalı |
| 11 | `shelf.add(...)` (`shelf: any Shelf`) | Derlenmez | `Item` bilinmiyor; Item ALAN üye çağrılamaz |
| 12 | `shelf.add(...)` (`shelf: any Shelf<Novel>`) | Derlenir | Primary associated type ile `Item` sabitlendi (SE-0346, SE-0353) |
| 13 | `ReadingItem.kindName` (static gereksinim) | Derlenmez | Protocol'ün kendisinin uygulaması yok; `type(of: item).kindName` çalışır |
| 14 | `let item: ReadingItem = Novel(...)` | Derlenir (uyarısız) | associatedtype/Self gereksinimi olmayan protocol'de `any` henüz zorunlu değil |
| 15 | Aynı satır, `-enable-upcoming-feature ExistentialAny` ile | Derlenir, uyarı verir | Bu derleyicide ExistentialAny **uyarı** üretir, hata değil |
| 16 | `extension Novel { var rating: Int = 0 }` | Derlenmez | "extensions must not contain stored properties" |

İki not:
- 2, 10 ve 15'teki uyarıların metni "this will be an error in a future Swift language mode" der: Bugün derlenir, ama `any` yazmayı alışkanlık edin.
- Mülakatçı "associatedtype'lı protocol tip olarak kullanılamaz" cevabını bekliyor olabilir. Doğru ve güncel cevap: "Swift 5.6'ya kadar öyleydi. 5.7'den beri `any Shelf` yazılabiliyor; kısıt, `Item` alan üyeleri çağıramamak. `any Shelf<Novel>` ile o da çözülüyor."

### 13. typealias

`typealias` var olan bir tipe **ikinci bir isim** verir. Yeni bir tip **oluşturmaz**: Derleyici için `BookID` ile `Int` birebir aynı tiptir ve çalışma anında alias hiç yoktur (`String(describing: BookID.self)` → `"Int"`). Örneklerin hepsi [TypealiasExamples.swift](../BookShelf/Features/Fundamentals/Typealias/TypealiasExamples.swift) içinde; uygulamada **Mülakat → "typealias nedir?"** konusunun Demo bölümünde.

**Nerede işe yarar?**

```swift
// 1. Closure tipine isim: hem kısalır hem ne işe yaradığını anlatır.
typealias BookFilter = @Sendable (Book) -> Bool

// 2. Protocol birleşimine isim. Apple'ın kendi tanımı da budur:
//    public typealias Codable = Decodable & Encodable
typealias ShelfItem = ReadingItem & Identifiable
func identifiers<Item: ShelfItem>(of items: [Item]) -> [Item.ID] { items.map(\.id) }

// 3. Generic alias
typealias BookMap<Value> = [Book.ID: Value]      // BookMap<Int> == [Int: Int]

// 4. Uzun generic tipi kısaltmak (FavoritesViewController)
typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Book>
typealias DataSource = UITableViewDiffableDataSource<Section, Book>

// 5. associatedtype'ı açıkça karşılamak
struct ClassicsShelf: Shelf {
    typealias Item = Novel          // çoğu zaman gerekmez: add(_ item: Novel)'dan çıkarılır
    ...
}

// 6. Dosya içi kısaltma (StructVsClassView)
private typealias ID = AccessibilityID.Fundamentals.StructVsClass
```

**Tuzak: yeni bir tip değil.** İki alias aynı tipe gidiyorsa birbirinin yerine geçer ve derleyici uyarmaz:

```swift
typealias BookID = Int
typealias MemberID = Int

let member: MemberID = 42
let book: BookID = member        // derlenir ve sessizce yanlış
```

Bir alias'a extension yazmak da aslında alttaki tipi genişletir: `extension BookID { var isEvenID: Bool { ... } }` yazdıktan sonra `7.isEvenID` de derlenir.

Tip güvenliği gerekiyorsa tek alanlı bir **sarmalayıcı struct** yaz. Ayrı bir tiptir; karıştırmak derleme hatasıdır ve bellekte içindeki `Int` kadar (8 bayt) yer kaplar:

```swift
struct LibraryCardNumber: RawRepresentable, Hashable, Sendable {
    let rawValue: Int
}

func cardLabel(for number: LibraryCardNumber) -> String { ... }
cardLabel(for: 42)
// error: cannot convert value of type 'Int' to expected argument type 'LibraryCardNumber'
```

Erişim seviyesi kuralı: Bir alias, gösterdiği tipten daha açık olamaz. `internal` bir tipe `public typealias` yazmak "type alias cannot be declared public because its underlying type uses an internal type" hatasıdır.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [ReadingItem.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift) | `ReadingItem`, `PagedReadingItem` | Gereksinimler, varsayılan uygulamalar, protocol kalıtımı |
| [ReadingItem.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift) | `totalReadingMinutes(of:)`, `totalReadingMinutes(ofMixed:)`, `readingSummary(for:)` | Generic vs existential, `some` parametre, existential açma |
| [ReadingItem.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift) | `ProtocolDispatchDemo` | Statik ve dinamik dispatch tuzağı |
| [ReadingItemTypes.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItemTypes.swift) | `Novel`, `Magazine`, `AudioBook` | Struct'lar ve `final class` aynı protocol'e uyuyor; `Comparable`, `CustomStringConvertible`, elle yazılmış `Equatable` |
| [ReadingItemTypes.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItemTypes.swift) | `extension Book: PagedReadingItem` | Var olan bir tipe sonradan uygunluk |
| [ReadingItemTypes.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItemTypes.swift) | `ReadingSamples.mixedItems`, `ReadingSamples.featuredItem()`, `ReadingSortOrder.sorted(_:)` | `[any ReadingItem]`, opaque dönüş tipi, heterojen sıralama |
| [Shelf.swift](../BookShelf/Features/Fundamentals/Protocols/Shelf.swift) | `Shelf`, `ReadingShelf`, `Shelf.sortedItems` | `associatedtype`, primary associated type, protocol birleşimi, koşullu extension |
| [ProtocolExtensionExamples.swift](../BookShelf/Features/Fundamentals/Protocols/ProtocolExtensionExamples.swift) | `ProtocolDispatchDemo.observe(from:)`, `ProtocolDefaultsDemo`, `Sequence.totalPageCount` | Etkileşimli dispatch, varsayılanların kaynağı, koşullu extension |
| [ProtocolExtensionDemoView.swift](../BookShelf/Features/Interview/Demos/SwiftBasics/ProtocolExtensionDemoView.swift) | `ProtocolExtensionDemoView` | "Protocol + extension" demosu; extension'ın ekleyemediği şeyler ve derleyici mesajları |
| [ProtocolsView.swift](../BookShelf/Features/Fundamentals/Protocols/ProtocolsView.swift) | `ProtocolsView` | Karışık liste (`[any ReadingItem]`) ve raf (`Shelf<Novel>`) ekranı |
| [QuizSnippets/](../BookShelf/Features/Interview/Demos/SwiftBasics/QuizSnippets/quiz-prelude.swift.txt) | `quiz-prelude.swift.txt`, `quiz-NN-*.swift.txt` | Quiz örnekleri: uygulamanın gösterdiği ve betiğin derlediği tek kaynak |
| [check-swift-quiz.sh](../scripts/check-swift-quiz.sh) | `typecheck` | Her örneği gerçekten derleyip beklenen sonucu ve mesajı doğrular |
| [SwiftQuizSnippet.swift](../BookShelf/Features/Interview/Demos/SwiftBasics/SwiftQuizSnippet.swift), [SwiftQuizSession.swift](../BookShelf/Features/Interview/Demos/SwiftBasics/SwiftQuizSession.swift) | `SwiftQuizParser`, `SwiftQuizLibrary`, `SwiftQuizSession` | Dosya biçimi, paketten okuma, skor mantığı |
| [TypealiasExamples.swift](../BookShelf/Features/Fundamentals/Typealias/TypealiasExamples.swift) | `TypealiasExamples` | Closure, birleşim ve generic alias'lar; `BookID`/`MemberID` tuzağı; `LibraryCardNumber` sarmalayıcısı |
| [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) | `FavoritesViewController.Snapshot`, `DataSource` | Gerçek kodda uzun generic tipleri kısaltan typealias'lar |
| [BookServiceProtocol.swift](../BookShelf/Core/Services/BookServiceProtocol.swift) | `BookServiceProtocol` | Protocol ile bağımlılık enjeksiyonu |
| [AppDependencies.swift](../BookShelf/App/AppDependencies.swift) | `AppDependencies.makeForLaunch(arguments:)` | Somut servisin seçildiği tek yer |
| [StubBookService.swift](../BookShelfTests/Support/StubBookService.swift) | `StubBookService` | Test dublörü: aynı protocol'e uyan sahte servis |
| [Book.swift](../BookShelf/Core/Models/Book.swift) | `Book` | `Identifiable`, `Hashable`, `Codable`, `Sendable` |
| [FundamentalsProtocolTests.swift](../BookShelfTests/Fundamentals/FundamentalsProtocolTests.swift), [FundamentalsShelfTests.swift](../BookShelfTests/Fundamentals/FundamentalsShelfTests.swift) | `FundamentalsProtocolTests`, `FundamentalsShelfTests` | Varsayılanlar, dispatch, generic toplam, sıralama, raf davranışı |
| [FundamentalsProtocolExtensionTests.swift](../BookShelfTests/Fundamentals/FundamentalsProtocolExtensionTests.swift), [FundamentalsSwiftQuizTests.swift](../BookShelfTests/Fundamentals/FundamentalsSwiftQuizTests.swift), [FundamentalsTypealiasTests.swift](../BookShelfTests/Fundamentals/FundamentalsTypealiasTests.swift) | `FundamentalsProtocolExtensionTests`, `FundamentalsSwiftQuizTests`, `FundamentalsTypealiasTests` | Dispatch bakış açıları, quiz dosyaları ve skor, typealias'ın aynı tip olması |
| [SwiftBasicsUITests.swift](../BookShelfUITests/SwiftBasicsUITests.swift) | `SwiftBasicsUITests` | Quiz, dispatch ve typealias demolarının UI testleri |

## Sık yapılan hatalar

**1. Özelleştirilmesi gereken bir üyeyi sadece extension'da tanımlamak.**

```swift
// YANLIŞ: Magazine'in shelfSection'ı any/generic üzerinden asla çağrılmaz.
protocol ReadingItem { var title: String { get } }
extension ReadingItem { var shelfSection: String { "Genel raf" } }

// DOĞRU: Gereksinim yap, varsayılanı extension'da ver.
protocol ReadingItem {
    var title: String { get }
    var shelfSection: String { get }
}
extension ReadingItem { var shelfSection: String { "Genel raf" } }
```

**2. Class kalıtımında varsayılan uygulamayı "ezdiğini" sanmak.**

```swift
protocol Greeter { func greet() -> String }
extension Greeter { func greet() -> String { "varsayılan" } }

class Base: Greeter {}                                    // varsayılanı kullanıyor
class Sub: Base { func greet() -> String { "alt sınıf" } }

let greeter: any Greeter = Sub()
greeter.greet()    // "varsayılan"! Uygunluk Base'e ait ve Base varsayılanı seçmişti.

// DOĞRU: Uygulamayı üst sınıfta yaz, alt sınıfta override et.
class Base: Greeter { func greet() -> String { "temel" } }
class Sub: Base { override func greet() -> String { "alt sınıf" } }
```

**3. `[any P]`'yi generic bir fonksiyona vermeye çalışmak.**

```swift
// YANLIŞ: "type 'any ReadingItem' cannot conform to 'ReadingItem'"
totalReadingMinutes(of: mixedItems)

// DOĞRU: Existential diziler için ayrı bir fonksiyon (ya da homojen bir dizi kullan).
totalReadingMinutes(ofMixed: mixedItems)
```

**4. Her yerde `any` kullanmak.**

```swift
// YANLIŞ: Gereksiz kutu ve dinamik çağrı; associatedtype ilişkileri kaybolur.
func describe(_ item: any ReadingItem) -> String { item.title }

// DOĞRU: Tek bir tip yeterliyse some.
func describe(_ item: some ReadingItem) -> String { item.title }
```

**5. Bir protocol'ü extension ile başka bir protocol'e uydurmaya çalışmak.**

```swift
// YANLIŞ: "extension of protocol 'ReadingItem' cannot have an inheritance clause"
extension ReadingItem: CustomStringConvertible { ... }

// DOĞRU: Protocol'ün kendisi miras alsın ya da tipler tek tek uysun.
protocol ReadingItem: CustomStringConvertible { ... }
```

**6. `<`'yu `==` ile tutarsız yazmak.**

```swift
// YANLIŞ: Aynı başlıklı iki farklı roman ne küçük ne büyük, ama eşit de değil.
static func < (lhs: Novel, rhs: Novel) -> Bool { lhs.title < rhs.title }

// DOĞRU: Eşitlik hangi alanlara bakıyorsa sıralama da onlara baksın.
static func < (lhs: Novel, rhs: Novel) -> Bool {
    (lhs.title, lhs.author, lhs.pageCount) < (rhs.title, rhs.author, rhs.pageCount)
}
```

(Projedeki `Novel` metinleri Türkçe alfabe kurallarıyla karşılaştırmak için `TurkishCollation` kullanır; tuple karşılaştırması ise fikri kısaca gösteriyor.)

**7. typealias'ı yeni bir tip sanmak.**

```swift
// YANLIŞ: İki "farklı" kimlik aslında aynı tip; karıştırınca derleyici uyarmaz.
typealias BookID = Int
typealias MemberID = Int
func loadBook(id: BookID) { ... }
loadBook(id: member.id)          // derlenir!

// DOĞRU: Ayrı bir tip istiyorsan sarmalayıcı struct yaz.
struct BookID: Hashable { let rawValue: Int }
```

## Mülakatta sorulabilecekler

**1. Protocol extension'daki bir metot ile protocol gereksinimi arasındaki fark nedir?**
Gereksinim dinamik dispatch ile çağrılır; uyan tipin kendi uygulaması, değişken `any P` ya da generic olsa bile çalışır. Sadece extension'da tanımlı metot statik dispatch ile çağrılır; derleme anındaki tip protocol ise extension'daki uygulama çalışır, tipin aynı isimli metodu yalnızca onu gölgeler.

**2. `some` ile `any` arasındaki fark nedir?**
`some P` tek, sabit, derleyicinin bildiği bir somut tiptir (opaque); statik dispatch ve özelleştirme mümkündür. `any P` herhangi bir uyan tipi tutabilen bir kutudur (existential); tip çalışma anında belli olur, çağrılar dinamiktir, bir maliyeti vardır. Varsayılan `some`; heterojen koleksiyon ya da çalışma anında değişen tip gerekince `any`.

**3. `associatedtype` nedir? Neden `any Shelf` üzerinde `add` çağrılamaz?**
Protocol içindeki, somut değerini uyan tipin belirlediği bir yer tutucu tiptir. `any Shelf`'te kutunun içindeki rafın `Item`'ı bilinmediği için `Item` alan bir metoda ne verileceği denetlenemez. Primary associated type ile `any Shelf<Novel>` yazınca `Item` sabitlenir ve çağrı mümkün olur.

**4. Protocol odaklı programlamanın class kalıtımına göre avantajları neler?**
Bir tip birden çok protocol'e uyabilir; struct ve enum'lar da katılır, böylece değer semantiği korunur; var olan tiplere sonradan uygunluk eklenebilir; üst sınıfın saklanan özelliklerini ve `init` zincirini devralmak gerekmez.

**5. Protocol'ler test yazmayı nasıl kolaylaştırır?**
Kod somut bir tipe değil protocol'e bağımlı olursa, testte aynı protocol'e uyan sahte bir tip (stub, mock, spy) verilebilir. Bu projede ekranlar `any BookServiceProtocol`'e bağlıdır; testlerde `StubBookService` sonuçları ve hataları kontrol eder, çağrı sayılarını kaydeder.

**6. `Equatable` ve `Hashable` ne zaman otomatik gelir?**
Struct ve enum'larda tüm saklanan alanlar (ya da ilişkili değerler) uyuyorsa, uygunluğu yazman yeterlidir; derleyici `==` ve `hash(into:)`'u üretir. Class'larda üretilmez. İlişkili değeri olmayan enum'lar `Hashable`'ı hiçbir şey yazmadan alır.

**7. Retroactive conformance nedir, ne zaman riskli?**
Bir tipe, tanımlandığı yerin dışında bir extension ile protocol uygunluğu eklemektir. Hem tip hem protocol başka modüllerden geliyorsa risklidir: O modüllerden biri ileride aynı uygunluğu eklerse iki uygulama çakışır. Swift 6 bunun için uyarır; bilerek yapıyorsan `@retroactive` yazarsın.

**8. `any P` bir değeri `some P` bekleyen fonksiyona verilebilir mi?**
Tek bir değer olarak evet: Swift 5.7'den beri existential otomatik açılır. Ama `[any P]` dizisi `[some P]` ya da `[T] where T: P` bekleyen fonksiyona verilemez; kutunun kendisi protocol'e uymaz.

**9. İki `any Equatable`'ı neden `==` ile karşılaştıramazsın?**
`==` iki tarafın aynı somut tip (`Self`) olmasını ister; iki kutunun içinde farklı tipler olabilir. Derleyici: "binary operator '==' cannot be applied to two 'any Equatable' operands". Çözüm aynı tipi zorunlu kılan generic bir fonksiyon: `func isSame<T: Equatable>(_ a: T, _ b: T) -> Bool`. Heterojen bir kümeye ihtiyaç varsa `AnyHashable`.

**10. `let x: Equatable = 42` derlenir mi?**
Swift 5.6 ve öncesinde derlenmezdi ("yalnızca generic kısıt olarak kullanılabilir"). Swift 5.7'den beri (SE-0309) her protocol existential olabilir; bu projenin derleyicisi (Swift 6.2) satırı derler ama `any Equatable` yazılmasını isteyen bir uyarı verir. Kutu ise pek işe yaramaz: `==` bile çağrılamaz.

**11. typealias yeni bir tip oluşturur mu?**
Hayır; var olan tipe ikinci bir isim verir. `typealias BookID = Int` ile `typealias MemberID = Int` birbirinin yerine geçer ve derleyici uyarmaz; alias'a yazılan extension da aslında `Int`'i genişletir. Tip güvenliği için tek alanlı sarmalayıcı struct yazılır.

**12. typealias ile associatedtype farkı nedir?**
`associatedtype` protocol içindeki bir yer tutucudur; gerçek tipi uyan tip belirler. `typealias` her zaman belli bir tipe takma addır. Uyan tipin içindeki `typealias Item = Novel`, associatedtype'ı açıkça karşılamanın yoludur; çoğu zaman derleyici bunu imzalardan kendisi çıkarır.

## Alıştırmalar

**1. `shelfSection`'ı gereksinim yap ve farkı gör.**
`shelfSection`'ı `ReadingItem` protocol'üne gereksinim olarak ekle (varsayılanı extension'da kalsın). Uygulamada **Dispatch** bölümünün nasıl değiştiğini gör, sonra `FundamentalsProtocolTests.testExtensionOnlyMemberIsStaticallyDispatched` testini yeni davranışa göre güncelle.
*İpucu:* Değişiklikten sonra `viaExistential` ve `viaGeneric` de "Süreli yayınlar" döndürmeli. Test adını da yeni davranışı anlatacak şekilde değiştir.

**2. Raf için generic bir "en uzun öğe" fonksiyonu yaz.**
`func longestItem<S: Shelf>(on shelf: S) -> S.Item?` yaz ve hem `ReadingShelf<Novel>` hem `ReadingShelf<Book>` ile test et. Ardından aynı fonksiyonu `some Shelf` parametresiyle yazmayı dene.
*İpucu:* `shelf.items.max(by:)` ile `estimatedMinutes` karşılaştır. `some Shelf` sürümünde dönüş tipini yazamayacağını fark edeceksin: Parametrenin tipine isim veremediğin için `S.Item` diyemezsin. Generic parametre burada neden gerekli, düşün.

**3. Bir dekoratör servis yaz.**
`BookServiceProtocol`'e uyan ve başka bir servisi saran bir `CountingBookService` yaz: Her `fetchBooks()` çağrısını sayıp asıl servise iletsin. `StubBookService` ile sarıp çağrı sayısını test et.
*İpucu:* Protocol'ün metotları `mutating` olmadığı için bir struct kendi `var` sayacını bu metotların içinde artıramaz; sıradan bir class ise değiştirilebilir alanı yüzünden `Sendable` olamaz. Ya tipi bir `actor` yap (`StubBookService` gibi) ya da sayacı ayrı bir actor'de tutan bir struct yaz. Sarılan servis `let wrapped: any BookServiceProtocol` olabilir.

**4. Quiz'e yeni bir soru ekle.**
`QuizSnippets/` klasörüne `quiz-17-...swift.txt` adında bir dosya ekle: `weak var delegate: ReadingItem?` (protocol class'a bağlı değilken `weak` kullanmak). Önce cevabı tahmin et, `EXPECT` satırını yaz ve `./scripts/check-swift-quiz.sh` çalıştır. Sonra `FundamentalsSwiftQuizTests`'teki soru sayısını güncelle.
*İpucu:* Bu satır derlenmez: `weak` yalnızca class'lara uygulanabilir, `ReadingItem`'a ise struct'lar da uyabilir. Mesajı betiğin çıktısından kopyala; tahmin etme. Düzeltmesi `protocol ReadingItem: AnyObject`.

**5. typealias'ı sarmalayıcı struct'a çevir.**
`TypealiasExamples.BookID`'yi `struct BookID: Hashable, Sendable { let rawValue: Int }` yap. Derleyicinin hangi satırlarda hata verdiğine bak (`bookID(mistakenlyFrom:)` artık derlenmeyecek) ve testleri yeni davranışa göre güncelle.
*İpucu:* Hatalar, typealias'ın gizlediği karışıklıkların tam listesidir. `ExpressibleByIntegerLiteral`'a uyarsan `let id: BookID = 42` yazmaya devam edebilirsin; ama o zaman "42 hangi tip?" sorusu yine bulanıklaşır. Bu bir tasarım kararı.
