# ARC, Retain Cycle ve Delegate: Kim Kimin Sahibi?

## Neden önemli?

Bu iki konu mülakatlarda neredeyse hep birlikte gelir, çünkü aynı soruya dayanırlar: **Bu nesneyi kim hayatta tutuyor?**

- "ARC nasıl çalışır, retain cycle nedir?" sorusu genelde "Peki UIKit'te nerede sızıntı olur, nasıl bulursun?" diye devam eder.
- "Delegate'te hangisi delegate olur?" sorusunu bazen "hangisi superclass olur?" diye yanlış hatırlarsın. Doğrusu: Kalıtımla ilgisi yoktur; cevap **sahiplik ve ömür**dür. Sahip delegate olur, sahip olunan nesne delegate'ini `weak` tutar.
- Gerçek projelerde bellek sızıntıları sessizdir: Ekran kapanır, görünüşte her şey yolundadır, ama arkada bir timer çalışmaya, bir gözlemci bildirim almaya, bir task ağdan veri çekmeye devam eder.

Uygulamada iki demo var:

- **Mülakat → "ARC nasıl çalışır?" → Demo:** UIKit sızıntı laboratuvarı. Beş klasik sızıntıyı (closure, Timer, delegate, NotificationCenter, Task) sızdıran ve düzeltilmiş halleriyle açıp kapatır, `deinit`'in çalışıp çalışmadığını ölçer.
- **Mülakat → "Delegate pattern'de kim delegate olur?" → Demo:** Canlı bir UIKit kontrolü (delegate + closure + target-action yan yana), "kim kimin sahibi?" şeması ve "hangisini seçmeli?" tablosu.

