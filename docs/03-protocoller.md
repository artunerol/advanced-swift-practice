# Protocol'ler ve Protocol Odaklı Programlama

## Neden önemli?

Swift'te soyutlamanın ana aracı class kalıtımı değil **protocol**'lerdir. Standart kütüphane baştan sona protocol'ler üzerine kuruludur (`Equatable`, `Collection`, `Codable`, `Sendable`...), SwiftUI'daki her view bir `View` protocol'üne uyar ve bağımlılık enjeksiyonu (dependency injection) ile test edilebilir kod yazmanın en yaygın yolu protocol'lerdir.

Bu derste şunları öğreneceksin: protocol tanımlamak ve uymak, extension ile varsayılan davranış eklemek, statik/dinamik dispatch tuzağı, `associatedtype` ve generic'ler, `some` ile `any` farkı, protocol birleşimi, standart protocol'ler ve protocol ile bağımlılık enjeksiyonu.

Uygulamada **Temeller → Protocol'ler** ekranındaki üç bölüm (Liste, Raf, Dispatch) bu dersin canlı halidir.

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

Generic bir fonksiyon içinde de aynısı olur: `func f(_ x: some ReadingItem) { x.shelfSection }` her zaman `"Genel raf"` döndürür. Uygulamadaki **Dispatch** bölümü bu dört durumu yan yana gösterir.

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

Derleyici her çağrıda `Item`'ın ne olduğunu bilir; kodu o tip için özelleştirebilir (specialization). Kısıtlar extension'lara da yazılabilir; o üye yalnızca kısıt sağlandığında var olur:

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

(Not: `any Shelf<Novel>` gibi kısıtlı existential'lar çalışma anı desteği ister; iOS 16 ve sonrasında kullanılabilir. Bu projenin hedefi iOS 17.)

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

Swift 6 dil modunda `any` kelimesini yazmak hâlâ zorunlu değildir (`let x: ReadingItem` de derlenir), ama her zaman yazmak iyi bir alışkanlıktır: Kodu okuyan, bunun bir kutu olduğunu ve bir bedeli olduğunu görür.

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
| [ProtocolsView.swift](../BookShelf/Features/Fundamentals/Protocols/ProtocolsView.swift) | `ProtocolsView` | Karışık liste, raf ve dispatch ekranı |
| [BookServiceProtocol.swift](../BookShelf/Core/Services/BookServiceProtocol.swift) | `BookServiceProtocol` | Protocol ile bağımlılık enjeksiyonu |
| [AppDependencies.swift](../BookShelf/App/AppDependencies.swift) | `AppDependencies.makeForLaunch(arguments:)` | Somut servisin seçildiği tek yer |
| [StubBookService.swift](../BookShelfTests/Support/StubBookService.swift) | `StubBookService` | Test dublörü: aynı protocol'e uyan sahte servis |
| [Book.swift](../BookShelf/Core/Models/Book.swift) | `Book` | `Identifiable`, `Hashable`, `Codable`, `Sendable` |
| [FundamentalsProtocolTests.swift](../BookShelfTests/Fundamentals/FundamentalsProtocolTests.swift), [FundamentalsShelfTests.swift](../BookShelfTests/Fundamentals/FundamentalsShelfTests.swift) | `FundamentalsProtocolTests`, `FundamentalsShelfTests` | Varsayılanlar, dispatch, generic toplam, sıralama, raf davranışı |

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
