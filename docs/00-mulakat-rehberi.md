# Mülakat Rehberi: 14 Soru + 2 Bonus

**Buradan başla.** Bu rehber projedeki her şeyi tek bir sıraya dizer: soru → 30 saniyelik cevap → ek sorular → tuzaklar → koda bakılacak yer → demo. Uygulamadaki **Mülakat** sekmesi aynı içeriğin cep sürümüdür; her sorunun uygulama içi metni [`BookShelf/Features/Interview/Topics/`](../BookShelf/Features/Interview/Topics/) altında, kendi dosyasındadır. Bir konuyu derinlemesine öğrenmek istersen her bölümün sonundaki ders bağlantısına git.

Rehberdeki dil ve SDK iddiaları bu projenin araçlarıyla denendi: Xcode 26.3, Swift 6.2.4, Swift 6 dil modu, iOS 17 hedefi. "Derlenir mi?" cevapları [`scripts/check-swift-quiz.sh`](../scripts/check-swift-quiz.sh) ile gerçekten derlenerek doğrulanır.

## İçindekiler

- [Nasıl kullanılır?](#nasil-kullanilir) · [5 günlük plan](#plan) · [Mülakat günü: 10 dakikalık tekrar](#son-10-dakika)
- **Swift:** [1. Protocol + extension](#soru-01) · [2. Protocol tip olarak (derlenir mi?)](#soru-02) · [3. Struct vs class, stack vs heap](#soru-03)
- **UIKit:** [4. UIViewController yaşam döngüsü](#soru-04) · [5. Dinamik (self-sizing) hücre](#soru-05) · [6. frame vs bounds](#soru-06) · [7. UITableView vs UICollectionView](#soru-07)
- **Swift:** [8. typealias](#soru-08)
- **Süreç:** [9. CI/CD](#soru-09)
- **Mimari:** [10. Clean Architecture, VIPER, MVVM](#soru-10) · [11. Dependency Inversion vs Injection](#soru-11)
- **Veri:** [12. Kalıcılık](#soru-12)
- **Bellek:** [13. ARC ve retain cycle](#soru-13) · [14. Delegate: kim kimi tutar?](#soru-14)
- **Bonus:** [Swift Concurrency](#bonus-concurrency) · [Objective-C interop](#bonus-objc)

<a id="nasil-kullanilir"></a>
## Nasıl kullanılır?

### Uygulamada

1. Simülatörde çalıştır (⌘R) ve alttaki **Mülakat** sekmesine geç. Sorular bölümlere ayrılmış; üstteki arama kutusu soruda, bölüm adında ve kısa cevapta arar.
2. Bir soruya dokun. Üstteki seçicide üç bölüm var:
   - **Cevap:** 30 saniyelik cevap, ek sorular ve tuzaklar.
   - **Demo:** Canlı örnek. Bölüm değişince demo sıfırdan kurulur (UIKit demolarında `viewDidLoad` yeniden çalışır).
   - **Kod:** Hangi dosya, hangi sembol, neye bakmalı. Kopyala düğmesi dosya adını panoya alır. Xcode'da ⇧⌘O ile dosyayı aç, ⌃6 ile sembolü bul.
3. Konuyu bitirince sağ üstteki ✓ ile "çalışıldı" diye işaretle (ya da listede satırı sağa kaydır). Merkezdeki ilerleme çubuğu güncellenir.

### Bu rehberle

Her soru için aynı dört adım (20-30 dakika):

1. **Söyle.** "30 saniyelik cevap"ı oku, sonra kapat ve sesli, kendi cümlelerinle söyle. Süre tut; 45 saniyeyi geçiyorsa kısalt.
2. **Savun.** "Derinleşirse" sorularını, cevaplarına bakmadan cevaplamayı dene.
3. **Gör.** Demo'yu aç. Bir şeyi değiştirmeden önce sonucu tahmin et, sonra kontrol et.
4. **Göster.** "Koda bak"taki dosyayı Xcode'da aç ve yanındaki soruyu kendi cümlenle cevapla. Mülakatta "bunu bir projede şöyle yaptım" diyebileceğin somut örnek burası.

Cevabı şu iskeletle kur: **tanım → neden → projeden örnek → tuzak.** Mülakatçılar ek soruyu genelde tuzaktan çıkarır; tuzağı sen söylersen sohbeti sen yönetirsin. Bir de dürüstlük kuralı: "Bu projede yaptım" ile "nasıl yapıldığını biliyorum" cümlelerini ayır. Bu ayrım özellikle CI/CD sorusunda önemli.

<a id="plan"></a>
## 5 günlük çalışma planı

Günde yaklaşık 2 saat. Her günün sonunda, o günün sorularını uygulamadan rastgele seçip sesli cevapla.

| Gün | Sorular | Demo'da mutlaka yap | Günün sonunda kendine sor |
|---|---|---|---|
| 1 · Swift dili | [1](#soru-01), [2](#soru-02), [3](#soru-03), [8](#soru-08) | 16 soruluk "derlenir mi?" quiz'ini bitir. Struct vs Class → Bellek'te adresleri karşılaştır. | `some` ile `any` farkını iki cümlede söyleyebiliyor muyum? "Struct stack'te" cümlesini nasıl düzeltirim? |
| 2 · Bellek ve sahiplik | [13](#soru-13), [14](#soru-14) | Sızıntı laboratuvarındaki 5 senaryonun ikişer sürümünü aç-kapat. Delegate → Sahiplik deneyini çalıştır. | Delegate neden `weak`, neden `unowned` değil? `[weak self]` hangi closure'da gerekmez? |
| 3 · UIKit | [4](#soru-04), [5](#soru-05), [6](#soru-06), [7](#soru-07) | Yaşam döngüsü günlüğünde PageSheet ile FullScreen'i karşılaştır. frame/bounds'ta 45° döndür. Hücre aç/kapa. | `viewDidLayoutSubviews`'a ne konur, ne konmaz? Döndürülmüş bir view'ın frame'i neden güvenilmez? |
| 4 · Mimari ve veri | [10](#soru-10), [11](#soru-11), [12](#soru-12) | VIPER'da not ekle, MVVM'e geç. Depo seçicisini değiştir. DI sayaçlarını izle. | DIP ile DI farkını bir örnekle anlatabiliyor muyum? Token'ı neden UserDefaults'a koymam? |
| 5 · Süreç ve prova | [9](#soru-09), [bonuslar](#bonus-concurrency) | CI/CD demosunda gerçekten yaptıklarını işaretle, cevap taslağını oku. | Rastgele 6 soruyu süre tutarak cevapla; takıldıklarının ✓ işaretini kaldır ve yarın tekrar et. |

<a id="son-10-dakika"></a>
## Mülakat günü: 10 dakikalık tekrar

Her satır, o sorunun "mutlaka söylenecek" cümlesi. Hepsini sesli oku.

- [ ] **1 · Protocol + extension:** Gereksinim bir özelleştirme noktasıdır, tipin uygulaması `any`/generic üzerinden de çalışır; yalnızca extension'da olan üye statik çağrılır, tipteki aynı adlı üye onu gölgeler.
- [ ] **2 · Protocol tip olarak:** `some` = derleme anında tek bir somut tip, `any` = kutu (64-bit'te 40 bayt, dinamik çağrı). `[any P]` generic `[T]`'ye gitmez, tek `any` değer gider (kutu açılır).
- [ ] **3 · Struct vs class:** Struct kopyalanır, class paylaşılır. "Struct stack'te" yarı doğru: Struct bulunduğu yerde satır içi saklanır; class örneği heap'te ve referans sayılır.
- [ ] **4 · Yaşam döngüsü:** `viewDidLoad` bir kez; `viewDidLayoutSubviews` belirsiz sayıda, oraya ucuz ve tekrar çalıştırılabilir geometri işi. Sheet, alttaki ekranın disappear'ını tetiklemez.
- [ ] **5 · Dinamik hücre:** `automaticDimension` + tahmin + contentView'da yukarıdan aşağı kesintisiz constraint zinciri; yükseklik değişince `performBatchUpdates(nil)`.
- [ ] **6 · frame vs bounds:** frame üst view'ın koordinatlarında, bounds kendi koordinatlarında. Transform bounds'u ve center'ı değiştirmez; `contentOffset == bounds.origin`.
- [ ] **7 · Table vs collection:** Dikey liste → table; ızgara, yatay bölüm, karışık yerleşim → collection view. iOS 14+ list configuration ile collection view tablo da olur.
- [ ] **8 · typealias:** Yeni tip oluşturmaz, yalnızca isim verir; tip güvenliği gerekiyorsa tek alanlı struct.
- [ ] **9 · CI/CD:** CI = her değişiklikte otomatik derleme ve test. Continuous Delivery'de yayın kararı insanda, Deployment'ta otomatik. Yapmadığın şeyi yapmış gibi anlatma.
- [ ] **10 · Mimari:** MVVM/VIPER sunumu böler, Clean bütün uygulamanın bağımlılık yönünü belirler: oklar domain'e bakar.
- [ ] **11 · DIP vs DI:** DIP ilke (soyutlamanın sahibi üst katman), DI teknik (bağımlılığı dışarıdan al). Somut sınıf enjekte etmek DI'dır ama DIP değildir.
- [ ] **12 · Kalıcılık:** Tercih → UserDefaults, sır → Keychain, belge → dosya, ilişkili ve sorgulanan veri → Core Data/SwiftData. Managed object thread'ler arasında taşınmaz; `NSManagedObjectID` taşınır.
- [ ] **13 · ARC:** Güçlü referans sayımı, GC yok; döngüyü ARC bulamaz, geri oku `weak` (ölebilir) ya da `unowned` (ömür garantili) yaparım.
- [ ] **14 · Delegate:** Kalıtım yok. Sahip olan, uzun yaşayan taraf delegate olur; sahip olunan taraf protokolü tanımlar ve delegate'ini `weak` tutar.
- [ ] **Bonus · Concurrency:** Actor data race'i önler, race condition'ı önlemez (reentrancy). `async` "arka plan" demek değildir; yeri izolasyon belirler.
- [ ] **Bonus · ObjC:** Köprü başlığı ObjC'yi Swift'e, `-Swift.h` Swift'i ObjC'ye açar; nullability işaretleri Optional'ı belirler.

---

<a id="soru-01"></a>
## 1. Protocol + extension

> **Soru:** "Protocol ile extension'ı birlikte nasıl kullanırsın? Varsayılan uygulama ne demek?"

### 30 saniyelik cevap

> "Protocol bir sözleşme: Bir tipin hangi özelliklere ve metotlara sahip olacağını söyler; struct, enum, class ve actor uyabilir. Protocol extension'ı ise uyan bütün tiplere ortak davranış ekler. Bir gereksinimin gövdesini extension'a yazarsam bu onun varsayılan uygulaması olur; tip isterse kendi uygulamasını yazar. Kritik ayrım dispatch'te: Gereksinim bir özelleştirme noktasıdır ve witness table üzerinden çağrılır, yani tipin kendi uygulaması `any` ya da generic üzerinden de çalışır. Yalnızca extension'da olan bir metot ise statik çağrılır; tipte aynı adlı bir metot onu ezmez, gölgeler. Ayrıca `where` ile koşullu extension yazar, var olan bir tipe kaynağına dokunmadan uygunluk eklerim. Extension'ın yapamadığı en önemli şey saklanan özellik (stored property) eklemek."

### Derinleşirse

- **Swift'te "optional" gereksinim var mı?** Saf Swift protocol'lerinde yok. Yalnızca `@objc protocol` içinde `@objc optional func` var; UIKit delegate'lerinin optional metotları bunlardır ve onları yalnızca class'lar uygulayabilir. Swift'teki karşılığı varsayılan uygulamadır.
- **Bir class protocol'e uyuyor ve varsayılanı kullanıyor. Alt sınıf aynı metodu yazarsa ne olur?** Uygunluk üst sınıfa aittir ve witness table'a varsayılan yazılmıştır. Alt sınıfın metodu `any P` ya da generic üzerinden çağrılmaz. Bu proje için derleyiciyle denendi: `any` üzerinden "default", generic üzerinden "default", doğrudan `Sub()` üzerinden "sub". Çözüm: Metodu üst sınıfın kendisinde yaz, alt sınıfta `override` et.
- **Extension neden saklanan özellik ekleyemez?** Tipin bellek düzeni (alanları, boyutu) tanımında sabitlenir; başka bir dosyadaki ya da modüldeki extension bunu değiştiremez. Derleyici `extensions must not contain stored properties` der. Gerekirse protocol'e `{ get }` gereksinimi konur, saklamayı uyan tip yapar.
- **Retroactive conformance nedir, `@retroactive` ne zaman gerekir?** Bir tipe tanımlandığı yerin dışında uygunluk eklemektir (`extension Book: PagedReadingItem`). Hem tip hem protocol başka modüllerdense (`extension Date: Identifiable`) derleyici uyarır, çünkü o modüllerden biri aynı uygunluğu ileride ekleyebilir. Bilerek yapıyorsan `@retroactive` yazarsın.
- **Protocol + extension mı, class kalıtımı mı?** Kalıtım tek üst sınıf demektir, yalnızca class'larda vardır ve saklanan özellikleriyle birlikte gelir. Protocol ile davranışı küçük parçalar halinde struct'lara da veririm, bir tip birden çok protocol'e uyabilir. Ortak saklanan durum ya da UIKit gibi bir class hiyerarşisi gerekiyorsa kalıtım seçerim.

### Tuzaklar

- Özelleştirilmesi beklenen bir üyeyi yalnızca extension'a yazmak: Tipin kendi uygulaması `any` ya da generic üzerinden hiç çağrılmaz.
- Gereksinimin imzasını tutturamamak (`summery()` yazım hatası, fazladan bir parametre): Tipin metodu ayrı bir metot olur, gereksinimi varsayılan karşılar. Swift 6.2 bu durumda uyarı bile vermez.
- Tek bir somut tip varken protocol + extension yazmak: Yalnızca dolaylılık ekler.

### Koda bak

1. [ReadingItem.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift) → `extension ReadingItem`: `symbolName` bir gereksinim ve varsayılanı var; `shelfSection` ise yalnızca extension'da. İkisinin yorumlarını yan yana oku.
2. [ReadingItem.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift) → `ProtocolDispatchDemo`: Aynı `Magazine` üç farklı "gözle" okunuyor. Kendine sor: `Magazine` iki üyeyi de kendisi yazmış; `any ReadingItem` üzerinden hangisinin sonucu değişiyor, neden?
3. [ReadingItemTypes.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItemTypes.swift) → `extension Book: PagedReadingItem`: Retroactive conformance. `Book`'un kaynağına dokunulmadı; eksik olan tek gereksinim `kindName`.
4. [Shelf.swift](../BookShelf/Features/Fundamentals/Protocols/Shelf.swift) → `extension Shelf where Item: Comparable`: Koşullu extension. `sortedItems`, `ReadingShelf<Novel>`'da var, `ReadingShelf<Book>`'ta yok.

### Demo

Mülakat → "Protocol ve extension birlikte nasıl kullanılır?" → **Demo**. **Dispatch** bölümünde "Derleme anındaki tip" seçicisini değiştir: Kod aynı, yalnızca değişkenin tipi değişiyor; `shelfSection` sonucu değişir, `symbolName` değişmez. Sonra **Varsayılan** ve **Koşullu** bölümlerine geç.

Ders: [03 Protocol'ler](03-protocoller.md) (§3-4, §11).

---

<a id="soru-02"></a>
## 2. Protocol tip olarak: "Bu derlenir mi?"

> **Soru:** Mülakatçı kısa kod parçaları gösterir ve sorar: "Bu olur mu, olmaz mı?" Konu `any`, `some`, generic ve `associatedtype`.

### 30 saniyelik cevap

> "Bir protocol'ü üç şekilde tip gibi kullanırım. Birincisi generic kısıt ya da parametrede `some P`: Derleme anında belli, tek bir somut tip; kutu yok, derleyici kodu o tipe özelleştirebilir ve `associatedtype` ilişkileri korunur. İkincisi dönüşte `some P`: Tipi fonksiyon seçer ve her yoldan aynı tipi döndürmek zorundadır; SwiftUI'daki `some View` gibi. Üçüncüsü `any P`, yani existential bir kutu: İçine çalışma anında herhangi bir uyan tip girer. Heterojen bir dizi için gerekir ama bedeli var: 64-bit'te 40 baytlık kutu, dinamik çağrı ve `associatedtype`'ın silinmesi. Kutunun kendisi protocol'e uymaz; bu yüzden `[any P]`'yi generic `[T]` bekleyen fonksiyona veremem, ama tek bir `any` değeri verebilirim, derleyici kutuyu açar. Varsayılan tercihim `some`; farklı tipleri bir arada saklamam gerekirse `any`."

### Olur mu, olmaz mı? (16 örnek, derleyiciyle doğrulandı)

Ortak tanımlar [quiz-prelude.swift.txt](../BookShelf/Features/Interview/Demos/SwiftBasics/QuizSnippets/quiz-prelude.swift.txt) içinde: `ReadingItem` (`static var kindName`, `title`, `summary()`), ona uyan `Novel` ve `Magazine`, `protocol Shelf<Item>` ve `describe<T: ReadingItem>(_:)`, `describeAll<T: ReadingItem>(_: [T])`. ✓ = derlenir, ⚠ = uyarıyla derlenir, ✗ = derlenmez.

| # | Kod | Sonuç | Neden |
|---|---|---|---|
| 1 | `let items: [any ReadingItem] = [Novel(...), Magazine(...)]` | ✓ | Farklı tipleri tutmanın yolu: her eleman bir kutu. |
| 2 | `let value: Equatable = 42` | ⚠ | `any Equatable` Swift 5.7 (SE-0309) ile mümkün oldu. Bu derleyici `any`'siz hali derler ama uyarır; uyarı, gelecekteki bir dil modunda hata olacağını söylüyor. |
| 3 | `lhs == rhs` (ikisi de `any Equatable`) | ✗ | `==` iki tarafın aynı somut tip (`Self`) olmasını ister; kutularda farklı tipler olabilir. |
| 4 | `let tags: Set<any Hashable> = [...]` | ✗ | Kutu `Hashable`'a uymaz. Çözüm: `Set<AnyHashable>`. |
| 5 | `-> some ReadingItem`, iki dalda `Novel` ve `Magazine` döndürmek | ✗ | Opaque tip tek bir somut tiptir: "do not have matching underlying types". |
| 6 | Aynısı `-> any ReadingItem` ile | ✓ | Kutu her iki tipi de taşıyabilir. |
| 7 | `describe(boxed)` (`boxed: any ReadingItem`) | ✓ | Tek değerde kutu otomatik açılır (SE-0352). |
| 8 | `describeAll(items)` (`items: [any ReadingItem]`) | ✗ | Dizi açılmaz; `'any ReadingItem' cannot conform to 'ReadingItem'`. |
| 9 | `func printSummary(_ item: some ReadingItem)`, iki farklı tiple çağırmak | ✓ | Parametrede `some` = generic; tipi her çağrıda çağıran seçer. |
| 10 | `let shelf: Shelf = NovelShelf()` | ⚠ | `associatedtype`'lı protocol de existential olabilir; `any Shelf` yazılmalı. |
| 11 | `var shelf: any Shelf` ve `shelf.add(...)` | ✗ | `Item` bilinmiyor; `Item` **alan** üye çağrılamaz. |
| 12 | `var shelf: any Shelf<Novel>` ve `shelf.add(...)` | ✓ | Primary associated type ile `Item` sabitlendi (SE-0346, SE-0353). |
| 13 | `ReadingItem.kindName` | ✗ | Protocol'ün kendi uygulaması yok. `Novel.kindName`, `T.kindName` ya da `type(of: item).kindName` olur. |
| 14 | `let item: ReadingItem = Novel(...)` | ✓ | `Self`/`associatedtype` gereksinimi olmayan protocol'de `any` hâlâ zorunlu değil; uyarı da yok. |
| 15 | Aynı satır, `ExistentialAny` açıkken | ⚠ | Upcoming feature; her `any`'siz existential için uyarı. |
| 16 | `extension Novel { var rating: Int = 0 }` | ✗ | Extension saklanan özellik ekleyemez. |

**Ezber tuzağı:** 2 ve 10'un klasik cevabı "olmaz"dı; bu Swift 5.6 ve öncesi için doğruydu. Mülakatçı eski cevabı bekliyor olabilir. Şöyle söyle: "Swift 5.6 ve öncesinde derlenmezdi, bu protocol'ler yalnızca generic kısıt olabiliyordu. Swift 5.7'den beri `any Equatable` diye bir existential var; Swift 6.2 `any`'siz hali uyarıyla derliyor, doğrusu `any` yazmak."

### Derinleşirse

- **`MemoryLayout<any ReadingItem>.size` kaç?** 64-bit'te 40 bayt: 3 kelimelik değer tamponu (24) + tip bilgisi (8) + witness table (8). Her ek protocol bir tablo daha ekler (`any P & Q` = 48); `Sendable` gibi marker protocol'ler eklemez. `AnyObject`'e bağlı bir protocol'ün kutusu 16 bayttır (referans + tablo). Tampona sığmayan değer heap'e taşınır.
- **`any` kutusu hiç kendi protocol'üne uymaz mı?** Genel kural bu, bilinen istisna `any Error`: `Error`'a uyar, bu yüzden `[any Error]` generic `[E: Error]` bekleyen bir fonksiyona verilebilir (derleyiciyle denendi).
- **`func f(_ x: some P)` ile `func f<T: P>(_ x: T)` farkı?** Anlam olarak aynı (SE-0341). Fark yazımda: `some`'ın gizli generic parametresine isim veremezsin; "iki parametre aynı tip olsun" ya da "aynı tipi döndür" diyemezsin, bunun için `<T>` gerekir.
- **`[any P]`'yi neden generic fonksiyona veremem ama tek değeri verebilirim?** Tek değerde derleyici kutuyu açıp içindeki gerçek tipi `T` yapar. Dizide her kutu farklı tip taşıyabilir, tek bir `T` bulunamaz. Çözüm: `items.map { describe($0) }` ya da existential dizi alan ayrı bir fonksiyon.
- **`any` üzerinden `Item` döndüren üyeler kullanılabilir mi?** Evet; sonuç üst sınıra silinir (`any Shelf`'te `items` → `[Any]`). Kısıt yalnızca `Item` **alan** üyelerde.

### Tuzaklar

- Her yerde `any` kullanmak: Gereksiz kutu ve dinamik çağrı; `associatedtype` ilişkileri kaybolur. Önce `some`/generic dene.
- "`associatedtype`'lı protocol tip olarak kullanılamaz" demek: Swift 5.6 ve öncesi için doğruydu. Bugün `any Shelf` yazılabilir; kısıt `Item` alan üyeleri çağırmakta.
- `-> some P` ile farklı yollardan farklı tipler döndürmeye çalışmak.

### Koda bak

1. [quiz-prelude.swift.txt](../BookShelf/Features/Interview/Demos/SwiftBasics/QuizSnippets/quiz-prelude.swift.txt) → `Shelf`: `protocol Shelf<Item>` satırındaki `<Item>` primary associated type.
2. [check-swift-quiz.sh](../scripts/check-swift-quiz.sh) → `typecheck`: Her örneği prelude ile birleştirip gerçekten derliyor; beklenen sonuç tutmazsa CI kırmızı olur.
3. [ReadingItem.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift) → `totalReadingMinutes(ofMixed:)`: Generic sürüm `[any ReadingItem]` kabul etmediği için existential diziye ayrı bir fonksiyon gerekiyor.
4. [ReadingItemTypes.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItemTypes.swift) → `ReadingSamples.featuredItem()`: Opaque dönüş tipi; hep `Novel` döner ama çağıran yalnızca `some ReadingItem` görür.
5. [AppDependencies.swift](../BookShelf/App/AppDependencies.swift) → `AppDependencies`: `any BookServiceProtocol`; çalışma anında gerçek servis ya da test dublörü tutulacağı için existential.

### Demo

Mülakat → "Protocol'ü tip olarak kullanmak" → **Demo**: 16 soruluk quiz. Her soruda önce **Olur ✓** ya da **Olmaz ✗** de, sonra derleyicinin birebir mesajını ve açıklamayı oku. Aynı örnekleri terminalde gerçekten derlemek için: `make quiz`.

Ders: [03 Protocol'ler](03-protocoller.md) (§5-7, §12).

---

<a id="soru-03"></a>
## 3. Struct vs class (ve stack vs heap)

> **Soru:** "Struct ile class arasındaki fark nedir?" Ardından sık gelen kayma: "Peki bellekte nerede duruyorlar? Stack mi, heap mi?"

Strateji: Önce **semantiği** anlat (kopya mı, paylaşım mı), sonra **depolamayı**; "struct her zaman stack'te" yanlışını mülakatçıdan önce sen düzelt.

### 30 saniyelik cevap

> "Struct değer tipidir: Atamada ve parametre geçişinde bağımsız bir kopya oluşur. Class referans tipidir: Kopyalanan şey adres; iki değişken aynı nesneyi paylaşır. Class'ta kalıtım, kimlik yani `===`, ARC ve deinit var; struct'ta otomatik memberwise init, `mutating` ve `let` ile tam değişmezlik var. Bellek tarafında class örnekleri heap'te ayrılır ve referans sayılır. Struct ise bulunduğu yerde satır içi saklanır: Yerel bir değişkense genelde stack'te ya da register'da, ama bir class'ın alanıysa ya da bir dizinin elemanıysa heap'te. Yani 'struct stack'te' yarı doğru; Swift'in garantisi depolama yeri değil, semantik. Bu yüzden class daha pahalıdır: heap ayırma, atomik retain/release, dolaylı erişim. Varsayılanım struct; kimlik ya da paylaşılan değiştirilebilir durum gerekiyorsa class, o durum thread'ler arasında paylaşılacaksa actor."

### Derinleşirse

- **Struct'lar her zaman stack'te mi?** Hayır. Class'ın alanıysa heap'teki nesnenin içinde, `Array` elemanıysa dizinin heap deposunda durur. Kaçan (escaping) bir closure'ın yakaladığı `var` heap'te bir kutuya taşınır; `any P` kutusunun 3 kelimelik tamponuna sığmayan değer de heap'e konur. Tersine, optimize edici fonksiyondan kaçmayan bazı class nesnelerini stack'e alabilir.
- **Struct her atamada kopyalanıyorsa büyük bir `Array`'i fonksiyona vermek pahalı değil mi?** Değil: `Array`, `String`, `Dictionary` ve `Set` copy-on-write kullanır. Kopyalamak yalnızca heap'teki depo referansını kopyalar (`MemoryLayout<[Int]>.size == 8`). Biri değiştirmek isteyince depo paylaşılıyor mu diye bakılır ve gerekirse o anda kopyalanır. Kendi yazdığın struct otomatik olarak CoW değildir.
- **Struct'ın içinde bir class tutarsan?** Struct kopyalanır ama class alanı aynı nesneyi gösterir: Kopyalar o nesneyi paylaşır, değer semantiği bozulur ve her kopyada o referans için retain/release yapılır. Çözüm: class'ı değişmez yapmak ya da CoW uygulamak (`PageHistory`).
- **Thread güvenliği açısından fark?** Kopyalanan bir değeri iki thread paylaşmaz. Alanları `Sendable` olan bir struct, `public` değilse kendiliğinden `Sendable` olur (`public` tipte açıkça yazılır). Değiştirilebilir alanı olan bir class iki thread'den aynı anda değiştirilebilir; Swift 6 bunu derleme anında engeller. Paylaşılan değiştirilebilir durum için actor.
- **`MemoryLayout` ile ne görürsün?** Satır içi boyut: tek `Int`'lik struct 8, class referansı 8 (nesne ne kadar büyük olursa olsun), `[Int]` 8, `String` 16, `any ReadingItem` 40 bayt. `size` ile `stride` farkı hizalamadan gelir: `Int` + `Bool` → size 9, stride 16.

### Tuzaklar

- Yalnızca "struct stack'te, class heap'te" deyip semantik farkı (kopya vs paylaşım) hiç söylememek.
- `let` ile tutulan bir class örneğini değişmez sanmak: `let` yalnızca referansı sabitler, nesnenin `var` alanları değişebilir.
- Class alanı olan bir struct'ın tam değer semantiğine sahip olduğunu sanmak.
- Kalıtım gerekmediği halde `final` yazmamak: Gereksiz dinamik dispatch.

### Koda bak

1. [Bookmark.swift](../BookShelf/Features/Fundamentals/StructVsClass/Bookmark.swift) → `CopySemanticsDemo.init`: İki satır aynı görünüyor (`= original`); biri değeri, diğeri adresi kopyalıyor.
2. [MemoryLayoutDemo.swift](../BookShelf/Features/Fundamentals/StructVsClass/MemoryLayoutDemo.swift) → `MemoryAddressDemo`: İki struct kopyası farklı adreste, aynı nesneyi gösteren iki referans aynı adreste. Önce dosyanın başındaki stack/heap notunu oku.
3. [MemoryLayoutDemo.swift](../BookShelf/Features/Fundamentals/StructVsClass/MemoryLayoutDemo.swift) → `MemoryLayoutDemo`: Rakamların kaynağı.
4. [PageHistory.swift](../BookShelf/Features/Fundamentals/StructVsClass/PageHistory.swift) → `PageHistory.record(_:)`: Elle copy-on-write; `isKnownUniquelyReferenced` ile depo yalnızca paylaşılıyorsa kopyalanıyor.
5. [FavoritesStore.swift](../BookShelf/Core/Stores/FavoritesStore.swift) → `FavoritesStore`: Paylaşılan değiştirilebilir durum için class + kilit yerine actor.

### Demo

Mülakat → "Struct ile class arasındaki fark nedir?" → **Demo**. **Kopyalama**: "Kopyayı değiştir"e bas; struct'ta orijinal yerinde kalır, class'ta ikisi birlikte ilerler. **CoW**: "Kopyaya sayfa ekle"; ilk yazmada depo ayrılır. **Bellek**: "Yeniden ölç"; adresleri ve `MemoryLayout` değerlerini karşılaştır.

Ders: [02 Struct vs Class](02-struct-vs-class.md) (§1, §4-5).

---

<a id="soru-04"></a>
## 4. UIViewController yaşam döngüsü

> **Soru:** "View controller'ın yaşam döngüsünü anlatır mısın? `viewDidLayoutSubviews` ne zaman çağrılır, oraya ne koyarsın?"

### 30 saniyelik cevap

> "Sıra şöyle: `init`, `loadView`, `viewDidLoad`; sonra her görünüşte `viewWillAppear`, `viewIsAppearing`, layout çifti ve `viewDidAppear`; kaybolurken `viewWillDisappear` ve `viewDidDisappear`; en sonda `deinit`. `viewDidLoad` bir kez çalışır; alt view, constraint, delegate gibi tek seferlik kurulum oraya. Ama boyutlar orada henüz kesin değil. `viewWillLayoutSubviews` / `viewDidLayoutSubviews` ise kök view'ın `layoutSubviews`'u her çalıştığında gelir: ilk yerleşim, döndürme, boyut değişimi, `setNeedsLayout`. Kaç kez geleceği belli olmadığı için `viewDidLayoutSubviews`'a ucuz ve tekrar çalıştırılabilir geometri işi koyarım; orada kök view'ın alt view'larının frame'leri kesindir. Görünüşe bağlı güncelleme için iOS 17 SDK'sıyla gelen `viewIsAppearing` daha doğru yer. Dinleyicileri `viewWillAppear`'da başlatıp `viewDidDisappear`'da durdururum. Bilinen bir tuzak da var: Sheet ile sunulan ekran, alttaki ekranın disappear metotlarını tetiklemez."

### Derinleşirse

- **`viewDidLayoutSubviews`'a ne konmaz?** Ağır hesap, ağ isteği, bir kez yapılacak kurulum ve yeniden layout tetikleyen değişiklikler (constraint eklemek, her seferinde farklı değer atamak): Sonsuz layout döngüsüne girebilir. Metot defalarca çağrılsa da sonuç aynı olmalı (idempotent); değeri yalnızca gerçekten değiştiyse güncelle.
- **`viewDidLayoutSubviews` çağrıldıysa bütün alt view'lar yerleşmiş midir?** Hayır. Yalnızca VC'nin kök view'ının `layoutSubviews`'u bitmiştir: Kök view'ın bounds'u ve doğrudan alt view'larının frame'leri kesindir. Daha derindeki view'lar kendi `layoutSubviews`'unda yerleşir. Derin bir view'ın geometrisi gerekiyorsa o view'ın kendi `layoutSubviews`'unu kullan ya da önce `layoutIfNeeded()` çağır.
- **`setNeedsLayout` ile `layoutIfNeeded` farkı?** `setNeedsLayout()` yalnızca "bir sonraki çizimden önce yeniden yerleştir" diye işaretler; ucuzdur. `layoutIfNeeded()` işaret varsa yerleşimi hemen ve senkron yapar (constraint değişikliğini animasyon bloğunda uygulamanın klasik yolu). İkisi de yalnızca layout çiftini tetikler; `viewDidLoad` tekrar çalışmaz.
- **`loadView` ile `viewDidLoad` farkı?** `loadView` kök view'ı oluşturur; override edersen `super` çağırmadan `view = ...` atarsın. `viewDidLoad` view oluştuktan sonraki kurulum içindir. `vc.view`'a ilk erişim yüklemeyi tetikler; `init` içinde `view`'a dokunmak onu erkenden yükler.
- **Sheet kapanınca alttaki ekranı nasıl tazelersin?** Sheet'te (`.pageSheet`/`.formSheet`, iOS 13+ varsayılanı) ve `.overFullScreen`'de alttaki view pencereden kaldırılmaz, bu yüzden appear/disappear gelmez. Sunulan ekran bir delegate ya da closure ile haber verir. Kullanıcının aşağı kaydırarak kapatması için `presentationController?.delegate` + `presentationControllerDidDismiss(_:)`; bu metot programatik `dismiss` sonrası çağrılmaz.
- **Child VC nasıl eklenir?** `addChild(child)` → `view.addSubview(child.view)` + constraint → `child.didMove(toParent: self)`. Çıkarırken `child.willMove(toParent: nil)` → `removeFromSuperview()` → `removeFromParent()`.
- **Döndürme ve trait değişimi?** Boyut için `viewWillTransition(to:with:)`; trait'ler (koyu mod, size class, yazı boyutu) için iOS 17+ `registerForTraitChanges(_:handler:)`. `traitCollectionDidChange` iOS 17'de deprecated oldu.
- **Güncel bilgi:** iOS 26 SDK'sında `updateProperties()` geldi: Bir sonraki layout geçişiyle birlikte çalışır, `setNeedsUpdateProperties()` ile istenir. Mülakatta bilmen beklenmez ama "takip ediyorum" göstergesidir.

### Tuzaklar

- Boyuta bağlı hesapları (köşe yarıçapı, frame'e göre konum) `viewDidLoad`'da yapmak.
- `viewDidLayoutSubviews`'a bir kez yapılacak işi ya da yeniden layout tetikleyen kodu koymak.
- Override ederken `super`'i çağırmamak (istisna: kendi kök view'ını kuran `loadView`).
- Sheet kapanınca alttaki ekranın `viewWillAppear`'ının çalışacağını varsaymak.

### Koda bak

1. [LoggingViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LoggingViewController.swift) → `viewDidLayoutSubviews()` ve diğer override'lar: Her biri önce `super`'i çağırıp olayı günlüğe yazıyor. `loadView`'da neden `super` yok? `deinit` günlüğe neden doğrudan değil, `Task` ile yazıyor?
2. [LifecycleSubjectViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LifecycleSubjectViewController.swift) → `makeModal(style:)`: `.pageSheet` ile `.fullScreen` arasındaki tek fark bu satır; günlükteki fark Ana'nın disappear çağrıları.
3. Aynı dosya → `relayout()`: `setNeedsLayout()` + `layoutIfNeeded()` yalnızca layout çiftini tetikliyor. `toggleChild()`: containment sırası.
4. [FrameBoundsViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift) → `viewDidLayoutSubviews()`: Geometriye bağlı iş tam burada; `convert(_:to:)` doğru sonucu ancak yerleşimden sonra verir.
5. [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) → `viewWillAppear(_:)` / `viewDidDisappear(_:)`: Gerçek ekranda dinlemeyi görünüşte başlat, ekran gerçekten kaybolunca durdur.

### Demo

Mülakat → "UIViewController yaşam döngüsünü anlatır mısın?" → **Demo**. Üstte gözlenen "Ana" ekranı, altta canlı günlük var.

1. İlk açılış sırasını günlükten oku.
2. **setNeedsLayout + layoutIfNeeded**: Yalnızca `viewWillLayoutSubviews` / `viewDidLayoutSubviews` gelir.
3. **PageSheet sun**, sonra kapat: Ana'ya disappear/appear gelmez. **FullScreen sun**, sonra kapat: gelir.
4. **Child ekle** ve tekrar dokunarak çıkar: containment sırası.
5. Simülatörü döndür (⌘→): layout çifti ve `viewWillTransition` gelir.

Ders: [07 UIKit](07-uikit.md) (§2, gözlenen sıra dahil).

---

<a id="soru-05"></a>
## 5. UITableView'da dinamik (self-sizing) hücre

> **Soru:** "İçeriğine göre yüksekliği değişen hücreyi nasıl yaparsın?"

### 30 saniyelik cevap

> "Tabloda `rowHeight = UITableView.automaticDimension` ve gerçeğe yakın bir `estimatedRowHeight`; ikisi de bugün varsayılan olarak automatic ama açıkça yazarım. Hücrede alt view'ları `contentView`'a ekler, constraint'leri yukarıdan aşağı kesintisiz bağlarım: üst kenar, label'lar, alt kenar. Yüksekliği Auto Layout bu zincirden hesaplar. Çok satırlı label'da `numberOfLines = 0`; Dynamic Type için `preferredFont(forTextStyle:)` ve `adjustsFontForContentSizeCategory`. Hücreyi register edip `cellForRowAt` içinde `dequeueReusableCell(withIdentifier:for:)` ile alır ve her alanını baştan ayarlarım; açık/kapalı gibi durum hücrede değil, modelde durur. Yükseklik çalışırken değişirse görünen hücreyi güncelleyip `performBatchUpdates(nil)` çağırırım; tablo yükseklikleri animasyonla yeniden sorar."

### Derinleşirse

- **Tek tabloda farklı tipte hücreler?** Satırları ilişkili değerli bir enum ile modelle (`case author(...)`, `case book(Book)`); her hücre sınıfını kendi reuse identifier'ıyla register et, `cellForRowAt` içinde enum'a göre switch et.
- **`reloadRows(at:with:)` ile `performBatchUpdates(nil)` farkı?** `reloadRows` hücreyi yeniden yapılandırır (`cellForRowAt` tekrar çağrılır, çapraz geçiş animasyonu olur, hücrenin geçici durumu kaybolur). Boş batch update veriye dokunmaz; tablo yalnızca yükseklikleri yeniden sorar. İçerik değiştiyse `reloadRows` ya da diffable'da `reconfigureItems`. (`beginUpdates`/`endUpdates` eski yöntemdir; SDK başlığı yerine `performBatchUpdates`'i öneriyor.)
- **`estimatedRowHeight` neden var?** Tablo ekran dışındaki satırları ölçmeden içerik boyutunu tahminle hesaplar; gerçek yükseklik hücre ekrana gelirken ölçülür. Tahmin gerçeğe ne kadar yakınsa kaydırma çubuğu o kadar az zıplar. 0 vermek tahmini kapatır.
- **Konsolda `UIView-Encapsulated-Layout-Height` çakışması?** Tablonun ölçmeden önce verdiği geçici yükseklik, senin zorunlu (1000) dikey zincirinle çakışıyor. Zincirdeki bir constraint'in (genellikle alttakinin) önceliğini 999 yapmak çakışmayı giderir.
- **Modern alternatif?** Diffable data source + `UIListContentConfiguration` (bu projede Favoriler ekranı). Self-sizing aynı kurallarla çalışır.

### Tuzaklar

- Dikey constraint zincirini eksik bırakmak (ör. alt kenara bağlamamak): Hücre tahmini yükseklikte kalır ya da içerik üst üste biner.
- Alt view'ları `contentView` yerine doğrudan hücreye eklemek.
- `heightForRowAt`'te sabit bir değer döndürmek: O satırlarda `automaticDimension` devre dışı kalır.
- Açık/kapalı gibi durumu hücrede saklamak: Hücre yeniden kullanılınca durum başka satıra geçer.

### Koda bak

1. [DynamicCellsViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/DynamicCellsViewController.swift) → `configureTableView()`: `register`, `rowHeight`, `estimatedRowHeight`.
2. Aynı dosya → `tableView(_:cellForRowAt:)`: Enum satır modeli, iki reuse identifier.
3. Aynı dosya → `toggleBook(at:)`: Durum VC'de (`expandedBookIDs`); hücre yerinde güncellenip `performBatchUpdates(nil)` çağrılıyor. Neden `reloadRows` değil?
4. [BookSummaryCell.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/BookSummaryCell.swift) → `configureLayout()`: `contentView`'a üstten alta zincir; alt constraint'in önceliği neden 999? `prepareForReuse()`: yalnızca geçici durumu sıfırlıyor.
5. [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) → `makeDataSource(for:)`: Aynı işin diffable + content configuration hali.

### Demo

Mülakat → "UITableView'da dinamik yükseklikli hücre" → **Demo**. Bir kitap satırına dokun: Açıklama açılır, yükseklik animasyonla değişir. Açık bir satırı ekran dışına kaydırıp geri getir: Durum korunur, çünkü hücrede değil kitap kimliğinde tutuluyor. Bonus: Xcode'un hata ayıklama çubuğundaki Environment Overrides ile yazı boyutunu büyüt; hücreler içeriğe göre büyür.

Ders: [07 UIKit](07-uikit.md) (§3, §9).

---

<a id="soru-06"></a>
## 6. frame vs bounds

> **Soru:** "frame ile bounds arasındaki fark nedir?"

### 30 saniyelik cevap

> "frame, view'ın üst view'ın (superview) koordinat sistemindeki dikdörtgeni: 'Babamın içinde neredeyim, ne kadar yer kaplıyorum?' bounds ise view'ın kendi koordinat sistemindeki dikdörtgeni: origin genelde (0, 0), size view'ın kendi boyutu; alt view'lar bu sisteme göre yerleşir. İki önemli fark var. Birincisi transform: Döndürünce ya da ölçekleyince bounds ve center değişmez; frame ise dönmüş view'ı saran eksen hizalı kutuya döner ve Apple dönüşmüş view'da frame'e güvenmememizi söyler, bounds ve center kullanılır. İkincisi bounds.origin: Onu değiştirince alt view'lar ekranda kayar ama frame'leri aynı kalır. UIScrollView tam olarak böyle kaydırır; contentOffset aslında bounds.origin. Koordinat sistemleri arasında geçiş için `convert(_:to:)` kullanırım."

### Derinleşirse

- **100×100'lük view'ı 45° döndürürsen?** bounds 100×100 kalır, center değişmez. frame yaklaşık 141×141 olur (100·√2). Dikdörtgende kenarlar (w + h)·√2/2 olur.
- **Transform hangi nokta etrafında uygulanır?** Katmanın `anchorPoint`'i etrafında (varsayılan orta nokta). center üst view'ın koordinatlarındadır ve anchorPoint'in konumudur; bu yüzden döndürünce yerinde kalır.
- **View'ın ekrandaki konumu?** `view.convert(view.bounds, to: nil)` pencere koordinatlarını verir. Bunu yerleşimden sonra (ör. `viewDidLayoutSubviews`) yap.
- **Auto Layout kullanan bir view'ın frame'ini elle değiştirirsem?** Bir sonraki layout geçişinde constraint'ler frame'i yeniden hesaplar, değişiklik kaybolur. Constraint'in sabitini değiştir.

### Tuzaklar

- Döndürülmüş ya da ölçeklenmiş bir view'ın frame'ine güvenmek veya frame'e değer atamak. SDK başlığı (`UIView.h`) açıkça yazar: "do not use frame if view is transformed".
- `child.frame = parent.frame` yazmak: Alt view'ın frame'i üstün **bounds**'una göredir; doğrusu `parent.bounds`.
- frame/bounds değerlerine `viewDidLoad`'da güvenmek.

### Koda bak

1. [FrameBoundsViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift) → `configureGeometry()`: child, frame ile değil bounds + center ile konumlanıyor. Neden?
2. Aynı dosya → `apply()`: transform değişince frame büyüyor, bounds/center aynı kalıyor; `container.bounds.origin` değişince child kayıyor ama frame'i değişmiyor.
3. Aynı dosya → `scrollViewDidScroll(_:)`: Sayfanın kendi scroll view'ında `contentOffset.y` ile `bounds.origin.y` hep eşit.
4. [FrameBoundsTests.swift](../BookShelfTests/UIKitLabs/FrameBoundsTests.swift) → `testRotating45DegreesGrowsFrameButNotBounds()`: √2 hesabının testle kanıtı.

### Demo

Mülakat → "frame ile bounds arasındaki fark nedir?" → **Demo**. Mavi kutu child (bounds 120×80), turuncu kesikli çerçeve `child.frame`.

1. Döndürmeyi 45°'ye getir: frame yaklaşık 141×141'e büyür, bounds 120×80 kalır.
2. Ölçeği değiştir: frame değişir, bounds değişmez.
3. `container.bounds.origin.y` kaydırıcısını oynat: child ekranda kayar ama frame değerleri aynı kalır.
4. Sayfayı kaydır: Alttaki satırda `contentOffset.y == bounds.origin.y`.

Ders: [07 UIKit](07-uikit.md) (§10).

---

<a id="soru-07"></a>
## 7. UITableView mı, UICollectionView mı?

> **Soru:** "Hangisini ne zaman kullanırsın?"

### 30 saniyelik cevap

> "UITableView tek sütunlu dikey listeler için: kaydırma eylemleri, düzenleme, bölüm başlıkları hazır gelir; ayar ekranları, mesaj listeleri gibi. UICollectionView'da yerleşimi bir layout nesnesi belirler: ızgara, yatay kayan bölümler, kartlar, her bölümü farklı yerleşimli ekranlar. Compositional layout'la tek bir bölümü `orthogonalScrollingBehavior` ile yana kaydırabilirim; bunu tabloda yapamam. iOS 14'ten beri list configuration ile collection view tablo gibi de davranabiliyor; Apple bunu liste kurmanın modern yolu olarak tanıttı ama UITableView deprecated değil. Veri tarafı ikisinde aynı: diffable data source ve snapshot. Kararım: Sadece dikey bir liste ve mevcut tablo kodu varsa table; ızgara, yatay bölüm ya da değişmesi muhtemel bir tasarım varsa collection view."

### Derinleşirse

- **Compositional layout'un parçaları?** İçten dışa: item → group (item'ları yatay/dikey dizer) → section (kendi kaydırma davranışı ve başlığı olabilir) → layout. Boyutlar `.fractionalWidth`, `.absolute` ya da `.estimated` (self-sizing). Section provider her bölüm için farklı yerleşim döndürebilir.
- **Aynı kitabı iki bölümde göstermek neden sorun?** Item kimlikleri bütün snapshot'ta benzersiz olmalı; aynı kimlik ikinci kez eklenirse çalışma anında hata alırsın. Çözüm: Bölümü de içeren bir kimlik tipi (`GridItem(section:bookID:)`).
- **`CellRegistration`'ın avantajı ve nerede oluşturulmalı?** Hücre ve öğe tipi generic parametredir: string reuse identifier ve `as!` yok. Cell provider kapanışının **dışında** bir kez oluşturulmalı; içinde oluşturmak yeniden kullanımı engeller ve iOS 15+ istisna fırlatır.
- **SwiftUI karşılıkları?** `List` ≈ table/list configuration, `LazyVGrid`/`LazyHGrid` ≈ ızgara, `ScrollView(.horizontal)` + `LazyHStack` ≈ yatay bölüm.

### Tuzaklar

- `CellRegistration`'ı cell provider'ın içinde oluşturmak.
- Snapshot'ta aynı item kimliğini iki kez kullanmak.
- Izgara için tablo hücresine collection view gömmek; ya da tersine basit bir ayar listesi için özel layout yazmak.

### Koda bak

1. [TableVsCollectionViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionViewController.swift) → `makeTableDataSource(_:books:)` ve `makeListDataSource(_:books:)`: Aynı veri; biri string identifier ile, diğeri kapanışın dışında oluşturulan `CellRegistration` ile.
2. Aynı dosya → `GridItem`: Aynı kitap iki bölümde; kimliğe bölümü katarak snapshot'ta benzersiz kalıyor.
3. [TableVsCollectionLayouts.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionLayouts.swift) → `list()`: Collection view'ı tabloya dönüştüren list configuration. `featuredSection()`: `orthogonalScrollingBehavior`.

### Demo

Mülakat → "UITableView mı UICollectionView mı?" → **Demo**. Üstteki **Tablo / Liste / Izgara** seçicisi: Aynı kitaplar üç farklı görünümde. Izgara'da üstteki öne çıkanlar bölümünü yana kaydır; sayfa dikey kaymaya devam eder.

Ders: [07 UIKit](07-uikit.md) (§3, §11).

---

<a id="soru-08"></a>
## 8. typealias

> **Soru:** "typealias nedir, nerede kullanırsın?"

### 30 saniyelik cevap

> "typealias var olan bir tipe ikinci bir isim verir; yeni bir tip oluşturmaz. Derleyici için `BookID` ile `Int` birebir aynı tiptir. Üç yerde işe yarar: Uzun closure tiplerine anlamlı bir isim, ör. `typealias BookFilter = @Sendable (Book) -> Bool`; protocol birleşimlerine isim, Apple'ın `Codable`'ı da aslında `Decodable & Encodable` için bir typealias; ve uzun generic tipleri kısaltmak, ör. diffable data source'un `Snapshot`'ı. Uyan tipte `typealias Item = Novel` yazarak bir `associatedtype`'ı açıkça da karşılayabilirim. Tuzağı: `UserID` ve `BookID` ikisi de `Int` ise birbirine karışır ve derleyici uyarmaz; tip güvenliği istiyorsam tek alanlı bir struct yazarım."

### Derinleşirse

- **typealias ile `associatedtype` farkı?** `associatedtype` protocol içindeki bir yer tutucudur, gerçek tipi uyan tip belirler. typealias her zaman belli bir tipe takma addır.
- **`typealias BookID = Int` için `extension BookID { ... }` yazarsam?** Aslında `Int`'i genişletmiş olursun; projedeki bütün `Int`'ler o üyeyi alır.
- **Swift'te "newtype" var mı?** Yok; tek alanlı bir struct yazılır (çoğu zaman `Hashable`, `Codable` ile). Ayrı bir tiptir, `Int` beklenen yere verilemez; bellekte içindeki `Int` kadar (8 bayt) yer kaplar.
- **Erişim seviyesi?** Alias, gösterdiği tipten daha açık olamaz: `internal` bir tipe `public typealias` yazmak hatadır. Tersi serbest: `private typealias ID = ...` gibi dosya içi kısaltmalar yaygındır.

### Tuzaklar

- typealias'ı tip güvenliği sanmak.
- Her şeye alias vermek: Okuyan, gerçek tipi görmek için tanıma atlamak zorunda kalır.
- Bir alias'a extension yazıp aslında alttaki tipi genişlettiğini fark etmemek.

### Koda bak

1. [TypealiasExamples.swift](../BookShelf/Features/Fundamentals/Typealias/TypealiasExamples.swift) → `TypealiasExamples`: Altı kullanım bir arada; hepsi neden bir enum'un içinde?
2. Aynı dosya → `TypealiasExamples.LibraryCardNumber`: Alias'ların aksine ayrı bir tip; `Int` ile karıştırmak derleme hatası.
3. [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) → `Snapshot` ve `DataSource`: Gerçek kullanım.
4. [StructVsClassView.swift](../BookShelf/Features/Fundamentals/StructVsClass/StructVsClassView.swift) → `private typealias ID`: Uzun iç içe adı yalnızca bu dosyada kısaltıyor.

### Demo

Mülakat → "typealias nedir?" → **Demo**. Süzgeç seçicisini değiştir (closure alias'ı). "aslında: ..." satırlarında alias'ların çalışma anında hiç görünmediğine bak. En alttaki bölüm tuzağı gösteriyor.

Ders: [03 Protocol'ler](03-protocoller.md) (§13).

---

<a id="soru-09"></a>
## 9. CI/CD: "Çalıştın mı, nelerle çalıştın?"

> **Soru:** "CI/CD ile çalıştın mı? Hangi araçları kullandın?"

Bu soru bilgi kadar **dürüstlüğü** ölçer: Mülakatçı söylediğin her aracı bir ek soruyla yoklar. Aşağıdaki cevap bu depoda gerçekten çalışan parçalara dayanır; kendi iş deneyimine göre değiştir ve yapmadığın bir şeyi yapmış gibi anlatma.

### 30 saniyelik cevap

> "Evet. CI'ı her push ve PR'da temiz bir makinede otomatik derleme ve test olarak kurarım; amaç ana dalın her an derlenir ve testleri geçer halde olması. Kendi projemde GitHub Actions kullandım: macOS runner'da hızlı bir kontrol adımı, sonra `build-for-testing` ile bir kez derleme, ardından birim ve UI testlerini yeniden derlemeden koşturma. Sonuç paketleri (.xcresult) her durumda artifact olarak yükleniyor; komutlar bir betikte, böylece lokalde de CI'daki adımların aynısını çalıştırıyorum. CD tarafında: Continuous Delivery'de yayın kararı insandadır, Continuous Deployment'ta o da otomatiktir; iOS'ta App Review yüzünden pratikte TestFlight'a otomatik dağıtım yapılır, mağazaya insan onayıyla gönderilir. Projemde sürüm etiketiyle tetiklenen imzasız bir arşiv işi var; TestFlight yüklemesini şablon olarak hazırladım ama gerçek bir hesapla çalıştırmadım. İmzalama için sertifika ve provisioning profile geçici bir keychain'e yüklenir ya da fastlane match kullanılır; yükleme App Store Connect API anahtarıyla yapılır. Sektörde Xcode Cloud, Bitrise ve fastlane de yaygın."

### Derinleşirse

- **build-for-testing ve test-without-building neden ayrı?** Derleme bir kez yapılır; ürünler ve `.xctestrun` dosyasıyla birim ve UI testleri yeniden derlenmeden koşar. Derleme hatası ile test hatası ayrı adımlarda görünür; ürünler başka makinelere dağıtılıp testler bölünebilir.
- **Sürüm ve build numarası?** Sürüm (`CFBundleShortVersionString`) bir insan kararıdır, git etiketinden gelir. Build numarası (`CFBundleVersion`) her yüklemede artmalı; App Store Connect aynı sürüm için aynı numarayı ikinci kez kabul etmez. CI'da `CURRENT_PROJECT_VERSION=...` ile komut satırından veririm, projeye commit'lemem.
- **Code signing neyden oluşur?** Sertifika (kim imzalıyor) + provisioning profile (hangi App ID, hangi sertifikalar, hangi yetkiler; geliştirme ve ad hoc'ta hangi cihazlar). fastlane match sertifika ve profilleri şifreli bir depoda tutar; CI salt okunur modda yalnızca indirir.
- **Testler CI'da kırıldı, lokalde geçiyor?** Önce .xcresult'ı indirip hatayı ve ekran görüntüsünü incelerim. Sonra ortam farkına bakarım: Xcode/SDK sürümü, simülatör, zaman dilimi ve dil, test sırası, yavaş makinede zamanlama. Lokalde aynı betiği çalıştırır, gerekirse "Run Repeatedly" ile yeniden üretirim.
- **Flaky UI testi?** Önce kök neden: sabit `sleep` yerine `waitForExistence`, metin yerine erişilebilirlik kimliği, animasyonları kapatmak, sahte veri. Kalanlar için yalnızca UI testlerinde sınırlı tekrar; birim testlerinde asla.

### Tuzaklar

- Yapmadığın şeyi yapmış gibi anlatmak. "Şablonunu biliyorum, gerçek hesapla koşmadım" demek güçlü bir cevaptır.
- `xcodebuild ... | xcbeautify` zincirinde `pipefail` olmaması: Testler kırılsa bile çıkış kodu xcbeautify'ınki (0) olur, CI yeşil görünür.
- Sırları loga sızdırmak (`echo $SECRET`, `set -x`, base64'ten çözülmüş değer). CI yalnızca secret'ın kendisini maskeler, türetilmiş değeri maskeleyemez.
- Birim testlerine tekrar (retry) açmak: Deterministik olması gereken testin ara sıra kalması gerçek bir hatadır.

### Koda bak

1. [ci.yml](../.github/workflows/ci.yml) → `build-and-test`: Adım sırası quiz → build-for-testing → birim → UI testleri. UI adımının `if:` koşuluna, adım zaman sınırlarına ve `if: always()` ile .xcresult yüklemesine bak.
2. [ci.sh](../scripts/ci.sh) → `cmd_ui`: `-retry-tests-on-failure` yalnızca UI testlerinde. Dosyanın başındaki `set -euo pipefail` olmasa ne olurdu?
3. Aynı dosya → `cmd_archive`: Sürüm ve build numarası komut satırından override ediliyor, arşivden geri okunup doğrulanıyor; `CODE_SIGNING_ALLOWED=NO` ile imzasız.
4. [release.yml](../.github/workflows/release.yml) → `signing-check`: İş düzeyindeki `if:` secrets'ı okuyamaz; ucuz bir iş secrets'ın var olup olmadığını çıktı olarak veriyor.
5. Aynı dosya → `testflight`: Şablon: geçici keychain, profil kurulumu, manuel imzalı arşiv, `ExportOptions.plist`, API anahtarıyla yükleme.

### Demo

Mülakat → "CI/CD ile çalıştın mı?" → **Demo**. **Pipeline**'da commit'ten App Store'a 8 aşama var; bir aşamaya dokun: ne yaptığı, hangi araçlarla yapıldığı ve bu depoda nerede olduğu açılır. **Mülakatta nasıl anlatırsın?** bölümünde gerçekten yaptıklarını işaretle; cevap taslağı yalnızca işaretlediklerini iddia eder. Terminalde: `make ci` (CI'daki akışın aynısı) ve `make archive`.

Ders: [11 CI/CD](11-ci.md).

---

<a id="soru-10"></a>
## 10. Clean Architecture, VIPER ve MVVM

> **Soru:** "Clean Architecture, VIPER ve MVVM'i anlatır mısın? Farkları ne, hangisini ne zaman seçersin?"

### 30 saniyelik cevap

> "Önce seviyeleri ayırırım: MVC, MVVM ve VIPER sunum katmanını böler; Clean Architecture ise bütün uygulamanın katmanlarını ve bağımlılık yönünü belirler. Yani Clean içinde sunumu MVVM ile de VIPER ile de yazabilirim. Clean'in özü bağımlılık kuralı: Oklar içeri, domain'e bakar. Domain'de entity, use case ve repository protokolü durur; UIKit, SwiftUI ya da Core Data bilmez. Data katmanı o protokolü uygular. MVVM'de ViewModel durumu ve kullanıcı eylemlerini yönetir, View'ı tanımaz; View onu gözlemler, SwiftUI'da `@Observable` ile çok doğal. VIPER'da View, Interactor, Presenter, Entity ve Router protokollerle ayrılır; test edilebilirlik yüksek ama tören de çok, geri referanslar `weak`. Seçim maliyet/fayda işi: Basit ekranda MVVM yeter; büyük bir UIKit ekibi, karmaşık akış ve sıkı modül sınırları varsa VIPER ya da MVVM + Coordinator."

### Projedeki katmanlar

```text
Features/ReadingNotes/
├── Domain/          UIKit/SwiftUI/CoreData import ETMEZ
│   ├── Entities/      ReadingNote (struct, Sendable)
│   ├── Repositories/  NotesRepository (protokol: soyutlamanın sahibi domain)
│   └── UseCases/      AddNote / FetchNotes / DeleteNote (iş kuralı burada)
├── Data/            NotesRepository'yi uygular: bellek, UserDefaults, dosya, Core Data, SwiftData
└── Presentation/    aynı use case'ler, iki sunum
    ├── VIPER/         UIKit: View, Interactor, Presenter, Router + Contracts
    └── MVVM/          SwiftUI: NotesListView + @Observable NotesListViewModel
```

### Derinleşirse

- **VIPER'da kim kimi tutar?** VC → presenter strong; presenter → interactor ve router strong. Geri dönenler `weak`: presenter → view, interactor → presenter (output), router → VC. Modülün tek dış sahibi VC'yi gösteren yapıdır (ör. navigation controller); onu bırakınca zincir çözülür. Weak geri referanslar property injection ile bağlanır, çünkü presenter oluşturulurken VC henüz yoktur.
- **Presenter ile ViewModel farkı?** Presenter View'ı bir protokol üzerinden tanır ve ona komut verir (`view?.render(...)`), bu yüzden view'a weak referans tutar. ViewModel View'ı tanımaz; durumu yayınlar, View gözlemler.
- **MVVM'de navigasyonu kim yönetir?** ViewModel navigasyon nesnelerini bilmemeli. SwiftUI'da view, view model'in durumuna göre sheet/`navigationDestination` gösterir; UIKit'te genelde bir Coordinator akışı yönetir (MVVM-C). VIPER'da bu işin karşılığı Router.
- **Her özellik için use case şart mı?** Hayır. İş kuralı varsa (bu projede: kırp, boş olamaz, en fazla 280 karakter) use case onu tek yerde tutar ve iki arayüz paylaşır. Sadece "depodan al, göster" ise ekstra katman tören olur.
- **`NSManagedObject`'i doğrudan ekrana verebilir miyim?** Clean'de hayır: Sınırda domain struct'ına çevir. Managed object context'in kuyruğuna bağlıdır ve ekranı depolama teknolojisine bağlar.

### Tuzaklar

- "Massive View Controller"dan kaçarken "Massive ViewModel/Presenter" yaratmak: İş kuralı use case'te olmalı.
- VIPER'da `presenter.view` ya da `interactor.output`'u strong tutmak: Modül ekrandan kalksa da bellekte kalır.
- Her ekrana VIPER uygulamak: Basit bir ayar ekranı için 5 dosya ve 5 protokol.
- Domain katmanına `import UIKit`/`CoreData` eklemek: Bağımlılık kuralı kırılır.

### Koda bak

1. [NotesListContracts.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListContracts.swift) → `NotesListViewProtocol`, `NotesListInteractorOutput`: VIPER'ın haritası. Hangi protokoller `AnyObject`, neden?
2. [NotesListRouter.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListRouter.swift) → `NotesListRouter.build(repository:formatter:)`: Strong bağımlılıklar init ile, weak geri referanslar property injection ile.
3. [NotesListPresenter.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListPresenter.swift) → `NotesListPresenter.viewState(for:formatter:)`: UIKit import etmeyen presenter; entity'yi ekran metnine çeviren saf fonksiyon.
4. [NotesListViewModel.swift](../BookShelf/Features/ReadingNotes/Presentation/MVVM/NotesListViewModel.swift) → `NotesListViewModel`: Aynı use case'ler, View'ı tanımayan `@Observable` durum.
5. [AddNoteUseCase.swift](../BookShelf/Features/ReadingNotes/Domain/UseCases/AddNoteUseCase.swift) → `AddNoteUseCase.validate(_:)`: İş kuralı domain'de; iki arayüz aynı kuralı ve aynı hata mesajını kullanır.
6. [NotesListRouterTests.swift](../BookShelfTests/ReadingNotes/NotesListRouterTests.swift) → `testReleasingViewControllerReleasesWholeModule`: VC bırakılınca presenter, interactor ve router da serbest kalıyor.

### Demo

Mülakat → "Clean Architecture, VIPER ve MVVM" → **Demo**. **VIPER · UIKit**'te bir not ekle, **MVVM · SwiftUI**'a geç: Not orada, çünkü ikisi aynı use case'leri ve aynı depoyu kullanıyor. Depo seçicisini değiştir (Bellek, UserDefaults, Dosya, Core Data, SwiftData): Sunum kodu tek satır değişmeden çalışır. **Kıyas** bölümünde iki yaklaşımın tablosu var.

Ders: [13 Mimari](13-mimari.md) (§3-8).

---

<a id="soru-11"></a>
## 11. Dependency Inversion vs Dependency Injection

> **Soru:** "Dependency Inversion ile Dependency Injection aynı şey mi?"

### 30 saniyelik cevap

> "Hayır. Dependency Inversion bir tasarım ilkesi, SOLID'in D'si: Üst seviye politika kodu alt seviye ayrıntıya değil soyutlamaya bağlı olmalı; ayrıntı da o soyutlamaya bağlı olmalı. Kritik nokta soyutlamanın sahibi: Protokol politika tarafında, yani domain'de durur, depolar onu uygular. Böylece kaynak koddaki ok 'depo → domain' olur, tersine döner. Dependency Injection ise bir teknik: Nesne bağımlılığını kendisi oluşturmaz, dışarıdan alır; init, property ya da metot parametresiyle. DI, DIP'i uygulamanın en yaygın yolu ama ikisi bağımsız: Somut bir sınıfı enjekte edersem DI var, DIP yok. Tersi de olur: Protokol tipindeki bağımlılığı bir service locator'dan kendisi isteyen kod DIP'e uyar ama DI yapmaz. İkisi için de container şart değil; elle kurulan bir composition root yeter."

### Derinleşirse

- **DI çeşitleri?** Constructor injection varsayılan tercih: Zorunlu bağımlılık eksik kalamaz, `let` ile değişmez, test kolay. Property injection: weak geri referanslar, storyboard'dan gelen VC'ler; atanmayı unutma riski var. Method injection: çağrıya özel strateji (`sorted(by:)` gibi). SwiftUI'da `Environment` ağaç boyunca DI yapar.
- **Composition root nedir?** Somut tiplerin seçilip birbirine bağlandığı tek yer, genelde uygulamanın girişi. Bu projede `AppDependencies.makeForLaunch`: UI testinde bellek deposu, normalde varsayılan depo. Geri kalan kod yalnızca protokolleri görür.
- **Service locator neden anti-kalıp sayılır?** Bağımlılık imzada görünmez, global durum taşır, testler birbirini etkiler ve eksik kayıt ancak çalışma anında çöker. DI'da bağımlılık init'te görünür ve derleyici denetler.
- **Inversion tam olarak neyi tersine çeviriyor?** Kaynak kod bağımlılığının yönünü. Çalışma anındaki çağrı akışı değişmez: Use case yine depoyu çağırır.
- **Her şeye protokol yazmalı mıyım?** Hayır. Soyutlama, değişmesi muhtemel ya da testte değiştirilmesi gereken bir sınırda değerlidir (depo, ağ, saat).

### Tuzaklar

- Protokolü alt katmana koymak (ör. Core Data modülünde `CoreDataNotesStoreProtocol`): Soyutlama yine ayrıntıya ait olur; DIP gerçekleşmez.
- "DI kullanıyorum, o zaman DIP de var" demek: `init(repository: CoreDataNotesRepository)` DI'dır ama üst seviye kod hâlâ Core Data'ya bağlıdır.
- Zorunlu bir bağımlılığı property injection ile vermek: Atanmayı unutursan sessizce hiçbir şey olmaz.

### Koda bak

1. [NotesRepository.swift](../BookShelf/Features/ReadingNotes/Domain/Repositories/NotesRepository.swift) → `NotesRepository`: Soyutlama Domain klasöründe. DIP'in kalbi burası.
2. [AppDependencies.swift](../BookShelf/App/AppDependencies.swift) → `AppDependencies.makeForLaunch(arguments:)`: Composition root; somut depo burada seçilir.
3. [AddNoteUseCase.swift](../BookShelf/Features/ReadingNotes/Domain/UseCases/AddNoteUseCase.swift) → `AddNoteUseCase.init(repository:now:)`: Constructor injection; "şu anki zaman" bile enjekte ediliyor. Neden? (İpucu: test.)
4. [DependencyExamples.swift](../BookShelf/Features/Interview/Demos/Architecture/DependencyExamples.swift) → `TightlyCoupledNoteCounter`, `ConcreteInjectedNoteCounter`, `InjectedNoteCounter`: Sıkı bağlılık, DIP'siz DI, DI + DIP yan yana.
5. [DependencyInjectionDemoView.swift](../BookShelf/Features/Interview/Demos/Architecture/DependencyInjectionDemoView.swift) → `EnvironmentValues.noteFormatter`: SwiftUI `Environment` ile DI.

### Demo

Mülakat → "Dependency Inversion ile Dependency Injection aynı şey mi?" → **Demo**. **Dolu depo / Boş depo** seçicisini değiştir: (a) sıkı bağlı sayaç hep 0 kalır, (b) ve (c) değişir. (b)'ye Core Data deposu vermek derleme hatası olurdu, (c) her depoyu kabul eder. **Tarih / Uzunluk** seçicisi: Biçimlendirici `Environment` ile aşağı akar, oradan metoda parametre olarak geçer.

Ders: [13 Mimari](13-mimari.md) (§9-10).

---

<a id="soru-12"></a>
## 12. Kalıcılık: UserDefaults, Keychain, dosya, Core Data, SwiftData

> **Soru:** "iOS'ta veriyi nerede saklarsın? Hangisini ne zaman?"

### 30 saniyelik cevap

> "Seçimi verinin türü belirler. Küçük tercihler, ör. tema ya da okuma hızı, UserDefaults'a. Sırlar asla UserDefaults'a gitmez: Token ve parola Keychain'e, çünkü UserDefaults kendi şifrelemesi olmayan bir plist dosyası. Belgeler, görseller ve basit Codable listeler Application Support'ta bir dosyaya; atomik yazıp dosya korumasıyla. Büyüyen, ilişkili ve sorgulanan veri için Core Data ya da iOS 17+ ise SwiftData; SQL'e tam hakimiyet gerekirse SQLite. Yeniden üretilebilen veri önbelleğe: bellekte NSCache, HTTP için URLCache, dosyalar için sistemin silebileceği Caches klasörü. Core Data'da her context bir kuyruğa bağlıdır: Nesnelere `perform` içinde dokunurum, thread'ler arasında managed object değil `NSManagedObjectID` ya da düz bir struct taşırım. Bu projede beş depolama da tek bir `NotesRepository` protokolünün arkasında; ekranlar hangisinin kullanıldığını bilmiyor."

### Derinleşirse

- **Token'ı ya da büyüyen bir listeyi neden UserDefaults'a koymayız?** UserDefaults tek bir plist'tir: İlk erişimde tamamı belleğe alınır, değişiklikte tamamı yeniden yazılır, sorgu yoktur. Kendine ait şifrelemesi yoktur; şifresiz bir yedekten okunabilir. Keychain ayrı ve şifreli bir veritabanıdır; ne zaman okunabileceği (`kSecAttrAccessible`) ve Face ID şartı seçilebilir.
- **UserDefaults thread-safe mi?** Evet, Apple öyle belgeler; `synchronize()` artık gereksizdir (SDK başlığı da öyle der). Ama Xcode 26 SDK'sında `Sendable` değildir: Bir örneği actor'e verip dışarıda kullanmaya devam edersen Swift 6 derleyicisi itiraz eder. Bu projede çözüm: Örnek değil suite **adı** saklanıp gerektiğinde yeni örnek açılıyor.
- **Core Data'da thread güvenliği?** `viewContext` ana kuyruğa, `newBackgroundContext()` kendi özel kuyruğuna bağlıdır. Context'e ve getirdiği nesnelere yalnızca `perform { }` / `performAndWait { }` içinde dokunulur. `NSManagedObject` `Sendable` değildir (`NSManagedObjectID` ve context ise `Sendable`); başka context'e `NSManagedObjectID` verilir ve `existingObject(with:)` ile yeniden alınır. Hataları yakalamak için `-com.apple.CoreData.ConcurrencyDebug 1` başlatma argümanı.
- **Derleyici bu hatayı yakalar mı?** Her zaman değil (Swift 6.2.4 ile denendi): Managed object'i bir actor'e göndermek Swift 6 modunda hatadır; `perform`'a dışarıdan nesne sokmak yalnızca uyarıdır (API `@preconcurrency`); bloktan nesne **döndürmek** ise hiç uyarı vermez. Kural: Bloktan yalnızca struct ya da `NSManagedObjectID` çıkar.
- **Lightweight migration?** Model yeni bir sürüme geçince Core Data eşlemeyi kendisi çıkarır: alan ekleme/silme, opsiyonel yapma, varsayılanla zorunlu yapma, renaming identifier ile yeniden adlandırma. Veriyi dönüştürmek gerekiyorsa özel mapping model ya da iOS 17+ staged migration. SwiftData'da `VersionedSchema` + `SchemaMigrationPlan`.
- **SwiftData mı, Core Data mı?** SwiftData iOS 17+ ve çok daha az kod: `@Model`, `#Predicate`, `@Query`, arka plan için `@ModelActor`. Core Data daha olgun: `NSFetchedResultsController`, batch istekleri, ayrıntılı migration, eski iOS desteği.
- **Uygulama silinince Keychain verisi silinir mi?** Genellikle hayır; kayıtlar cihazda kalır (Apple bunu garanti edilen bir davranış olarak belgelemez). Temiz başlangıç için UserDefaults'ta bir "ilk açılış" bayrağı tutulur, yoksa Keychain temizlenir.

### Tuzaklar

- `NSManagedObject`'i `perform` bloğunun dışına ya da başka bir thread'e taşımak: Rastgele çökme ve bozuk veri.
- Token, parola gibi sırları UserDefaults'a ya da düz bir dosyaya yazmak.
- Büyüyen bir listeyi UserDefaults'ta tutmak: Her eklemede bütün dizi kodlanıp bütün plist yeniden yazılır.
- Dosyayı atomik yazmamak, Application Support klasörünü oluşturmayı unutmak, bozuk dosyayı "boş" sayıp üzerine yazmak.

### Koda bak

1. [UserDefaultsNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/UserDefaultsNotesRepository.swift) → `UserDefaultsNotesRepository`: Her kayıtta bütün dizi kodlanıp yazılıyor. UserDefaults'un neden büyüyen veriye uygun olmadığını kodda gör.
2. [FileNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/FileNotesRepository.swift) → `FileNotesRepository.write(_:)`: Klasörü oluştur, sonra `.atomic` + `.completeFileProtection` ile yaz.
3. [CoreDataNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/CoreData/CoreDataNotesRepository.swift) → `CoreDataNotesRepository`: Her erişim `perform` içinde; `NoteEntity` bloğun dışına çıkmıyor, `ReadingNote`'a çevriliyor. Neden actor değil de `final class`? `sharedModel` neden tek?
4. [SwiftDataNotesRepository.swift](../BookShelf/Features/ReadingNotes/Data/SwiftData/SwiftDataNotesRepository.swift) → `SwiftDataNotesRepository`: `@ModelActor`; actor'ün executor'ı context'in seri kuyruğu, `perform` yazmaya gerek yok.
5. [KeychainStore.swift](../BookShelf/Features/Interview/Demos/Persistence/KeychainStore.swift) → `KeychainStore.save(_:account:)`: Önce `SecItemUpdate`, kayıt yoksa `SecItemAdd`; `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` seçiminin gerekçesi.
6. [NotesRepositoryContractTests.swift](../BookShelfTests/Persistence/NotesRepositoryContractTests.swift) → `NotesRepositoryContractTests`: Aynı sözleşme testi beş uygulamada koşuyor.

### Demo

Mülakat → "iOS'ta veri saklama yolları nelerdir?" → **Demo**. **Ayar & Sır**: Okuma hızını değiştir (`@AppStorage` = UserDefaults); sahte token'ı Keychain'e kaydet, oku, sil. **Notlar**: Bir depo seç, "Örnek not ekle", sonra "Yeni örnekle yeniden aç": Bellek deposunda yeni örnek 0 not görür (veri eski örneğin belleğindeydi), diğer dördünde not yerinde durur. **Karşılaştır**: UserDefaults'tan CloudKit'e seçeneklerin tablosu.

Ders: [14 Kalıcılık](14-kalicilik.md).

---

<a id="soru-13"></a>
## 13. ARC ve retain cycle

> **Soru:** "ARC nasıl çalışır? Retain cycle nedir, nasıl kırarsın?"

### 30 saniyelik cevap

> "ARC, class örneklerinin (closure bağlamları ve actor'ler dahil) güçlü referanslarını sayar; retain/release çağrılarını derleyici ekler. Sayaç sıfıra indiği anda `deinit` senkron çalışır; arka planda dolaşan bir çöp toplayıcı yoktur. Ama ARC döngü bulamaz: İki nesne birbirini güçlü tutarsa, klasik örnek VC → closure → VC, dışarıdan kimse ulaşamasa da sayaç sıfıra inmez; `deinit` çalışmaz, bellek sızar. Döngüyü geri dönen oku zayıflatarak kırarım. `weak` sayacı artırmaz, nesne ölünce otomatik `nil` olur, bu yüzden Optional'dır. `unowned` da artırmaz ama `nil` olmaz; ölmüş nesneye erişim çöker, onu yalnızca ömür garantiliyse kullanırım. UIKit'teki tipik kaynaklar: saklanan closure'da `self`, strong delegate, Timer, NotificationCenter block observer'ı ve hiç bitmeyen Task. Bulmak için `deinit`'e log koyarım, Debug Memory Graph'a ve Instruments'ın Leaks aracına bakarım; testte `weak` referansla nesnenin serbest kaldığını doğrularım."

### Derinleşirse

- **`weak`, `unowned`, `unowned(unsafe)` farkı?** Üçü de sayacı artırmaz. `weak` Optional'dır, nesne ölünce `nil` olur (zeroing); Swift 6.2 ile `weak let` de yazılabiliyor. `unowned` `nil` olmaz; ölmüş nesneye erişim kontrollü bir çökmedir (nesne deinit olur ama unowned referanslar bitene kadar belleği tamamen bırakılmaz, çalışma zamanı bu sayede ölü olduğunu anlar). `unowned(unsafe)` hiç kontrol yapmaz; erişim tanımsız davranıştır. Karşı taraf senden önce ölebiliyorsa `weak`, en az senin kadar yaşayacağı kesinse `unowned`.
- **`[weak self]`, `[self]` ve `[x]` farkı?** `[weak self]` self'i zayıf yakalar. `[self]` açıkça güçlü yakalar; davranış örtük yakalamayla aynıdır, sadece niyeti gösterir. `[x]`, x'in closure oluşturulduğu andaki değerini yakalar: Değer tipiyse kopyası, class ise o nesneye güçlü referans.
- **Her closure'da `[weak self]` gerekir mi?** Hayır. Döngü ancak closure, self'in doğrudan ya da dolaylı tuttuğu bir yerde saklanırsa oluşur. Kaçmayan closure'lar (`map`, `filter`) döngü kuramaz. Tek seferlik kaçan closure'lar (completion handler, `UIView.animate`) self'in ömrünü yalnızca iş bitene kadar uzatır. Saklanan closure'larda ve uzun ya da sonsuz Task'larda gerekir.
- **Timer gerçekten bir döngü mü?** Çoğu zaman sorun döngü değil kök: RunLoop zamanlayıcıyı, `target: self` ile kurulan zamanlayıcı da target'ını güçlü tutar. VC timer'ı hiç saklamasa bile `invalidate()` edilmeden ölemez. Block tabanlı Timer'da `[weak self]` VC'yi kurtarır ama zamanlayıcı yine `invalidate()` edilene kadar çalışır.
- **SwiftUI'da retain cycle olur mu?** View'lar struct olduğu için view'un kendisi döngü kuramaz. Ama `@Observable` view model'ler class'tır: Kendi sakladığı bir closure'da ya da bitmeyen bir Task'ta self'i güçlü tutarlarsa sızarlar. `.task` modifier'ı view kaybolunca task'ı kendisi iptal eder.

### Tuzaklar

- Temizliği `deinit`'e koymak: `timer.invalidate()`, `removeObserver` ya da `task.cancel()` `deinit`'teyse ve o kaynak self'i güçlü tutuyorsa `deinit` hiç gelmez. Durdurmayı `viewDidDisappear`'a ya da açık bir `stop()` metoduna koy.
- Task içinde `guard let self`'i döngüden **önce** yazmak: Self döngü boyunca güçlü kalır, `[weak self]` boşa gider.
- `[weak self]` yazınca işin bittiğini sanmak: VC kurtulur ama sonsuz Timer ya da Task boşuna çalışmaya devam eder.
- Ömrü garanti olmayan bir referansı `unowned` yapmak.

### Koda bak

1. [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) → `startObservingFavorites()`: `observationTask = Task { [weak self] in ... }`. Kendine sor: `guard let self` neden `for await` döngüsünün **içinde**? Döngüden önce yazılsaydı ne olurdu? Task nerede iptal ediliyor (`viewDidDisappear`), `deinit`'teki `cancel()` neden yalnızca güvenlik ağı?
2. [LeakVictimViewController.swift](../BookShelf/Features/Interview/Demos/Memory/LeakVictimViewController.swift) → `startTickTask()`: Sızdıran sürümde Task self'i güçlü yakalar ve hiç bitmez; `deinit`'teki `cancel()` bu yüzden hiç çalışmaz.
3. Aynı dosya → `startTimer()`: İki sürümde kurulum aynı, fark durdurmada: RunLoop → Timer → target zinciri ancak `invalidate()` ile kopar.
4. [DeallocationProbe.swift](../BookShelf/Features/Interview/Demos/Memory/DeallocationProbe.swift) → `DeallocationProbe.waitForRelease(timeout:)`: Sızıntıyı ölçmenin yolu: weak referans tut, son güçlü referansı bırak, `nil` olmasını bekle.
5. [RetainCycleDemo.swift](../BookShelf/Features/Fundamentals/StructVsClass/RetainCycleDemo.swift) → `LibraryCard`: strong, weak ve unowned geri referans yan yana.
6. [MemoryLabVictimTests.swift](../BookShelfTests/MemoryDelegate/MemoryLabVictimTests.swift) → `MemoryLabVictimTests`: Her sızıntının testte yakalanışı.

### Demo

Mülakat → "ARC nasıl çalışır?" → **Demo**: Sızıntı laboratuvarı. Üstte beş senaryo var: **Closure, Timer, Delegate, Bildirim, Task**. Her birinde "Sızdıranı aç" → Kapat: Ölçüm "SIZINTI: hâlâ bellekte ✗" der. "Düzeltilmişi aç" → Kapat: "Serbest bırakıldı ✓". Sızdıran ve düzeltilmiş kod yan yana gösterilir. Bitince "Sızıntıları temizle". Bonus: Sızdırdıktan sonra Xcode'da Debug Memory Graph'ı aç ve `LeakVictimViewController`'ı tutan zinciri bul. Struct vs Class demosundaki **ARC** bölümünde de "strong ↔ strong (döngü)", "weak ile kır", "unowned ile kır" var.

Ders: [12 ARC ve Delegate](12-arc-ve-delegate.md) (§1-5).

---

<a id="soru-14"></a>
## 14. Delegate: Kim delegate olur, kim kimi tutar?

> **Soru (mülakattaki hali):** "Delegate'te hangisinin superclass olacağını nasıl bilirsin?"

**Soru aslında ne soruyor?** Delegate'te superclass yani kalıtım yoktur; mülakatçının kastettiği "iki nesneden hangisi delegate olur, hangisi diğerini `weak` tutar ve buna neye bakarak karar verirsin?" sorusudur. Cevabın iki ayağı var: **ömür/sahiplik** (kim daha uzun yaşıyor, kim kime sahip) ve **mimari karar** (hangi taraf ne yapılacağına karar vermeli). Cevaba bu düzeltmeyle başlamak, soruyu anladığını gösterir.

### 30 saniyelik cevap

> "Önce küçük bir düzeltme: Delegate'te kalıtım, yani superclass ilişkisi yok. Bir nesne olaylarını ve sorularını bir protokol üzerinden başka bir nesneye devreder; bu kompozisyon. Kimin delegate olacağını sahiplik ve ömür belirler: Sahip olan, daha uzun yaşayan taraf (view controller, parent, presenter) delegate olur. Sahip olunan taraf (kontrol, table view, child) protokolü tanımlar ve delegate'ini `weak` tutar. Çünkü sahip onu zaten güçlü tutuyor; o da sahibini güçlü tutsaydı retain cycle olurdu. `weak` yazabilmek için protokol `AnyObject`'e bağlı olmalı ve çağrı `delegate?.` ile yapılır. Bu aynı zamanda mimari bir karar: Kontrol yeniden kullanılabilir kalsın diye 'ne yapılacağına' sahibi karar verir; kontrol sahibinin tipini bilmez, yalnızca protokolü bilir. Tek bir callback varsa closure, 1'e çok yayın varsa NotificationCenter, zaman içinde akan değerler varsa AsyncStream seçerim."

### Kural tek resimde

```text
BookRatingViewController   (sahip · uzun ömürlü · DELEGATE OLUR)
     │ strong                     ▲ weak
     ▼ view → subview             │ delegate
StarRatingControl          (sahip olunan · protokolü tanımlar · weak tutar)
```

Aynı kural her yerde: `UITableView` ↔ VC (`tableView.delegate = self`), VIPER'da presenter ↔ view ve interactor ↔ presenter, sunulan ekran ↔ onu sunan ekran.

### Derinleşirse

- **Neden `unowned` değil de `weak`?** Delegate'in kontrolden önce ölmeyeceği genelde garanti değildir: Kontrolü başka biri tutuyor olabilir, bir animasyon ya da async iş onu yaşatabilir. `unowned` ölmüş nesneye erişimde çöker; `weak` `nil` olur ve `delegate?.` ile güvenle atlanır.
- **Delegate mi, closure mı, NotificationCenter mı?** Delegate: 1'e 1, birbiriyle ilişkili birçok callback ve dönüş değeri isteyen sorular (`should…`, data source). Closure: tek olay ya da tek seferlik sonuç; saklanıyorsa `[weak self]`. NotificationCenter: 1'e çok, birbirini tanımayan taraflar; dönüş değeri yok. Akan değerler: AsyncStream ya da Combine.
- **Swift'te isteğe bağlı delegate metodu?** `@objc protocol` + `@objc optional func` (yalnızca class'lar, Objective-C çalışma zamanı) ya da saf Swift'te protokol extension'ında varsayılan uygulama. Projede `shouldChangeRatingTo` varsayılan olarak `true` döner.
- **Delegate metotlarının ilk parametresi neden kontrolün kendisi?** Cocoa geleneği: Aynı delegate birden çok kontrolü yönetebilir (`tableView(_:didSelectRowAt:)`) ve olayın hangisinden geldiğini ayırt eder.
- **VIPER'da weak referanslar nerede?** View (VC) presenter'ı strong tutar, presenter view'u weak tutar. Presenter interactor'ı strong tutar, interactor output'u (presenter) weak tutar. Router da genelde VC'yi weak tutar.

### Tuzaklar

- Delegate'i strong tanımlamak (`var delegate: XDelegate?`): VC → kontrol → VC döngüsü, ikisi de hiç ölmez.
- Protokolü `AnyObject`'e bağlamayı unutmak: `'weak' must not be applied to non-class-bound 'any XDelegate'; consider adding a protocol conformance that has a class bound`.
- `delegate = self` atamasını unutmak: `delegate?.method()` sessizce hiçbir şey yapmaz.
- Birden çok dinleyici gerekirken delegate kullanmak: Delegate tek bir nesnedir, ikinci atama birinciyi ezer.

### Koda bak

1. [StarRatingControl.swift](../BookShelf/Features/Interview/Demos/Delegation/StarRatingControl.swift) → `StarRatingControlDelegate`: Protokolü sahip olunan taraf tanımlıyor; `AnyObject` (weak için şart) ve `@MainActor`. Altındaki extension'da `shouldChange` için varsayılan cevap.
2. Aynı dosya → `StarRatingControl.selectRating(_:)`: Önce delegate'e soruyor (dönüş değeri!), sonra değiştiriyor, en son delegate, closure ve target-action ile haber veriyor.
3. [BookRatingViewController.swift](../BookShelf/Features/Interview/Demos/Delegation/BookRatingViewController.swift) → `BookRatingViewController.connectRatingControl()`: Üç bağlantı: `delegate = self` (weak), `onRatingChange` closure'ında `[weak self]`, `addTarget` (UIControl hedefi retain etmez).
4. [DelegateLifetimeExperiment.swift](../BookShelf/Features/Interview/Demos/Delegation/DelegateLifetimeExperiment.swift) → `DelegateLifetimeExperiment.run()`: Sahip ölür, kontrol yaşar; weak delegate kendiliğinden `nil` olur, kontrol çökmez.
5. [LeakVictimViewController.swift](../BookShelf/Features/Interview/Demos/Memory/LeakVictimViewController.swift) → `LeakVictimViewControllerDelegate`: Modal kalıbı: Sunulan ekran kendini kapatmaz, sahibine weak delegate ile "işim bitti" der.
6. [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) → `configureTableView()`: UIKit'in kendi örneği; `UITableView` delegate ve dataSource'unu weak tutar.

### Demo

Mülakat → "Delegate pattern'de kim delegate olur?" → **Demo**. **Canlı**: Yıldızlara dokun; delegate, closure ve target-action kanallarının üçü de haber verir. **Sahiplik**: Şemayı incele, sonra "Sahibi yok et, kontrolü yaşat": Sahip serbest kalır, `delegate` kendiliğinden `nil` olur, kontrol çökmeden çalışır. **Hangisi?**: Delegate / closure / target-action / NotificationCenter / AsyncStream karar tablosu.

Ders: [12 ARC ve Delegate](12-arc-ve-delegate.md) (§6-7).

---

<a id="bonus-concurrency"></a>
## Bonus 1. Swift Concurrency

> **Soru:** "Swift Concurrency'yi anlatır mısın? async/await, actor, `Sendable` ve `@MainActor` ne işe yarar?"

### 30 saniyelik cevap

> "async/await asenkron kodu callback'siz, yukarıdan aşağı okunur yazdırır. `await` olası bir askıya alma noktasıdır: Fonksiyon beklemek zorunda kalırsa thread'i bloklamaz, thread başka işlere döner. `async let` ve TaskGroup ile açılan alt görevler yapılandırılmıştır: Üst görevin kapsamını aşamaz, iptal görev ağacı boyunca yayılır; `Task { }` ise yapılandırılmamıştır, ömrünü ve iptalini ben yönetirim. Actor değiştirilebilir durumunu izole eder; dışarıdan erişim `await` ister, böylece data race olmaz. `@MainActor` ana thread'i temsil eden global actor; UI kodu orada çalışır. `Sendable` bir değerin izolasyon sınırını güvenle geçebileceğini söyler. Swift 6 dil modunda derleyici bunları denetler. Ama race condition hâlâ mümkündür: Actor bir `await`'te askıya alınınca araya başka çağrılar girebilir; buna reentrancy denir."

### Derinleşirse

- **Data race ile race condition aynı şey mi?** Hayır. Data race: Aynı belleğe, en az biri yazma olan iki erişimin senkronizasyonsuz aynı anda yapılması; tanımsız davranıştır ve Swift 6 bunu derleme anında engeller. Race condition: Sonucun zamanlamaya bağlı olması; mantık hatasıdır. Actor ilkini önler, ikincisini önlemez.
- **`async` fonksiyon arka planda mı çalışır?** `async` "ayrı thread" demek değildir; yeri izolasyon belirler. Bu projenin ayarlarıyla (Swift 6 modu, Approachable Concurrency kapalı) `nonisolated` bir `async` fonksiyon global concurrent executor'de çalışır. `NonisolatedNonsendingByDefault` açıksa aynı fonksiyon çağıranın actor'ünde çalışır; arka plana göndermek için `@concurrent` yazılır.
- **`Task { }` ile `Task.detached { }` farkı?** `Task { }` başlatıldığı yerin actor izolasyonunu, önceliğini ve task-local değerlerini miras alır; `Task.detached` hiçbirini almaz. İkisinde de iptal kendiliğinden geçmez.

### Tuzaklar

- Actor'ü bir kilit ya da transaction sanmak: oku → `await` → yaz kalıbında güncellemeler kaybolur.
- Hatayı susturmak için `@unchecked Sendable` ya da `nonisolated(unsafe)` yazmak.
- `cancel()`'ın işi durdurduğunu sanmak: İptal yalnızca bir bayraktır; iş `Task.isCancelled`'a bakmalı.

### Koda bak

1. [FavoritesStore.swift](../BookShelf/Core/Stores/FavoritesStore.swift) → `FavoritesStore.toggle(_:)`: Oku-karar ver-yaz adımları arada `await` olmadan; bu yüzden atomik.
2. [LabCounters.swift](../BookShelf/Features/ConcurrencyLab/LabCounters.swift) → `ReentrantCounter`: Data race yok ama race condition var.
3. [BookDetailViewModel.swift](../BookShelf/Features/BookDetail/BookDetailViewModel.swift) → `loadExtrasIfNeeded()`: `async let` ile iki istek aynı anda.
4. [LongRunningJob.swift](../BookShelf/Features/ConcurrencyLab/LongRunningJob.swift) → `LongRunningJob.run(onProgress:)`: Kooperatif iptal.

### Demo

Mülakat → "Swift Concurrency'yi anlatır mısın?" → **Demo** (aynı deneyler Laboratuvar sekmesinde de var): sıralı vs paralel, data race vs actor, actor reentrancy, iptal. Data race deneyini Thread Sanitizer açıkken çalıştırırsan (Scheme → Run → Diagnostics) TSan yarışı raporlar.

Ders: [05 async/await](05-async-await.md), [06 Concurrency ve Actor](06-concurrency-ve-actor.md).

---

<a id="bonus-objc"></a>
## Bonus 2. Objective-C interop

> **Soru:** "Objective-C ile Swift aynı projede nasıl birlikte çalışır?"

### 30 saniyelik cevap

> "İki yönlü. ObjC'den Swift'e: Uygulama hedefinde ObjC header'larını köprü başlığına (bridging header) import ederim; Swift bu API'leri `import` yazmadan, Swift'e çevrilmiş haliyle görür. Swift'ten ObjC'ye: Xcode `<Modül>-Swift.h` başlığını üretir, .m dosyası onu import eder; ObjC yalnızca `@objc` ile açılan ve ObjC'de karşılığı olan şeyleri görür: NSObject'ten türeyen sınıflar, `@objc` protocol'ler, tamsayı ham değerli `@objc` enum'lar. Struct, generic ve ilişkili değerli enum görünmez. Header'daki işaretler Swift API'sini şekillendirir: `nullable`/`nonnull` Optional olup olmayacağını, `NS_SWIFT_NAME` Swift'teki adı belirler. Son parametresi `NSError **` olan metot Swift'te `throws` olur."

### Derinleşirse

- **Nullability yazılmazsa?** Swift pointer'ı örtük açılan Optional (`String!`) olarak alır; `nil` gelirse çöker. Çözüm: `NS_ASSUME_NONNULL_BEGIN`/`END` ve `nullable` işaretleri.
- **`@objc` ile `@objc dynamic` farkı?** `@objc` üyeyi ObjC çalışma zamanına açar; Swift'ten çağrılar yine doğrudan ya da vtable ile yapılabilir. `dynamic` ile her çağrı `objc_msgSend` ile yapılır; KVO ve swizzling bunu ister.
- **ObjC enum'unu `switch`'lerken neden `@unknown default`?** `NS_ENUM` donmamış (non-frozen) sayılır; ileride değer eklenebilir. Swift 6 modunda `@unknown default` olmadan bütün vakaları kapsayan `switch` derlenmez (Swift 5'te uyarı; bu proje için derleyiciyle denendi).

### Tuzaklar

- Header'a nullability yazmamak.
- `-Swift.h`'yi bir .h dosyasından import etmek: Döngü. .h'de `@class` ileri bildirimi kullan.
- `NSException`'ı Swift `do/catch` ile yakalayabileceğini sanmak: Swift `catch` yalnızca `Error`'ları yakalar.

### Koda bak

1. [BookShelf-Bridging-Header.h](../BookShelf/ObjC/BookShelf-Bridging-Header.h): ObjC → Swift yönü.
2. [BKISBNValidator.h](../BookShelf/ObjC/BKISBNValidator.h) → `+validateISBN13:error:`: `NSError **` + BOOL → `throws`; aynı dosyada `NS_SWIFT_NAME`, `NS_ERROR_ENUM`, `nullable`.
3. [ISBNCheckOutcome.swift](../BookShelf/Features/ISBNChecker/ISBNCheckOutcome.swift) → `ISBNCheckOutcome.evaluate(_:)`: Swift tarafı: `try`, `catch let error as BKISBNValidatorError`, `@unknown default`.
4. [BKReadingTimeEstimator.m](../BookShelf/ObjC/BKReadingTimeEstimator.m) → `initWithPagesPerHour:`: `#import "BookShelf-Swift.h"` yalnızca .m'de; Swift sınıfı (`ReadingPace`) ObjC'den çağrılıyor.

### Demo

Mülakat → "Objective-C ile Swift aynı projede nasıl birlikte çalışır?" → **Demo**: ISBN doğrulayıcı; doğrulamayı Objective-C sınıfı yapar. `978-605-000-001-6` geçerlidir. `978-605-000-008-6`'yı dene: Örnek verideki "Huzur"un ISBN'i, kontrol hanesi bilerek yanlış (doğrusu 5). ObjC'nin `NSError **` ile döndürdüğü hata Swift'te `catch let error as BKISBNValidatorError` ile tipli olarak yakalanır. Aynı ObjC sınıfı Kitaplar sekmesinde de çalışıyor: "Huzur"un detayındaki ISBN rozeti bu yüzden kırmızı.

Ders: [08 Objective-C](08-objective-c.md).