Bu ders [02 Struct vs Class](02-struct-vs-class.md) (ARC'nin temelleri) ve [07 UIKit](07-uikit.md) (delegate, `[weak self]`) derslerinin üzerine kurulur.

## Temel kavramlar

### 1. ARC tek paragrafta

ARC (Automatic Reference Counting), referans tiplerinin ömrünü **güçlü referans sayısıyla** yönetir:

- Sayılanlar: class örnekleri, actor'ler ve closure'ların yakaladığı bağlam (context). Struct ve enum'ların kendisi sayılmaz; ama içlerindeki class referansları ve `Array`/`String` gibi tiplerin heap'teki depoları sayılır.
- `retain`/`release` çağrılarını **derleyici** ekler. Çalışma anında arka planda dolaşan bir çöp toplayıcı (GC) yoktur.
- Sayı 0 olduğu anda `deinit` **senkron** olarak çalışır (son referansı hangi thread bıraktıysa orada) ve nesne yok edilir. Bu deterministiktir.
- ARC **döngü aramaz**. Birbirini güçlü tutan nesneler, dışarıdan kimse onlara ulaşamasa bile yaşar.
- Bir nesnenin ömrü `}` işaretinde değil, **son kullanıldığı yerde** bitebilir (bkz. [02 Struct vs Class](02-struct-vs-class.md)). Testlerde "tam şu satırda silinir" yerine "kısa süre içinde silinir" diye bekleriz.

### 2. `strong`, `weak`, `unowned`, `unowned(unsafe)`

| | Sayacı artırır mı? | Nesne yok olunca | Optional? | Ölü nesneye erişim | Ne zaman? |
|---|---|---|---|---|---|
| `strong` (varsayılan) | Evet | Yok olmaz; sen tuttukça yaşar | Fark etmez | Olamaz | Sahiplik |
| `weak` | Hayır | Otomatik `nil` olur (*zeroing*) | Her zaman | `nil` okursun, güvenli | Karşı taraf senden önce ölebilir (delegate, geri referans) |
| `unowned` | Hayır | `nil` olmaz | İsteğe bağlı (`unowned var x: T?` de olur) | Kontrollü **çökme** | Karşı taraf en az senin kadar yaşayacaksa |
| `unowned(unsafe)` | Hayır | `nil` olmaz | İsteğe bağlı | **Tanımsız davranış** (askıda pointer) | Neredeyse hiç; ölçülmüş performans ihtiyacı |

- `weak` Swift 6.2'ye kadar yalnızca `var` olabiliyordu; Swift 6.2 ile `weak let` de yazılabiliyor.
- `weak` ve `unowned` yalnızca class'a bağlı tiplere uygulanabilir. Protokol tipini zayıf tutmak için protokol `AnyObject`'ten türemelidir, yoksa derleyici şunu söyler:
  `'weak' must not be applied to non-class-bound 'any XDelegate'; consider adding a protocol conformance that has a class bound`

### 3. Yakalama listeleri (capture lists)

Closure'lar referans tipidir ve yakaladıklarını **güçlü** tutar. Yakalama listesi bu varsayılanı değiştirir:

| Yazım | Ne yakalanır? |
|---|---|
| (liste yok) | Değişkenin kendisi: closure çağrıldığında **güncel** değeri görür. Class örneği güçlü tutulur. |
| `[weak self]` | `self`'e zayıf referans; closure içinde `self` Optional'dır. |
| `[unowned self]` | `self`'e sahipsiz referans; closure `self` öldükten sonra `self`'e erişirse çöker. |
| `[self]` | `self` açıkça **güçlü** yakalanır. Davranış örtük yakalamayla aynıdır; niyeti gösterir ve gövdede `self.` yazmayı gereksiz kılar. |
| `[x]` | `x`'in closure **oluşturulduğu andaki** değeri: değer tipiyse kopyası, class ise o nesneye güçlü referans. |

```swift
var x = 1
let implicit = { print(x) }
let captured = { [x] in print(x) }
x = 2
implicit()   // 2: değişkenin kendisini görür
captured()   // 1: oluşturulduğu andaki değeri görür
```

Her closure `[weak self]` istemez:

- **Kaçmayan (non-escaping)** closure'lar (`map`, `filter`, `sorted(by:)`) fonksiyon bitince yok olur; döngü kuramaz.
- **Tek seferlik kaçan** closure'lar (bir completion handler, `UIView.animate`) `self`'in ömrünü yalnızca iş bitene kadar uzatır; döngü değildir.
- Döngü, closure **`self`'in doğrudan ya da dolaylı tuttuğu bir yerde saklanınca** oluşur: bir özellikte (`onUpdate`), bir düğmenin `UIAction`'ında, bir data source'un cell provider'ında, ya da hiç bitmeyen bir `Task`'ta.

### 4. UIKit'te beş klasik sızıntı (laboratuvardaki senaryolar)

| Senaryo | Sızdıran sürümde tutan zincir | Düzeltme |
|---|---|---|
| Saklanan closure | VC → `onUpdate` → closure → VC | `[weak self]` |
| Timer | RunLoop → Timer → target: VC | `viewDidDisappear`'da `invalidate()` |
| Strong delegate | VC → reporter → `delegate`: VC | `weak var delegate` |
| NotificationCenter (block) | NotificationCenter → gözlemci → block → VC | `[weak self]` + `removeObserver(token)` |
| Hiç bitmeyen Task | Çalışan Task → closure → VC | `[weak self]` + `viewDidDisappear`'da `cancel()` |

Hepsinde aynı tuzak var: **Temizliği `deinit`'e koymak.** `deinit { timer?.invalidate() }` yazarsın, ama timer VC'yi tuttuğu için sayaç hiç 0 olmaz ve `deinit` hiç gelmez. Kural: **Kur ↔ durdur simetrisi.** `viewWillAppear`'da başlayan şey `viewDidDisappear`'da durur; `deinit` yalnızca güvenlik ağıdır.

Ayrıntılar:

- **Timer:** Zamanlanmış bir timer'ı RunLoop güçlü tutar; timer da target'ını **invalidate edilene kadar** güçlü tutar. Block tabanlı timer + `[weak self]` VC'yi kurtarır ama timer çalışmaya devam eder (her saniye `nil` bir `self`'e boşuna dokunur). `invalidate()` yine şarttır.
- **NotificationCenter:** Block tabanlı `addObserver(forName:object:queue:using:)` dönen gözlemciyi merkez, `removeObserver` çağrılana kadar tutar; block da `self`'i yakalarsa VC hiç ölmez. Selector tabanlı `addObserver(_:selector:name:object:)` için iOS 9'dan beri kaldırma zorunlu değildir (merkez gözlemciyi tutmaz). Block'un tipi SDK'da `@Sendable`; `queue: .main` ile ana thread'de çalıştığını derleyiciye `MainActor.assumeIsolated` ile söyleriz.
- **Task:** Yapısal olmayan bir `Task { }`, closure'ını ve yakaladıklarını **bitene kadar** tutar. İptal işbirlikçidir: `cancel()` sadece bir bayrak kaldırır; döngü `Task.isCancelled`'a bakmalı ya da `Task.sleep` gibi iptale tepki veren bir çağrıda beklemelidir.

```swift
// YANLIŞ: guard döngüden ÖNCE → self döngü boyunca güçlü kalır, [weak self] boşa gider.
task = Task { [weak self] in
    guard let self else { return }
    while !Task.isCancelled {
        refresh()
        try? await Task.sleep(for: .seconds(1))
    }
}

// DOĞRU: self'e her turda kısa süreliğine dokun, task'ı viewDidDisappear'da iptal et.
task = Task { [weak self] in
    while !Task.isCancelled {
        self?.refresh()
        try? await Task.sleep(for: .seconds(1))
    }
}
```

Laboratuvarın kendi kodunda da aynı disiplin var: Düğmelerin `UIAction` closure'ları `[weak self]` kullanır (VC → view → düğme → `UIAction` → closure → VC olmasın), kurbanı izleyen kayıt defteri (`LeakRegistry`) kurbanları **zayıf** tutar. Ölçen kod ölçtüğü şeyi hayatta tutsaydı sonuç anlamsız olurdu.

### 5. Sızıntıyı bulmak

1. **`deinit` logu.** En ucuz araç: `deinit { logger.debug("deinit: \(...)") }`. Ekranı kapatınca satır görünmüyorsa nesne yaşıyordur. (`LeakVictimViewController` bunu `Logger` ile yapar.)
2. **Xcode Debug Memory Graph.** Uygulama çalışırken hata ayıklama çubuğundaki düğmeyle bellekteki nesne grafiğini dondurur. Sol panelde tip başına örnek sayısı görünür: Ekranı üç kez açıp kapattıktan sonra üç tane `LeakVictimViewController` görmek alarm işaretidir. Ulaşılamayan döngüler mor ünlemle işaretlenir. Nesnenin nerede oluşturulduğunu görmek için şemada (Scheme → Diagnostics) **Malloc Stack Logging**'i aç.
3. **Instruments → Leaks.** Ulaşılamayan (hiçbir kökten erişilemeyen) belleği bulur: klasik iki nesneli döngüler. Dikkat: RunLoop'un tuttuğu bir timer ya da NotificationCenter'ın tuttuğu bir block **teknik olarak ulaşılabilirdir**; Leaks onları "sızıntı" saymayabilir. Bunlar "terk edilmiş bellek"tir (*abandoned memory*).
4. **Instruments → Allocations + Mark Generation.** Bir işlemi (ekranı aç-kapat) tekrarla, her seferinde nesil işaretle. Her nesilde kalıcı olarak büyüyen nesneler terk edilmiş belleği gösterir.
5. **Birim testi.** Nesneye `weak` referans tut, son güçlü referansı bırak, `nil` olmasını bekle. Projede `DeallocationProbe` ve [MemoryLabVictimTests](../BookShelfTests/MemoryDelegate/MemoryLabVictimTests.swift) bunu yapar. Yaygın bir kalıp da test sonunda kontrol etmektir: `addTeardownBlock { [weak sut] in XCTAssertNil(sut) }`.

### 6. Delegate: kim kimin sahibi?

Delegate kalıbında bir nesne, olaylarını ve sorularını **bir protokol üzerinden** başka bir nesneye devreder. İki taraf arasında **kalıtım yoktur**; bu bir kompozisyondur:

```swift
@MainActor
protocol StarRatingControlDelegate: AnyObject {          // protokolü sahip OLUNAN taraf tanımlar
    func starRatingControl(_ control: StarRatingControl, shouldChangeRatingTo rating: Int) -> Bool
    func starRatingControl(_ control: StarRatingControl, didChangeRating rating: Int)
}

final class StarRatingControl: UIControl {               // UIControl'den türer
    weak var delegate: (any StarRatingControlDelegate)?
}

final class BookRatingViewController: UIViewController { // UIViewController'dan türer
    let ratingControl = StarRatingControl()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(ratingControl)                     // sahip → kontrol: strong (view hiyerarşisi)
        ratingControl.delegate = self                      // kontrol → sahip: weak
    }
}
```

```
BookRatingViewController   (sahip · uzun ömürlü · delegate)
     │ strong                     ▲ weak
     ▼ view → subview             │ delegate
StarRatingControl          (sahip olunan · protokolü tanımlar)
```

**Kural:** Uzun yaşayan **sahip** (VC, parent, presenter) aşağıdakini strong tutar ve **delegate olur**. Sahip olunan, daha kısa yaşayan nesne (kontrol, table view, child, interactor) protokolü tanımlar ve delegate'i **weak** tutar.

- **Neden weak?** Sahip zaten aşağıyı güçlü tutuyor. Kontrol de sahibi güçlü tutsaydı iki ok birbirine döner, ikisi de hiç ölmezdi.
- **Neden unowned değil?** Kontrolün sahibinden önce öleceği garanti değildir: başka biri onu tutuyor olabilir, bir animasyon ya da async iş onu yaşatabilir. `weak` nil olur ve `delegate?.method()` ile güvenle atlanır; `unowned` çöker. Projedeki [DelegateLifetimeExperiment](../BookShelf/Features/Interview/Demos/Delegation/DelegateLifetimeExperiment.swift) bunu gösterir: sahip ölür, kontrol yaşar, `control.delegate` kendiliğinden `nil` olur, kontrol çökmeden çalışmaya devam eder.
- **Neden `AnyObject`?** `weak` yalnızca class örneklerine uygulanabilir.
- **İlk parametre neden kontrolün kendisi?** Cocoa geleneği: Aynı delegate birden çok kontrolü yönetebilir (`tableView(_:didSelectRowAt:)` gibi) ve hangisinden geldiğini ayırt eder.
- **İsteğe bağlı metotlar:** `@objc protocol` + `@objc optional func` (UIKit böyle; yalnızca class'lar, Objective-C çalışma zamanı) ya da saf Swift'te protokol extension'ında varsayılan uygulama. `StarRatingControlDelegate.shouldChangeRatingTo` varsayılan olarak `true` döner.
- **Delegate vs data source:** İkisi de aynı kalıptır. Delegate genelde olayları ve davranış kararlarını, data source ise veriyi (`numberOfRowsInSection`) sorar.

**"Hangisi superclass olur?" sorusu gelirse:** "Delegate'te kalıtım yok; iki taraf bir protokolle konuşur. Asıl soru kim kimi tutar: Sahip delegate olur ve aşağıyı strong tutar; sahip olunan delegate'ini weak tutar. Bu aynı zamanda mimari bir karardır: Kontrol yeniden kullanılabilir kalsın diye 'ne yapılacağına' sahibi karar verir; kontrol sahibinin tipini bilmez, sadece protokolü bilir."

**Mimarideki karşılığı (VIPER):** View (VC) presenter'ı strong tutar, `presenter.view` weak'tir. Presenter interactor'ı strong tutar, `interactor.output` (presenter) weak'tir. Router da genellikle VC'yi weak tutar. Projede mimari dersindeki VIPER örneği `BookShelf/Features/ReadingNotes/Presentation/VIPER/` klasöründedir; aynı kuralı orada da arayabilirsin.

### 7. Delegate mi, closure mı, target-action mı, NotificationCenter mı, AsyncStream mi?

| Yöntem | Ne zaman? | Bellek |
|---|---|---|
| Delegate | 1'e 1; birbiriyle ilişkili birçok olay ve **değer döndüren sorular** (`should…`, data source) | Sahip olunan taraf `weak` tutar |
| Closure | 1'e 1; tek olay ya da tek seferlik sonuç | Saklanıyorsa `[weak self]` |
| Target-action | `UIControl` olayları | `addTarget` hedefi **retain etmez**; `addAction(UIAction)` closure'ı tutar |
| NotificationCenter | 1'e çok yayın; taraflar birbirini tanımaz; dönüş değeri yok | Block gözlemcisini kaldır, block'ta `[weak self]` |
| AsyncStream / Combine | Zaman içinde akan değerler | Dinleyen `Task`'ı iptal et / `AnyCancellable`'ı sakla; sink'te `[weak self]` |

`AsyncStream` tek tüketicilidir; birden çok dinleyici için her birine ayrı akış verilir (bkz. `FavoritesStore.changes()`). Combine publisher'larına ise birden çok abone bağlanabilir.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [LeakVictimViewController.swift](../BookShelf/Features/Interview/Demos/Memory/LeakVictimViewController.swift) | `startTimer()`, `startObservingPings()`, `startTickTask()`, `installUpdateClosure()`, `viewDidDisappear(_:)`, `deinit` | Beş sızıntının gerçek kodu; kur ↔ durdur simetrisi; `deinit`'teki temizliğin sızdıran sürümde hiç çalışmaması |
| [LeakLabReporter.swift](../BookShelf/Features/Interview/Demos/Memory/LeakLabReporter.swift) | `LeakLabReporter`, `LeakLabReporterDelegate` | Strong ve weak delegate yan yana; `AnyObject` şartı |
| [DeallocationProbe.swift](../BookShelf/Features/Interview/Demos/Memory/DeallocationProbe.swift) | `DeallocationProbe.waitForRelease(timeout:)`, `LeakRegistry` | Weak referansla sızıntı ölçmek; sızanlara zayıf referansla ulaşıp döngüyü kırmak |
| [MemoryLeakLabViewController.swift](../BookShelf/Features/Interview/Demos/Memory/MemoryLeakLabViewController.swift) | `leakVictimDidRequestClose(_:)`, `Status` | Modal + weak delegate ile kapatma; durumu tek `enum` ile modellemek |
| [LeakScenario.swift](../BookShelf/Features/Interview/Demos/Memory/LeakScenario.swift) | `LeakScenario`, `LeakMeasurement` | Senaryoların tutan zincirleri ve düzeltmelerin açıklaması |
| [StarRatingControl.swift](../BookShelf/Features/Interview/Demos/Delegation/StarRatingControl.swift) | `StarRatingControlDelegate`, `selectRating(_:)` | Kendi delegate protokolün; önce sor, sonra haber ver; protokol extension ile isteğe bağlı metot |
| [BookRatingViewController.swift](../BookShelf/Features/Interview/Demos/Delegation/BookRatingViewController.swift) | `connectRatingControl()` | Aynı olay üç kanaldan: weak delegate, `[weak self]` closure, target-action |
| [DelegateLifetimeExperiment.swift](../BookShelf/Features/Interview/Demos/Delegation/DelegateLifetimeExperiment.swift) | `DelegateLifetimeExperiment.run()` | Sahip ölür, kontrol yaşar: `weak` delegate `nil` olur |
| [OwnershipDiagramView.swift](../BookShelf/Features/Interview/Demos/Delegation/OwnershipDiagramView.swift) | `OwnershipDiagramView` | "Kim kimin sahibi?" şeması ve aynı kuralın diğer örnekleri |
| [RetainCycleDemo.swift](../BookShelf/Features/Fundamentals/StructVsClass/RetainCycleDemo.swift) | `LibraryCard` | strong / weak / unowned geri referans (UIKit'siz, saf Swift) |
| [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) | `startObservingFavorites()`, `configureTableView()` | Gerçek ekranda `[weak self]` + iptal; `tableView.delegate = self` |
| [MemoryLabVictimTests.swift](../BookShelfTests/MemoryDelegate/MemoryLabVictimTests.swift) | `MemoryLabVictimTests` | Her sızıntının ve düzeltmesinin testi; sızanların testte temizlenmesi |
| [DelegationStarRatingTests.swift](../BookShelfTests/MemoryDelegate/DelegationStarRatingTests.swift) | `testWeakDelegateDoesNotKeepOwnerAliveAndBecomesNil`, `testStrongDelegateCreatesCycleUntilDetached` | Weak delegate'in sahibi tutmaması, strong delegate'in döngüsü |
| [MemoryDelegateUITests.swift](../BookShelfUITests/MemoryDelegateUITests.swift) | `MemoryDelegateUITests` | Laboratuvar ve delegate demosunun UI testleri |

## Sık yapılan hatalar

**1. Temizliği `deinit`'e koymak.**

```swift
// YANLIŞ: Timer VC'yi tutuyor → deinit hiç gelmez → invalidate hiç çağrılmaz.
deinit { timer?.invalidate() }

// DOĞRU: Ekranın yaşam döngüsüne bağla.
override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    timer?.invalidate()
    timer = nil
}
```

**2. Delegate'i strong tanımlamak.**

```swift
// YANLIŞ: VC → kontrol → VC döngüsü.
var delegate: StarRatingControlDelegate?

// DOĞRU
weak var delegate: StarRatingControlDelegate?
```

**3. Protokolü class'a bağlamayı unutmak.**

```swift
// YANLIŞ: "'weak' must not be applied to non-class-bound 'any ReaderDelegate'"
protocol ReaderDelegate { func readerDidFinish() }

// DOĞRU
protocol ReaderDelegate: AnyObject { func readerDidFinish() }
```

**4. `[weak self]` yazıp işi bitti sanmak.**

```swift
// EKSİK: VC kurtulur ama task sonsuza dek döner, gözlemci bildirim almaya devam eder.
task = Task { [weak self] in while !Task.isCancelled { self?.refresh(); try? await Task.sleep(for: .seconds(1)) } }

// TAM: weak + viewDidDisappear'da durdurma.
task?.cancel()
NotificationCenter.default.removeObserver(token)
```

**5. Ömrü garanti olmayan bir referansı `unowned` yapmak.**

```swift
// YANLIŞ: Sahip önce ölürse bir sonraki olayda uygulama çöker.
unowned var delegate: StarRatingControlDelegate

// DOĞRU
weak var delegate: StarRatingControlDelegate?
```

**6. `delegate = self` atamasını unutmak.**
`delegate?.method()` `nil` üzerinde sessizce hiçbir şey yapmaz; ne hata ne uyarı alırsın, sadece callback'ler gelmez. Bağlantıyı `viewDidLoad`'da kur ve bir testle doğrula (bkz. `DelegationOwnerTests.testViewDidLoadWiresDelegateClosureAndTargetAction`).

**7. Her closure'a refleksle `[weak self]` yazmak.**
`items.map { self.format($0) }` gibi kaçmayan bir closure'da `[weak self]` gereksizdir ve kodu `self?` ile doldurup okunaklılığı düşürür. Önce sor: Bu closure, `self`'in tuttuğu bir yerde **saklanıyor** mu?

## Mülakatta sorulabilecekler

**1. ARC nasıl çalışır? Garbage collector'dan farkı ne?**
Derleyici güçlü referansların oluştuğu ve bittiği yerlere `retain`/`release` ekler. Sayı 0 olduğu anda `deinit` çalışır ve nesne yok edilir; bu deterministiktir. GC ise çalışma anında ulaşılamayan nesneleri arar; döngüleri de toplar ama ne zaman çalışacağı belli değildir. ARC döngüleri bulamaz; onları `weak`/`unowned` ile biz kırarız.

**2. Retain cycle'a üç UIKit örneği verir misin?**
Saklanan closure'da `self` (`onUpdate = { self.refresh() }`), strong delegate, target'ı `self` olan ve invalidate edilmeyen `Timer`. Bonus: block tabanlı NotificationCenter gözlemcisi ve hiç bitmeyen `Task`.

**3. `weak` ile `unowned` farkı?**
İkisi de sayacı artırmaz. `weak` Optional'dır ve nesne ölünce otomatik `nil` olur. `unowned` `nil` olmaz; ölmüş nesneye erişim çöker. Karşı taraf senden önce ölebiliyorsa `weak`, en az senin kadar yaşayacağı kesinse `unowned`.

**4. `[weak self]` ile `[self]` ve `[x]` farkı?**
`[weak self]` zayıf, `[self]` açıkça güçlü yakalar (örtük yakalamayla aynı davranış). `[x]` x'in o anki değerini yakalar; sonradan dıştaki x değişse closure eski değeri görür.

**5. Timer neden sızdırır, `[weak self]` neden yetmez?**
RunLoop zamanlanmış timer'ı, timer da target'ını invalidate edilene kadar güçlü tutar. Block tabanlı timer + `[weak self]` VC'yi kurtarır ama timer çalışmaya devam eder; `invalidate()` yine gerekir. Bunu `deinit`'e değil `viewDidDisappear`'a koyarım.

**6. Delegate'te kim delegate olur? Delegate neden weak?**
Sahip olan, uzun yaşayan taraf delegate olur; sahip olunan nesne protokolü tanımlar ve delegate'ini weak tutar. Sahip aşağıyı zaten strong tuttuğu için geri ok da strong olsaydı döngü olurdu. Protokol `AnyObject`'e bağlı olmalı.

**7. Delegate, closure, NotificationCenter: hangisini ne zaman seçersin?**
Delegate: 1'e 1, çok sayıda ilişkili callback ve değer döndüren sorular. Closure: tek olay, kısa ve yerel. NotificationCenter: 1'e çok yayın, taraflar birbirini tanımıyor. Zaman içinde akan değerler için AsyncStream ya da Combine.

**8. Bir sızıntıyı nasıl bulur ve nasıl test edersin?**
`deinit`'e log koyarım; Debug Memory Graph'ta tip başına örnek sayısına ve mor ünlemlere bakarım; Instruments'ta Leaks (ulaşılamayan döngüler) ve Allocations'ta Mark Generation (birikme) kullanırım. Testte nesneye weak referans tutup son güçlü referansı bırakır, `nil` olmasını beklerim.

**9. SwiftUI'da retain cycle olur mu?**
View'lar struct olduğu için view'un kendisi döngü kuramaz. Ama `@Observable`/`ObservableObject` view model'ler class'tır; kendi sakladığı closure'da, Combine sink'inde ya da bitmeyen bir `Task`'ta `self`'i güçlü tutarlarsa sızarlar. `.task` modifier'ı view kaybolunca görevi iptal ettiği için tercih edilir.

## Alıştırmalar

**1. Altıncı senaryo: Combine `sink`.**
`LeakScenario`'ya bir `combine` vakası ekle: Kurban bir `PassthroughSubject`'e `sink` ile abone olsun ve `AnyCancellable`'ı kendi `Set<AnyCancellable>`'ında saklasın. Sızdıran sürümde sink closure'ı `self`'i güçlü yakalasın. `MemoryLabVictimTests`'e sızıntı ve düzeltme testlerini ekle.
*İpucu:* Zincir VC → `cancellables` → abonelik → closure → VC. Düzeltme için `[weak self]` yeter; VC ölünce `cancellables` da yok olur ve abonelik iptal edilir.

**2. Yeniden kullanılabilir bir sızıntı yardımcısı yaz.**
`XCTestCase` için `trackForMemoryLeaks(_ object: AnyObject)` adında bir yardımcı yaz: `addTeardownBlock` içinde nesnenin `nil` olduğunu doğrulasın. `DelegationOwnerTests.makeLoadedOwner()` içinde kullan.
*İpucu:* `addTeardownBlock { [weak object] in XCTAssertNil(object, ...) }`. UIKit nesneleri için autorelease havuzunun boşalmasını beklemen gerekebilir; `DeallocationProbe.waitForRelease` gibi kısa bir bekleme ekle.

**3. `unowned` delegate'in çöktüğünü gör.**
`StarRatingControl.delegate`'i geçici olarak `unowned` yap (`unowned var delegate: (any StarRatingControlDelegate)?`; `unowned` varsayılan olarak `unowned(safe)`'tir) ve `DelegationOwnerTests.testOwnerIsReleasedWhileControlLivesAndDelegateBecomesNil` testini çalıştır. Çökme mesajını oku, sonra değişikliği geri al.
*İpucu:* Deney sahibi bıraktıktan sonra `control.delegate`'i okur. `weak` olsaydı `nil` dönerdi; `unowned` ise ölü nesneye erişildiği anda "Attempted to read an unowned reference but object ... was already deallocated" diye çöker.

**4. Bir delegate, iki kontrol.**
`BookRatingViewController`'a ikinci bir `StarRatingControl` ekle ("Kapak puanı"). Aynı VC ikisinin de delegate'i olsun; `starRatingControl(_:didChangeRating:)` içinde ilk parametreyi (`control === coverRatingControl`) kullanarak hangi etiketin güncelleneceğine karar ver.
*İpucu:* Cocoa'da delegate metotlarının ilk parametresinin gönderen nesne olmasının sebebi tam olarak budur.
