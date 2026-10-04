# UIKit (ve SwiftUI ile birlikte çalışması)

## Neden önemli?

- **Mevcut kodun büyük kısmı UIKit.** Yıllardır yayında olan uygulamaların çoğu UIKit ile yazıldı. Yeni ekranlar SwiftUI ile yazılsa bile, bir işe girdiğinde büyük ihtimalle UIKit kodunu okuyacak, düzeltecek ve SwiftUI ile birleştireceksin.
- **SwiftUI'ın altında çoğu zaman UIKit var.** iOS'ta `List`, `NavigationStack`, `TabView` gibi bileşenler perde arkasında büyük ölçüde UIKit nesneleriyle çizilir (bu bir uygulama ayrıntısıdır, sürümden sürüme değişebilir). Yaşam döngüsünü, hücre yeniden kullanımını ve bellek yönetimini bilmek, SwiftUI'daki garip davranışları da anlamanı sağlar.
- **Her şey SwiftUI'da yok.** Bazı API'ler (ör. bazı kamera/harita/metin düzenleme ihtiyaçları, eski üçüncü parti SDK'lar) hâlâ yalnızca UIKit ile gelir. `UIViewRepresentable` / `UIHostingController` köprülerini bilmek zorunludur.
- **Mülakatlarda klasik sorular buradan gelir:** view controller yaşam döngüsü (özellikle `viewDidLayoutSubviews`), dinamik yükseklikli hücreler, `frame` ile `bounds` farkı, `UITableView` mı `UICollectionView` mı, delegate kalıbı, retain cycle, Auto Layout.

Bu projede **Favoriler** sekmesi bilerek UIKit ile yazıldı ve SwiftUI'ın içine gömüldü; detay ekranı ise yine SwiftUI. Yani iki yönlü köprünün ikisini de gerçek kodda görebilirsin.

**Mülakat** sekmesinin UIKit bölümünde dört canlı laboratuvar var (hepsi kodla yazılmış UIKit, SwiftUI'a `UIViewControllerRepresentable` ile gömülü): yaşam döngüsü günlüğü, açılıp kapanan self-sizing hücreler, döndürülebilen bir view ile frame/bounds, aynı kitapların üç farklı liste/ızgara görünümü. Her konunun "Demo" bölümünde lab'ı, "Kod" bölümünde hangi dosyada neye bakman gerektiğini bulursun.

## Temel kavramlar

### 1. Emredici (imperative) ve bildirimsel (declarative) arayüz

**SwiftUI (declarative):** "Durum şu olduğunda arayüz şöyle görünür" diye bir *tarif* yazarsın. Durum değişince framework `body`'yi yeniden hesaplar ve farkı kendisi uygular.

```swift
struct FavoritesSummary: View {
    let books: [Book]

    var body: some View {
        if books.isEmpty {
            Text("Henüz favori kitabın yok.")
        } else {
            List(books) { Text($0.title) }
        }
    }
}
```

**UIKit (imperative):** View nesnelerini sen oluşturur, hiyerarşiye sen eklersin. Veri değişince hangi view'ın nasıl değişeceğini **komutlarla** söylersin.

```swift
emptyStateLabel.isHidden = !books.isEmpty
tableView.isHidden = books.isEmpty
// ...ve tabloya yeni satırları uygula
```

Emredici kodda en sık hata, bir durumu güncelleyip diğerini unutmaktır ("liste doldu ama boş mesajı hâlâ görünüyor"). Bu projede bunu önlemek için tüm güncellemeleri tek bir `render(_ state:)` metodunda topladık: durum bir `enum` (`FavoritesState`), ekran ise o durumun bir yansıması. Bu, SwiftUI'ın fikrini UIKit'e taşımanın basit bir yoludur.

| | UIKit | SwiftUI |
|---|---|---|
| Arayüzü tarif etme | Nesneler + komutlar | Değer tipi `View` + `body` |
| Durum değişince | Sen güncellersin | Framework yeniden hesaplar |
| Yerleşim | Auto Layout (constraint'ler), `UIStackView` | `VStack`/`HStack`, modifier'lar |
| Ekran ömrü | `viewDidLoad`, `viewWillAppear`... | `onAppear`, `.task`, `onDisappear` |
| Liste | `UITableView`/`UICollectionView` + data source | `List`, `ForEach` |
| Navigasyon | `UINavigationController` (push/pop) | `NavigationStack` |

### 2. `UIViewController` yaşam döngüsü

Bir view controller ile onun **view'ı** farklı şeylerdir. VC oluşturulduğunda view henüz yoktur; ilk kez `view` özelliğine erişildiğinde yüklenir (lazy loading).

| Sıra | Metot | Kaç kez? | Ne için kullanılır? |
|---|---|---|---|
| 1 | `init(...)` | 1 | Bağımlılıkları almak. View'a dokunma. |
| 2 | `loadView()` | 1 | Kök view'ı **tamamen kendin** oluşturmak istersen (nadiren). Override edersen `super` çağırma, `view = ...` ata. |
| 3 | `viewDidLoad()` | 1 | Tek seferlik kurulum: alt view'lar, constraint'ler, delegate'ler. Boyutlar henüz kesin değil. |
| 4 | `viewWillAppear(_:)` | Her görünüşte | Ekran görünmek üzere: veriyi tazele, dinlemeyi başlat. |
| 5 | `viewIsAppearing(_:)` | Her görünüşte | iOS 17 SDK'sıyla geldi, iOS 13'e kadar geriye dönük çalışır. View hiyerarşide ve boyutları belli; boyuta/trait'lere bağlı son ayarlar için ideal. |
| 6 | `viewWillLayoutSubviews()` / `viewDidLayoutSubviews()` | Çok kez | Yerleşim her hesaplandığında. Ağır iş koyma. |
| 7 | `viewDidAppear(_:)` | Her görünüşte | Animasyon başlatma, analitik "ekran görüldü" olayı. |
| 8 | `viewWillDisappear(_:)` | Her kayboluşta | Kaybolmak **üzere**. Geçiş iptal edilebilir (ör. yarım bırakılan geri kaydırma). |
| 9 | `viewDidDisappear(_:)` | Her kayboluşta | Gerçekten kayboldu: dinlemeyi / zamanlayıcıları durdur. |
| 10 | `deinit` | 1 | Nesne bellekten silinirken. Sadece son temizlik. |

Önemli noktalar:

- `viewDidLoad` **bir kez**, `viewWillAppear` **her seferinde** çağrılır. Sekmeye her dönüşte veya üstteki ekrandan her geri gelişte `viewWillAppear` yeniden çalışır.
- Bu metotları override ederken **`super`'i çağır**. UIKit bazı işlerini oralarda yapar.
- SwiftUI karşılaştırması: SwiftUI'da `.task { for await ... }` modifier'ı, view görünürken bir task başlatır ve view kaybolunca **otomatik** iptal eder. UIKit'te bunu elle yaparız: `viewWillAppear`'da başlat, `viewDidDisappear`'da iptal et. [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) tam olarak bunu yapıyor.

**Nereye ne konur? (kısa kural)**

| İş | Yer | Neden |
|---|---|---|
| Bağımlılıkları almak | `init` | View'a dokunma: `view`'a erişmek onu hemen yükler. |
| Alt view, constraint, delegate, bir kez yapılan kurulum | `viewDidLoad` | Bir kez çalışır. |
| Görünüşe bağlı UI güncellemesi (trait'e, boyuta bağlı) | `viewIsAppearing` | Trait'ler, pencere ve geometri artık geçerli; `viewWillAppear`'dan sonra ama aynı karede. |
| Dinlemeyi / zamanlayıcıyı başlatmak | `viewWillAppear` | Her görünüşte. |
| Geometriye bağlı hesap (köşe yarıçapı, `convert`, çizim yolu) | `viewDidLayoutSubviews` | Frame'ler kesin; ama **çok kez** çağrılır → ucuz ve idempotent tut. |
| Dinlemeyi durdurmak | `viewDidDisappear` | Geçiş gerçekten bitti (`viewWillDisappear` iptal edilebilir). |
| Döndürme / pencere boyutu | `viewWillTransition(to:with:)` | Coordinator ile animasyona eşlik edilir. |
| Trait değişimi (koyu mod, size class, yazı boyutu) | `registerForTraitChanges(_:handler:)` (iOS 17+) | `traitCollectionDidChange` iOS 17'de deprecated. |

**`setNeedsLayout` ve `layoutIfNeeded`:** `setNeedsLayout()` yalnızca "bir sonraki çizimden önce yeniden yerleştir" diye işaretler; ucuzdur, hemen bir şey olmaz. `layoutIfNeeded()` işaret varsa yerleşimi **hemen ve senkron** yapar (constraint değişikliğini animasyon bloğu içinde uygulamanın klasik yolu). İkisi de yalnızca `viewWillLayoutSubviews` / `viewDidLayoutSubviews` çiftini tetikler; `viewDidLoad` tekrar çalışmaz, çünkü view zaten yüklüdür.

#### Lab'da gözlenen gerçek sıra (iOS 26.2 simülatörü, UI testiyle doğrulandı)

Yaşam döngüsü lab'ı ([LifecycleLabViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LifecycleLabViewController.swift)) üstte gözlenen bir "Ana" ekranı, altta canlı bir günlük gösterir. Ana, kendi `UINavigationController`'ının (çubuğu gizli) kök ekranıdır. Günlük satırları sadeleştirilmiş haliyle:

İlk görünüş:

```
Ana · init
Ana · willMove(toParent: UINavigationController)   ← nav controller'ın kökü olurken (init sırasında)
Ana · loadView
Ana · viewDidLoad
Ana · viewWillAppear
Ana · viewIsAppearing
Ana · viewWillLayoutSubviews
Ana · viewDidLayoutSubviews
Ana · viewDidAppear
Ana · didMove(toParent: UINavigationController)    ← geçiş bitince
```

`.fullScreen` ile sun, sonra "Kapat":

```
FullScreen · init → loadView → viewDidLoad
Ana        · viewWillDisappear
FullScreen · viewWillAppear → viewIsAppearing → (layout) → viewDidAppear
Ana        · viewDidDisappear
── Kapat (dismiss) ──
FullScreen · viewWillDisappear
Ana        · viewWillAppear → viewIsAppearing → viewDidAppear
FullScreen · viewDidDisappear
FullScreen · deinit
```

**Klasik tuzak, `.pageSheet`:** Aynı ekran `.pageSheet` ile sunulup kapatıldığında Ana'ya **hiçbir** `viewWillDisappear` / `viewDidDisappear` / `viewWillAppear` / `viewDidAppear` gelmez; yalnızca birkaç `viewWillLayoutSubviews` / `viewDidLayoutSubviews` gelir. Sebep: Sheet'te sunan ekranın view'ı pencereden çıkarılmaz, sheet onun üstünde durur. `.fullScreen`'de ise sunum bitince sunan ekranın view'ı pencereden kaldırılır; bu yüzden disappear (ve kapanışta yeniden appear) bildirimleri gelir. Pratik sonuç: "Sheet kapanınca listeyi tazelerim" diye `viewWillAppear`'a güvenme; sunulan ekran bir delegate ya da closure ile haber versin. Kullanıcının aşağı kaydırarak kapatmasını yakalamak için `presentationController?.delegate` + `presentationControllerDidDismiss(_:)` vardır (programatik `dismiss` sonrası çağrılmaz).

**Push:** `Push · viewDidLoad` → `Ana · viewWillDisappear` → `Push · viewWillAppear` → ... → `Ana · viewDidDisappear` → `Push · viewDidAppear`. Ana'nın içinde bir child VC varsa, o da Ana ile birlikte disappear alır: görünüş bildirimleri containment ağacında aşağı doğru iletilir.

**Child VC (containment):** Ekleme sırası `addChild` (child'a `willMove(toParent:)` otomatik gider) → `view.addSubview(child.view)` + constraint → `child.didMove(toParent: self)`. Çıkarma: `child.willMove(toParent: nil)` → `child.view.removeFromSuperview()` → `child.removeFromParent()` (`didMove(toParent: nil)` otomatik). Pencerede görünen bir ekrana eklenen child `viewWillAppear` … `viewDidAppear` bildirimlerini, çıkarılırken de `viewWillDisappear` … `viewDidDisappear` bildirimlerini kendiliğinden alır. Lab'da ilginç bir ayrıntı görülür: Hem eklemede hem çıkarmada günlükte `didMove(toParent:)` **iki kez** görünür; biri bizim çağrımız (ya da `removeFromParent`'ın), diğeri UIKit'in görünüş geçişi bitince yaptığı ek çağrı (iOS 26.2'de gözlendi; belgelenmiş bir davranış değil, bir uygulama ayrıntısı). Ders: `didMove(toParent:)` içine yalnızca bir kez yapılması gereken iş koyma.

**`deinit` ve ana actor:** `deinit` nonisolated'dır; ana actor'deki günlüğe senkron yazamaz. Lab bu yüzden iki `Sendable` değeri (günlük, ad) kopyalayıp `Task { @MainActor in ... }` açar ([LoggingViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LoggingViewController.swift)); "deinit" satırı günlüğe birkaç an sonra düşer. Swift 6.2'nin `isolated deinit`'i daha temiz olurdu, ama Xcode 26.3 (Swift 6.2.4) bu projede derlemeyi kırdı: Alt sınıf, `isolated deinit`'li üst sınıftan önceki bir dosyada derlenince emit-module adımı `'@preconcurrency' attribute cannot be applied to this declaration` hatası veriyor (dosya sırasına bağlı bir derleyici hatası; küçük bir örnekle yeniden üretildi).

### 3. `UITableView`, hücre yeniden kullanımı ve diffable data source

Bir tablo iki "yardımcı" nesneyle konuşur:

- **`dataSource`**: *Ne gösterilecek?* Kaç bölüm/satır var, şu satırın hücresi ne?
- **`delegate`**: *Etkileşim ve görünüm kararları.* Satıra dokunuldu, kaydırma eylemleri neler, satır yüksekliği ne?

**Hücre yeniden kullanımı (cell reuse):** 1000 satırlık bir tablo için 1000 hücre oluşturulmaz. Ekrana sığan kadar hücre oluşturulur; kaydırınca ekrandan çıkan hücre, yeni giren satır için geri dönüştürülür.

```swift
tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FavoriteBookCell")
// ...
let cell = tableView.dequeueReusableCell(withIdentifier: "FavoriteBookCell", for: indexPath)
```

Sonucu: **Hücreyi her seferinde baştan yapılandır.** Bir önceki satırın metni, görseli, rengi veya `accessibilityIdentifier`'ı üzerinde kalmış olabilir. (Özel hücre sınıflarında `prepareForReuse()` ile sıfırlama da yapılabilir.)

**Eski yöntem: `UITableViewDataSource` + `reloadData()`**

```swift
func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { books.count }
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { ... }

books.remove(at: 2)
tableView.reloadData() // Her şeyi baştan yükler; animasyon yok.
// veya animasyon için:
tableView.deleteRows(at: [IndexPath(row: 2, section: 0)], with: .automatic)
```

`deleteRows`/`insertRows` çağrıları ile veri dizisi birbirini tutmazsa uygulama meşhur *"Invalid update: invalid number of rows in section 0"* hatasıyla çöker. Değişiklikleri elle hesaplamak zordur.

**Yeni yöntem (iOS 13+): `UITableViewDiffableDataSource` + snapshot**

Tablonun **olması gereken son halini** bir *snapshot* olarak verirsin; data source eski ve yeni snapshot arasındaki farkı (diff) kendisi hesaplar, animasyonla uygular.

```swift
var snapshot = NSDiffableDataSourceSnapshot<Section, Book>()
snapshot.appendSections([.main])
snapshot.appendItems(books, toSection: .main)
dataSource.apply(snapshot, animatingDifferences: true)
```

**Neden `Book`'un `Hashable` olması önemli?** Diffable data source öğeleri kimliklerine göre ayırt eder: iki snapshot'taki iki öğe eşitse (`==`, ve buna uygun `hash`) "aynı satır" sayılır. Buradan iki sonuç çıkar:

1. Öğeler bir snapshot içinde **benzersiz** olmalı. Tekrar eden kimlikler çalışma anında hataya (aynı dizide tekrar varsa çökmeye) yol açar. Örneğin aynı kitabı iki kez listelemek istiyorsan öğe tipi `Book` olamaz; her satır için ayrı bir kimlik gerekir.
2. Öğe tipi olarak tüm `struct`'ı kullandığında, bir alanı değişen öğe *başka bir öğe* sayılır (satır silinip yeniden eklenir). `Book` değişmez (tüm alanları `let`) olduğu için bu projede sorun yok. İçeriği değişebilen öğelerde Apple'ın önerisi, öğe tanımlayıcısı olarak **kimliği** (`Book.ID`) kullanmak ve içerik değişince `snapshot.reconfigureItems([...])` (iOS 15+) çağırmaktır.

`reloadData` ile karşılaştırma: iOS 15'ten itibaren `apply(_:animatingDifferences: false)` da fark hesaplar, sadece animasyon yapmaz. Gerçekten her şeyi baştan yüklemek istersen `applySnapshotUsingReloadData(_:)` vardır.

**Hücre içeriği: `UIListContentConfiguration` (iOS 14+).** Eski `cell.textLabel?.text = ...` yerine hücrenin içeriğini tarif eden bir **değer tipi** oluşturup hücreye verirsin:

```swift
var content = cell.defaultContentConfiguration()
content.text = book.title
content.secondaryText = "\(book.author) · \(String(book.year))"
content.image = UIImage(systemName: "heart.fill")
cell.contentConfiguration = content
```

### 4. Auto Layout temelleri

Auto Layout, view'ların konum ve boyutlarını **denklemlerle** (constraint) tarif eder: `tableView.top = view.top`, `label.width = stack.width` gibi. UIKit bu denklemleri çözer ve her ekran boyutunda, döndürmede, Dynamic Type değişiminde yeniden hesaplar.

```swift
tableView.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(tableView)
NSLayoutConstraint.activate([
    tableView.topAnchor.constraint(equalTo: view.topAnchor),
    tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
])
```

- **`translatesAutoresizingMaskIntoConstraints = false`**: Varsayılan `true` iken UIKit, view'ın `frame`'ini sabitleyen otomatik constraint'ler üretir; seninkilerle çakışır. Kodla constraint yazdığın her view için `false` yap. (`UIStackView`'a `addArrangedSubview` ile eklenenlerde stack bunu kendisi yapar.)
- **Anchor API** tip güvenlidir: yatay bir anchor'ı (`leadingAnchor`) dikey birine (`topAnchor`) bağlamak derleme hatasıdır.
- **`NSLayoutConstraint.activate([...])`**: Toplu etkinleştirme; tek tek `isActive = true` yazmaktan hem okunaklı hem verimli.
- **`leading`/`trailing`** sağdan sola yazılan dillerde otomatik yer değiştirir; `left`/`right` değiştirmez. Neredeyse her zaman `leading`/`trailing` kullan.
- **Layout guide'lar**: `safeAreaLayoutGuide` (çentik, navigasyon/sekme çubukları dışında kalan alan), `layoutMarginsGuide` (sistem kenar boşlukları), `readableContentGuide` (uzun metin için okunabilir genişlik).
- **Intrinsic content size**: `UILabel`, `UIButton` gibi view'lar içeriklerinden doğal bir boyut önerir; bu yüzden onlara genellikle sadece konum constraint'i vermek yeter. İki view aynı alanı paylaşırken hangisinin büyüyüp küçüleceğini *content hugging* ve *compression resistance* öncelikleri belirler.
- **`UIStackView`** constraint sayısını çok azaltır ve `isHidden = true` olan elemanları otomatik olarak yerleşimden çıkarır. Favoriler ekranındaki yükleniyor / boş / hata görünümleri bu sayede tek bir yığında durur.

### 5. Delegate kalıbı, target-action ve `UIAction`

**Delegate (vekil):** Bir nesne bazı kararları ve olayları başka bir nesneye devreder. Tablo "şu satıra dokunuldu" der; ne yapılacağına VC karar verir.

```swift
tableView.delegate = self

extension FavoritesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { ... }
}
```

`delegate` özellikleri neredeyse her zaman **`weak`**'tir. Sebep: VC tabloyu güçlü tutar (view hiyerarşisi üzerinden); tablo da VC'yi güçlü tutsaydı ikisi birbirini hayatta tutardı (retain cycle). Kendi delegate protokolünü yazarken de `protocol MyDelegate: AnyObject` ve `weak var delegate: MyDelegate?` kullanılır.

**Target-action:** Klasik olay yönetimi. "Olay olunca `target` nesnesinin `action` metodunu çağır."

```swift
retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)

@objc private func retryButtonTapped() { ... }
```

Metot adı çalışma anında bir Objective-C mesajı olarak gönderildiği için `@objc` olmak zorundadır; `#selector` adı derleme anında doğrular. `UIControl` hedefini **zayıf** tutar, bu yüzden target-action retain cycle oluşturmaz.

**`UIAction` (iOS 14+):** Aynı işi closure ile yapar. Okuması kolaydır ama closure'ı kontrol tuttuğu için `self`'i **`[weak self]`** ile yakalamak gerekir:

```swift
UIBarButtonItem(title: "Tümünü temizle", primaryAction: UIAction { [weak self] _ in
    self?.presentClearAllConfirmation()
})
```

### 6. `UINavigationController`

Bir view controller **yığını** (stack) yönetir: `pushViewController(_:animated:)` üstüne yeni ekran ekler, geri düğmesi veya `popViewController(animated:)` en üsttekini çıkarır. Navigasyon çubuğunu da o çizer; her VC çubukta ne görüneceğini kendi `navigationItem`'ı ile söyler (`title`, `rightBarButtonItem`, `largeTitleDisplayMode`).

Bir VC'nin `navigationController` özelliği, onu içeren navigasyon denetleyicisini verir; hiçbir navigasyon yığınında değilse `nil`'dir. Bu yüzden `FavoritesView`, `FavoritesViewController`'ı bir `UINavigationController` içine sarar: SwiftUI'ın `TabView`'ı UIKit ekranımıza kendiliğinden bir yığın vermez.

### 7. Bellek yönetimi: ARC, retain cycle, closure'lar ve Task'lar

Swift, sınıf örneklerini **ARC** (Automatic Reference Counting) ile yönetir: bir nesneye kaç **güçlü** (strong) referans varsa sayılır; sayı sıfıra inince nesne silinir ve `deinit` çalışır. Çöp toplayıcı (garbage collector) yoktur; bu yüzden **döngüler** (A → B → A) kendiliğinden çözülmez.

Retain cycle'ın tipik kaynakları:

| Kaynak | Çözüm |
|---|---|
| Delegate güçlü tutuluyor | `weak var delegate` |
| Nesnenin sakladığı closure `self`'i yakalıyor (`UIAction`, completion handler, data source'un cell provider'ı) | `[weak self]` veya closure'da `self`'i hiç kullanmamak |
| `Task { }` `self`'i yakalıyor ve task hiç bitmiyor | `[weak self]` + task'ı iptal etmek |

**`weak` vs `unowned`:** `weak` her zaman `Optional`'dır; nesne silinince otomatik `nil` olur. `unowned` optional değildir; nesne silindikten sonra erişilirse uygulama **çöker**. Yalnızca referansın nesneden daha uzun yaşamayacağından *kesin* emin olduğunda `unowned` kullan; emin değilsen `weak`.

**Task'lar ve `self`:** `Task { }` closure'ını ve yakaladığı her şeyi **task bitene kadar** tutar. Kısa bir task'ta (`Task { await store.remove(id) }`) bu sorun değildir: task birkaç milisaniyede biter ve referansı bırakır. Ama `for await` ile bir akışı dinleyen task, akış bitmedikçe **hiç bitmez**. Böyle bir task `self`'i güçlü tutarsa VC asla silinmez, `deinit` asla çalışmaz, dolayısıyla task'ı iptal edecek kod da asla çalışmaz.

```swift
observationTask = Task { [weak self] in
    for await ids in await favorites.changes() {
        guard let self, !Task.isCancelled else { return } // güçlü referans yalnızca bu tur için
        self.render(.from(catalog: catalog, favoriteIDs: ids))
    }
}
```

**Swift 6 ve `deinit`:** `UIViewController` `@MainActor`'dır, ama `deinit` varsayılan olarak **nonisolated**'dır; son referans hangi thread'de bırakıldıysa orada çalışır. Bu yüzden `deinit` içinde `@MainActor` metotları çağıramazsın. `Task` `Sendable`'dır ve `cancel()` her thread'den güvenle çağrılabilir; bu yüzden `deinit { observationTask?.cancel() }` Swift 6'da temiz derlenir. Gövdenin ana actor'de çalışması gerçekten gerekiyorsa Swift 6.2'deki `isolated deinit` (SE-0371) kullanılabilir.

**Concurrency notu:** `UIViewController`, `UIView` ve diğer UIKit tipleri `@MainActor` ile işaretlidir. Bir VC metodunun içinde oluşturulan `Task { }` bu izolasyonu **miras alır**; yani gövdesi ana actor'de çalışır ve `await` noktalarında ana thread'i serbest bırakır. UI'ı güncellemek için ayrıca `DispatchQueue.main.async` veya `MainActor.run` gerekmez. Swift 6 dil modunda UIKit'e ana thread dışından dokunmaya çalışmak çoğu durumda **derleme hatasıdır**.

### 8. SwiftUI ↔ UIKit köprüleri

| Yön | API | Ne zaman? |
|---|---|---|
| SwiftUI içinde UIKit **view** | `UIViewRepresentable` | Tek bir `UIView` (ör. `MKMapView`, `WKWebView`, özel çizim yapan bir view) |
| SwiftUI içinde UIKit **view controller** | `UIViewControllerRepresentable` | Kendi yaşam döngüsü ve navigasyonu olan bir ekran (bu projede Favoriler) |
| UIKit içinde SwiftUI **ekranı** | `UIHostingController(rootView:)` | SwiftUI view'ını push etmek, modal açmak, child VC olarak eklemek |
| UIKit hücresinde SwiftUI | `UIHostingConfiguration` (iOS 16+) | Tablo/koleksiyon hücresinin içeriğini SwiftUI ile yazmak |

`UIViewControllerRepresentable`'ın parçaları:

- **`makeUIViewController(context:)`**: UIKit nesnesini **bir kez** oluşturur. SwiftUI, representable struct'ını defalarca yeniden oluşturabilir (ucuzdur); ama UIKit nesnesini, view ağaçtaki kimliğini koruduğu sürece saklar.
- **`updateUIViewController(_:context:)`**: SwiftUI tarafındaki girdiler (`@State`, `@Binding`, struct alanları, environment) değiştiğinde çağrılır. Görevi, yeni değerleri **mevcut** nesneye aktarmaktır; burada yeni nesne oluşturma.
- **`makeCoordinator()`** ve **`Coordinator`**: UIKit'in delegate/target-action olaylarını SwiftUI'a geri taşıyan yardımcı nesne (ör. bir `UITextField`'ın delegate'i olup metni bir `@Binding`'e yazmak). `context.coordinator` ile erişilir. Favoriler ekranında UIKit'ten SwiftUI'a veri akışı olmadığı için (tüm veri actor üzerinden akıyor) Coordinator gerekmedi.
- **`static func dismantleUIViewController(_:coordinator:)`** (isteğe bağlı): View ağaçtan kalkarken son temizlik.

`UIHostingController` sıradan bir `UIViewController`'dır; bu yüzden navigasyon yığınına push edilebilir:

```swift
let detail = UIHostingController(
    rootView: BookDetailView(book: book, dependencies: dependencies, favoriteButtonPlacement: .header)
)
detail.title = book.title
navigationController?.pushViewController(detail, animated: true)
```

**Köprünün bir sınırı:** SwiftUI'ın `.navigationTitle` ve `.toolbar` modifier'ları, view SwiftUI'ın kendi `NavigationStack`'inde gösterildiğinde navigasyon çubuğuna yansır. Bu projede aynı `BookDetailView` UIKit'in `UINavigationController`'ına `UIHostingController` ile push edildiğinde ise ne başlık ne de araç çubuğundaki kalp düğmesi UIKit çubuğuna taşındı. Bunu UI testi yakaladı (iOS 26.2 simülatörü): Favoriler'den açılan detayda `bookDetail.favoriteButton` erişilebilirlik ağacında hiç yoktu. Çözüm iki parçalı: Başlığı UIKit tarafı `detail.title` ile kendisi veriyor. Kalp düğmesi ise `favoriteButtonPlacement: .header` ile içeriğe, başlık bölümünün altına taşınıyor. Genel ders: `UIHostingController` ile gömülen bir ekranın navigasyon çubuğu öğelerini varsayma; UIKit tarafında `navigationItem`'ı kendin kur ya da düğmeyi içeriğe al ve bir UI testiyle doğrula ([XCUITest dersi](10-xcuitest.md)).

Bu projedeki "sandviç":

```
SwiftUI TabView (RootTabView)
  └─ FavoritesView: UIViewControllerRepresentable
       └─ UINavigationController
            ├─ FavoritesViewController (UIKit, UITableView)
            └─ UIHostingController<BookDetailView> (yine SwiftUI)
```

### 9. Dinamik yükseklikli (self-sizing) hücreler

Hücre yüksekliğini sen hesaplamazsın; **Auto Layout hücrenin içeriğinden hesaplar.** Tarif:

1. **Tablo:** `rowHeight = UITableView.automaticDimension` ve gerçeğe yakın, sıfırdan farklı bir `estimatedRowHeight`. (iOS 11'den beri ikisi de varsayılan olarak `automaticDimension`; açıkça yazmak niyeti belli eder.) `heightForRowAt`'te sabit bir değer döndürürsen o satırlarda self-sizing devre dışı kalır.
2. **Hücre:** Alt view'ları `contentView`'a ekle (hücrenin kendisine değil) ve constraint'leri `contentView`'un **üstünden altına kesintisiz** bağla. Zincirde bir halka eksikse (ör. alt kenara bağlanmamış bir label) yükseklik hesaplanamaz.
3. **Label:** `numberOfLines = 0` (sınırsız) ya da istediğin bir sınır; Dynamic Type için `preferredFont(forTextStyle:)` + `adjustsFontForContentSizeCategory = true`. Kullanıcı yazıyı büyütünce hücre kendiliğinden uzar.
4. **Konsolda `UIView-Encapsulated-Layout-Height` çakışması:** Tablo hücreyi ölçmeden önce ona geçici bir yükseklik verir; zincirin tamamı zorunluysa (1000) bu değerle çakışır. Dikey zincirden bir constraint'in (genellikle alttakinin) önceliğini 999 yapmak yeterli.

```swift
// BookSummaryCell.configureLayout() — kısaltılmış
let bottom = row.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
bottom.priority = .required - 1   // 999
NSLayoutConstraint.activate([
    row.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
    row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
    row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
    bottom,
])
```

**Klasik data source ve birden çok hücre tipi.** Mülakatta beklenen kalıp: `register` → `numberOfRowsInSection` → `cellForRowAt` içinde `dequeueReusableCell(withIdentifier:for:)`. Farklı hücre tiplerini tek tabloda göstermenin en okunur yolu satırları ilişkili değerli bir `enum` ile modellemek:

```swift
enum Row: Equatable {
    case author(name: String, bookCount: Int, index: Int)
    case book(Book)
}

func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch rows[indexPath.row] {
    case let .author(name, bookCount, index):
        let cell = tableView.dequeueReusableCell(withIdentifier: AuthorHeaderCell.reuseIdentifier, for: indexPath)
        (cell as? AuthorHeaderCell)?.configure(authorName: name, bookCount: bookCount, index: index)
        return cell
    case .book(let book):
        let cell = tableView.dequeueReusableCell(withIdentifier: BookSummaryCell.reuseIdentifier, for: indexPath)
        (cell as? BookSummaryCell)?.configure(with: book, isExpanded: expandedBookIDs.contains(book.id))
        return cell
    }
}
```

`for: indexPath` sürümü kayıtlı sınıftan her zaman bir hücre döndürür (kimlik kayıtlı değilse çöker); eski `dequeueReusableCell(withIdentifier:)` ise `nil` dönebilir.

**Yükseklik çalışırken değişirse (aç/kapa):**

```swift
func toggleBook(at indexPath: IndexPath) {
    // 1) Durum VC'de: hücreler yeniden kullanıldığı için "açık" bilgisi hücrede saklanmaz.
    // 2) Görünen hücreyi yerinde güncelle (reloadRows hücreyi baştan kurar, çapraz geçiş yapar).
    (tableView.cellForRow(at: indexPath) as? BookSummaryCell)?.setExpanded(isExpanded)
    // 3) Boş toplu güncelleme: veri değişmedi, tablo yükseklikleri yeniden sorup animasyonla uygular.
    tableView.performBatchUpdates(nil)   // eski yazımı: beginUpdates() + endUpdates()
}
```

`prepareForReuse()` yalnızca **geçici** durumu sıfırlamak içindir (süren bir resim indirmesi, açık/kapalı görünüm). İçeriği yine `cellForRowAt`'te her seferinde baştan ver. Modern alternatif: diffable data source + `UIListContentConfiguration` (Favoriler ekranı); self-sizing kuralları aynıdır, içerik değişince `snapshot.reconfigureItems(_:)`.

### 10. `frame` ve `bounds`

```
container (üst view); koordinatları (0,0)'dan başlar
│
│     ┌ ─ ─ ─ ─ ─ ─ ─ ┐   ← child.frame: dönmüş child'ı saran, eksen hizalı kutu
│           ╱╲              (container'ın koordinatlarında)
│     │   ╱    ╲      │
│       ╱ child  ╲
│     │ ╲        ╱    │
│         ╲    ╱
│     │     ╲╱        │
│     └ ─ ─ ─ ─ ─ ─ ─ ┘
│
child.bounds = (0, 0, 120, 80)   → kendi koordinatları; transform DEĞİŞTİRMEZ
child.center = (130, 130)        → container'ın koordinatlarında; transform DEĞİŞTİRMEZ
```

- **`frame`**: View'ın **üst view'ın** koordinat sistemindeki dikdörtgeni. "Babamın içinde neredeyim, ne kadar yer kaplıyorum?"
- **`bounds`**: View'ın **kendi** koordinat sistemindeki dikdörtgeni. Origin genellikle (0, 0), size içeriğin boyutu. Alt view'ların `frame`'i bu sisteme göredir. Bu yüzden bir alt view'ı üstünü kaplayacak şekilde yerleştirirken `child.frame = parent.bounds` yazılır, `parent.frame` değil.
- **`center`**: Üst view'ın koordinatlarında. `transform` katmanın `anchorPoint`'i (varsayılan orta nokta) etrafında uygulanır.
- **`transform` (döndürme/ölçek)**: `bounds` ve `center` değişmez; `frame` dönüşmüş view'ı saran kutuya döner. 100×100'lük bir view 45° dönünce frame ≈ 141×141 olur (100·√2). UIView.h açıkça uyarır: *dönüşmüş view'da frame'i kullanma, bounds + center kullan.* Apple'ın dokümantasyonu bu durumda frame'in değerini "tanımsız, yok sayılmalı" diye niteler. Pratikte okunan değer saran kutudur (lab ve birim testleri bunu gösterir), ama konumu/boyutu frame'e değer atayarak değiştirmeye kalkma.
- **`bounds.origin`'i değiştirmek**: Alt view'lar ekranda kayar ama `frame`'leri değişmez; çünkü frame'in tanımlı olduğu koordinat sisteminin kendisi kaydı. **`UIScrollView` tam olarak böyle kaydırır: `contentOffset` == `bounds.origin`.** Kaydırınca hiçbir alt view'ın frame'i değişmez.
- **`convert(_:to:)` / `convert(_:from:)`**: Bir dikdörtgeni/noktayı başka bir view'ın koordinatlarına çevirir. `view.convert(view.bounds, to: nil)` pencere koordinatlarını verir. Yerleşim bittikten sonra (ör. `viewDidLayoutSubviews`) çağır.

Lab ([FrameBoundsViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift)): gri bir container ve içinde mavi bir child var. Child Auto Layout kullanmıyor; `bounds` + `center` ile konumlanıyor. Kaydırıcılarla döndür / ölçekle / container'ın `bounds.origin.y`'sini kaydır; turuncu kesikli çerçeve `child.frame`'i container'ın koordinatlarında çizer, etiketler değerleri canlı gösterir. Sayfanın kendisi de bir `UIScrollView`; en alttaki satır kaydırdıkça `contentOffset.y` ile `bounds.origin.y`'nin hep eşit olduğunu gösterir.

### 11. `UITableView` mı `UICollectionView` mı?

| İhtiyaç | Seçim |
|---|---|
| Tek sütunlu, dikey liste; ayar ekranı, mesaj listesi | `UITableView` (ya da collection view + list configuration) |
| Satır kaydırma eylemleri, düzenleme modu (silme/taşıma), bölüm başlıkları | İkisi de: table'da hazır; collection view'da iOS 14+ list configuration ile |
| Izgara, kartlar, farklı yerleşimli bölümler | `UICollectionView` + compositional layout |
| Dikey sayfa içinde yatay kayan bölüm | `UICollectionView` + `orthogonalScrollingBehavior` |
| Tasarımın ileride değişmesi muhtemel | `UICollectionView` (layout'u değiştirmek view'ı değiştirmekten kolay) |

- **Tablo**nun yerleşimi sabittir: tek sütun, dikey. Bu kısıt aynı zamanda kolaylıktır; çok şey hazır gelir.
- **Collection view** yerleşim bilmez; neyin nerede duracağına bir layout nesnesi karar verir. **Compositional layout** (iOS 13+) parçaları: item → group → section → layout. Boyutlar `.fractionalWidth/Height`, `.absolute` ya da `.estimated` (self-sizing) ile verilir; section provider her bölüm için farklı yerleşim döndürebilir.
- **List configuration** (iOS 14+): `UICollectionViewCompositionalLayout.list(using: UICollectionLayoutListConfiguration(appearance: .insetGrouped))` collection view'ı tablo gibi gösterir. Apple bunu WWDC20'de ("Lists in UICollectionView") tablo benzeri listeler kurmanın modern yolu olarak tanıttı; `UITableView` ise deprecated değil ve yaygın biçimde kullanılmaya devam ediyor.
- **`CellRegistration`** (iOS 14+): Hücre ve öğe tipi generic parametredir; string reuse identifier ve `as!` dönüşümü yok. Kayıt, cell provider kapanışının **dışında** bir kez oluşturulur; içinde oluşturmak yeniden kullanımı engeller ve iOS 15+ çalışma anında istisna fırlatır.
- **Diffable kimlikleri benzersiz olmalı:** Aynı kitabı hem "öne çıkanlar"da hem "tüm kitaplar"da göstermek için öğe kimliği bölümü de içerir: `GridItem(section: .featured, bookID: 1)`. Aynı kimliği snapshot'a iki kez eklemek çalışma anında hata verir.
- **Gerçek bir tuzak (bu projede yaşandı):** iOS 16'daki `NSCollectionLayoutGroup.horizontal(layoutSize:repeatingSubitem:count:)` item'ın genişliğini **zorlamaz** (eski, deprecated `subitem:count:` zorluyordu). SDK başlık dosyası "count tekrarın gruba sığması çağıranın sorumluluğu" der. Item'a `.fractionalWidth(1)` verince her kart satırın tamamını kapladı ve ikinci sütun ekrandan taştı; çözüm `.fractionalWidth(1 / sütunSayısı)` ve boşluğu item'ın `contentInsets`'i ile vermek.

Lab ([TableVsCollectionViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionViewController.swift)): Aynı kitaplar üstteki seçiciyle üç biçimde: `UITableView`, list configuration'lı `UICollectionView` ve üstte yatay kayan "öne çıkanlar" + altta iki sütunlu ızgara. Üçü de diffable data source kullanır; değişen tek şey view ve yerleşim.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [FavoritesView.swift](../BookShelf/Features/Favorites/FavoritesView.swift) | `FavoritesView` (`UIViewControllerRepresentable`), `makeUIViewController`, `updateUIViewController` | SwiftUI içinde UIKit; neden `UINavigationController` ile sarıldığı; Coordinator notu |
| [FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift) | `viewDidLoad`, `viewWillAppear`, `viewDidDisappear`, `deinit` | Yaşam döngüsü; dinlemeyi başlatma/durdurma; nonisolated `deinit`'te iptal |
| aynı dosya | `startObservingFavorites()` | Ana actor'ü miras alan `Task`, `[weak self]`, `for await` ile `FavoritesStore.changes()` dinleme, iptal kontrolü |
| aynı dosya | `render(_:)`, `makeDataSource(for:)`, `configure(_:with:)` | Snapshot uygulama, hücre yeniden kullanımı, `UIListContentConfiguration`, `self` yakalamayan `static` cell provider |
| aynı dosya | `configureLayout()`, `configureStatusViews()` | Anchor'larla Auto Layout, layout guide'lar, `UIStackView` |
| aynı dosya | `tableView(_:didSelectRowAt:)`, `tableView(_:trailingSwipeActionsConfigurationForRowAt:)` | Delegate kalıbı; `UIHostingController` push (UIKit içinde SwiftUI); "Kaldır" kaydırma eylemi |
| aynı dosya | `clearAllButton`, `retryButtonTapped()`, `makeClearAllConfirmation()`, `clearAllFavorites()` | `UIAction` ile target-action karşılaştırması, `UIAlertController`, tek doğruluk kaynağı olarak actor |
| [FavoritesState.swift](../BookShelf/Features/Favorites/FavoritesState.swift) | `FavoritesState`, `from(catalog:favoriteIDs:)` | "Massive View Controller"dan kaçınmak; birbirini dışlayan durumlar için `enum`; `Set` sırası neden güvenilmez |
| [FavoritesStore.swift](../BookShelf/Core/Stores/FavoritesStore.swift) | `FavoritesStore.changes()` | Ekranın dinlediği `AsyncStream`; iptalde `onTermination` ile temizlik |
| [RootTabView.swift](../BookShelf/App/RootTabView.swift) | `RootTabView` | `FavoritesView`'ın SwiftUI `TabView`'ına yerleştirilmesi |
| [AccessibilityID+Favorites.swift](../Shared/AccessibilityID+Favorites.swift) | `AccessibilityID.Favorites` | UIKit'te `accessibilityIdentifier`; kimliği olmayan `UIContextualAction` ve iOS 26 alert düğmeleri için XCUITest notları |
| [FavoritesViewControllerTests.swift](../BookShelfTests/Favorites/FavoritesViewControllerTests.swift) | `simulateAppearance(of:)`, `waitUntil(...)`, `waitForCompletion(of:)`, `testViewControllerIsReleasedWhileObservingAndDeinitCancelsTask` | Pencere olmadan VC testi, polling ile async bekleme, iptal testi, `weak` referansla sızıntı testi |
| [FavoritesStateTests.swift](../BookShelfTests/Favorites/FavoritesStateTests.swift) | `FavoritesStateTests` | UIKit'siz, anında çalışan saf mantık testleri |
| [LoggingViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LoggingViewController.swift) | `LoggingViewController` | Her yaşam döngüsü override'ı (önce `super`), `loadView`'da `super` yok, `registerForTraitChanges`, nonisolated `deinit`'ten `Task` ile günlüğe yazmak |
| [LifecycleSubjectViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LifecycleSubjectViewController.swift) | `makeModal(style:)`, `pushDetail()`, `toggleChild()`, `relayout()` | `.pageSheet` vs `.fullScreen`, push, child VC containment sırası, `setNeedsLayout` + `layoutIfNeeded` |
| [LifecycleLogger.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LifecycleLogger.swift) | `LifecycleLogger`, `LifecycleLoggerDelegate` | Sahiplik: kap günlüğü güçlü, günlük kabı `weak delegate` ile tutar |
| [LifecycleLabViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LifecycleLabViewController.swift) | `LifecycleLabViewController` | Gözlenen ekranı çubuğu gizli bir `UINavigationController` içinde child VC olarak gömmek; neden kendisi günlüğe yazmıyor |
| [DynamicCellsViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/DynamicCellsViewController.swift) | `configureTableView()`, `tableView(_:cellForRowAt:)`, `toggleBook(at:)` | Klasik `UITableViewDataSource`, `enum` ile iki hücre tipi, `automaticDimension`, `performBatchUpdates(nil)` |
| [BookSummaryCell.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/BookSummaryCell.swift) | `configureLayout()`, `setExpanded(_:)`, `prepareForReuse()` | `contentView`'a üstten alta zincir, 999 öncelikli alt constraint, `numberOfLines`, gizlenen yığın elemanı |
| [FrameBoundsViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift) | `configureGeometry()`, `apply()`, `updateReadouts()`, `viewDidLayoutSubviews()`, `scrollViewDidScroll(_:)` | bounds + center ile konumlama, transform, `bounds.origin` kaydırma, `convert(_:to:)`, `contentOffset == bounds.origin` |
| [TableVsCollectionViewController.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionViewController.swift) | `makeTableDataSource`, `makeListDataSource`, `makeGridDataSource`, `GridItem` | Üç view, tek veri; `CellRegistration`, `SupplementaryRegistration`, benzersiz diffable kimlikleri |
| [TableVsCollectionLayouts.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionLayouts.swift) | `list()`, `featuredSection()`, `gridSection(columnCount:)` | List configuration, `orthogonalScrollingBehavior`, `repeatingSubitem:count:` tuzağı |
| [UIKitLabHost.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/Common/UIKitLabHost.swift) | `UIKitLabHost`, `UIKitLabBooksLoader` | Lab VC'lerini SwiftUI'a gömmek (çift navigasyon çubuğu olmadan); VC'lere servis değil `[Book]` vermek |
| [BookShelfTests/UIKitLabs](../BookShelfTests/UIKitLabs) | `LifecycleLabTests`, `DynamicCellsTests`, `FrameBoundsTests`, `TableVsCollectionTests` | Pencere olmadan VC testi, `systemLayoutSizeFitting` ile hücre ölçümü, √2 ve `contentOffset == bounds.origin` kanıtı |
| [UIKitLabsUITests.swift](../BookShelfUITests/UIKitLabsUITests.swift) | `testPageSheetKeepsPresenterVisibleButFullScreenTriggersDisappear` | Sunum stili farkının gerçek bir pencerede doğrulanması; günlük test raporuna ek (attachment) olarak düşer |

## Sık yapılan hatalar

**1. `translatesAutoresizingMaskIntoConstraints`'i unutmak**

```swift
// YANLIŞ: otomatik frame constraint'leri seninkilerle çakışır, konsolda
// "Unable to simultaneously satisfy constraints" görürsün ve view yanlış yerde durur.
view.addSubview(label)
label.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true

// DOĞRU
label.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(label)
NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
```

**2. Sonsuz task'ta `self`'i güçlü tutmak**

```swift
// YANLIŞ: `guard let self` döngüden ÖNCE → güçlü referans döngü boyunca (sonsuza dek) yaşar.
// VC hiç silinmez; deinit hiç çalışmaz.
observationTask = Task { [weak self] in
    guard let self else { return }
    for await ids in await self.dependencies.favorites.changes() {
        self.render(...)
    }
}

// DOĞRU: ihtiyaç duyulan değerleri önce yerel sabitlere al; `self`'i her turda kısa süreliğine aç.
let favorites = dependencies.favorites
observationTask = Task { [weak self] in
    for await ids in await favorites.changes() {
        guard let self else { return }
        self.render(...)
    }
}
```

`[weak self]` tek başına yetmez: görünmeyen ekranın dinlemeye devam etmemesi için task'ı `viewDidDisappear`'da (ve güvenlik ağı olarak `deinit`'te) **iptal** et.

**3. Yeniden kullanılan hücreyi eksik yapılandırmak**

```swift
// YANLIŞ: sadece favori olanlara simge koyuyoruz. Geri dönüştürülen hücrede
// önceki satırın simgesi kalır ve favori olmayan kitapta da kalp görünür.
if isFavorite { content.image = UIImage(systemName: "heart.fill") }

// DOĞRU: her dalda her özelliği ayarla.
content.image = isFavorite ? UIImage(systemName: "heart.fill") : nil
```

**4. Veriyi ve tabloyu ayrı ayrı güncellemek**

```swift
// YANLIŞ: iki doğruluk kaynağı. Actor'e yazmayı unutursan (veya başka ekran actor'ü değiştirirse)
// tablo ile gerçek veri ayrışır. Diziyle deleteRows tutmazsa çökme.
books.remove(at: indexPath.row)
tableView.deleteRows(at: [indexPath], with: .automatic)

// DOĞRU: sadece tek doğruluk kaynağını değiştir; tablo, akıştan gelen yeni snapshot ile güncellenir.
Task { await favorites.remove(book.id) }
```

**5. `updateUIViewController` içinde yeni nesne oluşturmak**

```swift
// YANLIŞ: her SwiftUI güncellemesinde yeni bir VC oluşturulur, durum kaybolur, performans düşer.
func updateUIViewController(_ controller: UINavigationController, context: Context) {
    controller.setViewControllers([FavoritesViewController(dependencies: dependencies)], animated: false)
}

// DOĞRU: nesneyi `makeUIViewController`'da bir kez oluştur; `update`'te sadece değişen değerleri aktar.
func updateUIViewController(_ controller: UINavigationController, context: Context) {}
```

**6. Delegate'i güçlü tutmak**

```swift
// YANLIŞ: VC → view → delegate (VC) döngüsü.
var delegate: ReaderDelegate?

// DOĞRU
protocol ReaderDelegate: AnyObject { func readerDidFinish() }
weak var delegate: ReaderDelegate?
```

**7. Boyuta bağlı hesabı `viewDidLoad`'da yapmak**

```swift
// YANLIŞ: viewDidLoad'da view.bounds henüz son boyutunu almamış olabilir.
override func viewDidLoad() { super.viewDidLoad(); cardView.layer.cornerRadius = view.bounds.width / 10 }

// DOĞRU: Auto Layout ile oranla ya da boyut belli olduktan sonra hesapla.
override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); cardView.layer.cornerRadius = view.bounds.width / 10 }
```

**8. `viewDidLayoutSubviews`'a bir kez yapılacak ya da layout'u yeniden bozan iş koymak**

```swift
// YANLIŞ: Her layout geçişinde yeni bir alt view ve constraint eklenir; layout her seferinde yeniden geçersiz olur.
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    view.addSubview(badge)
    badge.widthAnchor.constraint(equalToConstant: view.bounds.width / 4).isActive = true
}

// DOĞRU: Kurulum viewDidLoad'da; burada yalnızca ucuz ve idempotent geometri güncellemesi.
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    badge.layer.cornerRadius = badge.bounds.height / 2
}
```

**9. Sheet kapanınca `viewWillAppear`'ın çalışacağını sanmak**

```swift
// YANLIŞ: .pageSheet sunumundan dönünce alttaki ekranın viewWillAppear'ı ÇAĞRILMAZ; liste tazelenmez.
override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reloadNotes() }

// DOĞRU: Sunulan ekran haber versin (delegate/closure); kaydırarak kapatma için presentationControllerDidDismiss.
editor.onSave = { [weak self] in self?.reloadNotes() }
editor.presentationController?.delegate = self
```

**10. Self-sizing hücrede zinciri kırık bırakmak ya da yüksekliği sabitlemek**

```swift
// YANLIŞ: Alt kenara bağlanmayan label → yükseklik hesaplanamaz; heightForRowAt sabit → self-sizing kapanır.
label.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 44 }

// DOĞRU: Üstten alta kesintisiz zincir, heightForRowAt yok (ya da automaticDimension döndür).
NSLayoutConstraint.activate([
    label.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
    label.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
])
```

**11. Dönüşmüş view'ın frame'iyle çalışmak**

```swift
// YANLIŞ: transform varken frame tanımsız sayılır; sonuç beklenmedik konum/boyut olur.
card.transform = CGAffineTransform(rotationAngle: .pi / 8)
card.frame.origin.x += 20

// DOĞRU: Konum için center, boyut için bounds.
card.center.x += 20
```

**12. `CellRegistration`'ı cell provider'ın içinde oluşturmak**

```swift
// YANLIŞ: Her hücre için yeni kayıt → yeniden kullanım yok; iOS 15+ çalışma anında istisna.
UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
    let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { _, _, _ in }
    return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
}

// DOĞRU: Kayıt dışarıda bir kez; kapanış onu yakalar.
let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { cell, _, id in /* ... */ }
UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
    collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
}
```

## Mülakatta sorulabilecekler

1. **`viewDidLoad`, `viewWillAppear` ve `viewDidAppear` arasındaki fark nedir? Hangisinde ne yaparsın?**
   `viewDidLoad` view belleğe yüklendiğinde bir kez çalışır: tek seferlik kurulum (alt view'lar, constraint'ler, delegate'ler). `viewWillAppear` her görünüşten önce çalışır: veriyi tazelemek, dinlemeyi başlatmak. `viewDidAppear` ekran göründükten sonra: animasyon, analitik. Boyuta bağlı son ayarlar için `viewIsAppearing` veya `viewDidLayoutSubviews` daha uygundur.

2. **Hücre yeniden kullanımı nedir, neden var?**
   Tablo ekrana sığan kadar hücre oluşturur ve ekrandan çıkan hücreyi yeni satır için geri dönüştürür (`dequeueReusableCell`). Bellek ve kaydırma performansı içindir. Sonucu: hücre her yapılandırmada tüm özellikleriyle yeniden ayarlanmalı, yoksa önceki satırın durumu görünür.

3. **Diffable data source'un `reloadData`'ya göre avantajı nedir?**
   Tablonun son halini snapshot olarak verirsin; fark hesaplaması ve animasyonlu güncelleme otomatik yapılır. Satır sayısı uyumsuzluğundan doğan çökmeler ortadan kalkar. Öğeler `Hashable` ile ayırt edildiği için snapshot'taki öğeler benzersiz olmalıdır.

4. **Delegate neden genellikle `weak` tanımlanır? Delegate, closure ve `NotificationCenter` arasında nasıl seçim yaparsın?**
   Nesne ile delegate'i çoğu zaman sahip-sahipli ilişkisindedir (VC tabloyu tutar); delegate güçlü olsaydı retain cycle oluşurdu. Delegate: birden çok ilişkili callback ve bire bir ilişki. Closure: tek bir callback, kısa ve yerel. `NotificationCenter`: bire çok, birbirini tanımayan taraflar arasında yayın.

5. **Retain cycle nedir? `weak` ve `unowned` farkı nedir? `Task` ile nasıl oluşur?**
   İki (veya daha çok) nesnenin birbirini güçlü tutması; referans sayısı hiç sıfıra inmez, `deinit` çalışmaz. `weak` optional'dır ve nesne silinince `nil` olur; `unowned` optional değildir ve silinmiş nesneye erişim çöker. `Task` closure'ını bitene kadar tutar; hiç bitmeyen bir `for await` döngüsü `self`'i güçlü yakalarsa VC hiç silinmez. Çözüm: `[weak self]`, `self`'i döngü turu içinde açmak ve task'ı iptal etmek.

6. **SwiftUI'da UIKit, UIKit'te SwiftUI nasıl kullanılır? Coordinator ne işe yarar?**
   SwiftUI içinde UIKit: `UIViewRepresentable` / `UIViewControllerRepresentable` (`make...` bir kez, `update...` her girdi değişiminde). UIKit içinde SwiftUI: `UIHostingController(rootView:)` (hücreler için `UIHostingConfiguration`). Coordinator, UIKit'in delegate/target-action olaylarını SwiftUI tarafına (ör. `@Binding`) taşıyan yardımcı nesnedir.

7. **`translatesAutoresizingMaskIntoConstraints` nedir? `frame` ile `bounds` farkı nedir?**
   `true` iken UIKit, view'ın `frame`/autoresizing mask'ini constraint'lere çevirir; kodla constraint yazarken bunları istemediğimiz için `false` yaparız. `frame` view'ın **üst view'ın** koordinat sistemindeki konum ve boyutudur; `bounds` view'ın **kendi** koordinat sistemindeki dikdörtgenidir (origin genellikle (0,0); scroll view'da kaydırınca `bounds.origin` değişir, `contentOffset` tam olarak budur). Ayrıntı: bölüm 10 ve frame/bounds lab'ı.

8. **Swift 6'da UIKit ve concurrency: UI'ı arka plan thread'inden güncellemeyi derleyici nasıl engeller? `deinit` neden özel?**
   UIKit tipleri `@MainActor`'dır; ana actor dışından onlara senkron erişim derleme hatasıdır. VC içinde açılan `Task` ana actor'ü miras alır. `deinit` ise varsayılan olarak nonisolated'dır; içinde `@MainActor` metot çağıramazsın, ama `Sendable` bir `Task`'ı `cancel()` edebilirsin (thread-safe). Gerekirse Swift 6.2 `isolated deinit` kullanılır (bu projede Xcode 26.3'te alt sınıflı bir hiyerarşide derleyici hatasına takıldı; bkz. bölüm 2).

9. **`viewDidLayoutSubviews` ne zaman ve kaç kez çağrılır? İçine ne koyarsın?**
   Kök view'ın `layoutSubviews`'u her çalıştığında: ilk yerleşim, döndürme, boyut değişimi, `setNeedsLayout` + bir sonraki geçiş ya da `layoutIfNeeded`, alt view eklenmesi... Sayısı belli değildir. Frame'ler artık kesin olduğu için geometriye bağlı, ucuz ve idempotent işler (köşe yarıçapı, `convert`, çizim yolu) buraya konur; kurulum, ağ isteği ya da layout'u yeniden bozan değişiklik konmaz.

10. **`.pageSheet` ile `.fullScreen` sunumda alttaki ekranın yaşam döngüsü nasıl değişir?**
    `.fullScreen`'de sunum bitince alttaki ekranın view'ı pencereden çıkarılır: `viewWillDisappear`/`viewDidDisappear`, kapanışta `viewWillAppear`/`viewDidAppear` gelir. `.pageSheet`'te alttaki view pencerede kalır; bu dört çağrının hiçbiri gelmez (iOS 26.2'de lab ve UI testiyle doğrulandı). Veri tazelemek için delegate/closure ya da `presentationControllerDidDismiss(_:)` kullanılır.

11. **Self-sizing hücre nasıl yapılır? Yükseklik çalışırken değişirse ne yaparsın?**
    `rowHeight = automaticDimension` + sıfırdan farklı `estimatedRowHeight`; alt view'lar `contentView`'da, constraint'ler üstten alta kesintisiz; çok satırlı label'da `numberOfLines = 0`. Yükseklik değişince görünen hücreyi güncelleyip `performBatchUpdates(nil)` (ya da `beginUpdates`/`endUpdates`) çağırırsın; tablo hücreyi yeniden yüklemeden yükseklikleri yeniden sorar.

12. **`UITableView` mı `UICollectionView` mı?**
    Tek sütunlu dikey liste ve hazır davranışlar (kaydırma eylemleri, düzenleme) için table. Izgara, yatay kayan bölüm, farklı yerleşimli bölümler için compositional layout'lu collection view. iOS 14+ list configuration ile collection view tablo gibi de davranır; Apple bunu WWDC20'de liste kurmanın modern yolu olarak tanıttı, ama `UITableView` deprecated değil.

## Alıştırmalar

1. **Sıralama menüsü ekle.** Navigasyon çubuğunun soluna "Sırala" düğmesi koy; menüde "Katalog sırası", "Başlığa göre", "Yıla göre" seçenekleri olsun. Sıralama mantığını `FavoritesState`'e (UIKit'siz) ekle ve [FavoritesStateTests.swift](../BookShelfTests/Favorites/FavoritesStateTests.swift)'e test yaz.
   *İpucu:* `UIBarButtonItem(title:image:primaryAction:menu:)` ile bir `UIMenu` ver; seçili olanı `UIAction`'ın `state = .on` özelliğiyle işaretle. Türkçe başlıkları doğru sıralamak için `title.compare(other, locale: Locale(identifier: "tr_TR"))` kullan ("Ç", "İ", "Ş" harflerine dikkat). Seçim değişince son bilinen favori kümesiyle yeniden `render` etmen gerekecek; onu nerede saklayacağını düşün.

2. **Boş durumu `UIContentUnavailableConfiguration` ile yeniden yaz (iOS 17+).** `emptyStateLabel` yerine sistemin boş durum görünümünü kullan: SF Symbol'lü bir başlık, açıklama ve "Kitaplara git" gibi bir düğme.
   *İpucu:* `UIViewController`'ın `contentUnavailableConfiguration` özelliği ve `updateContentUnavailableConfiguration(using:)` metodu var; durum değişince `setNeedsUpdateContentUnavailableConfiguration()` çağır. `UIContentUnavailableConfiguration.empty()` ile başla. XCUITest'in hâlâ bulabilmesi için kimliği nereye koyacağını düşün ve `AccessibilityID.Favorites.emptyState` sözleşmesini koru.

3. **Sızıntıyı kendi gözünle gör.** `startObservingFavorites()` içindeki `[weak self]` kalıbını bilerek boz (ör. döngüden önce `guard let self else { return }` yaz) ve `testViewControllerIsReleasedWhileObservingAndDeinitCancelsTask` testini çalıştır. Sonra uygulamayı çalıştırıp Favoriler sekmesine birkaç kez girip çık ve Xcode'un **Debug Memory Graph** düğmesiyle kaç tane `FavoritesViewController` yaşadığına bak. En son kalıbı geri al.
   *İpucu:* Test "VC bellekten silinmeli" mesajıyla zaman aşımına uğramalı. Uygulamada sekme değiştirmek VC'yi silmez (SwiftUI `TabView` sekmeleri saklar); sızıntıyı görmek için `FavoritesView`'ı koşullu gösterip gizleyen küçük bir deneme ekranı ya da yalnızca test yeterli. Memory Graph'ta döngüyü oluşturan referans okları da görünür.

4. **Sheet kapanınca tazele.** Yaşam döngüsü lab'ında `.pageSheet` ile açılan ekran kapanınca Ana'nın günlüğüne "sheet kapandı" diye bir satır düşsün; hem "Kapat" düğmesiyle hem de aşağı kaydırarak kapatınca.
   *İpucu:* `viewWillAppear`'a güvenemezsin. "Kapat" için `LifecycleDetailViewController`'a bir `onClose` closure'ı ekle (`[weak self]` unutma); kaydırarak kapatma için sunmadan önce `modal.presentationController?.delegate = self` ve `presentationControllerDidDismiss(_:)`. İkincisinin programatik `dismiss` sonrası çağrılmadığını günlükte gör.

5. **Self-sizing'i bilerek boz.** [BookSummaryCell.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/DynamicCells/BookSummaryCell.swift)'te alt constraint'i kaldır ve `DynamicCellsTests` ile uygulamayı çalıştır. Sonra önceliği 999'dan 1000'e çıkarıp konsolda `UIView-Encapsulated-Layout-Height` uyarısını ara. En son geri al.
   *İpucu:* `testLongSummaryCellIsTallerThanShortSummaryCell` kırılmalı. Uyarı her zaman görünmeyebilir; tahmini yükseklik (`estimatedRowHeight`) ile gerçek yükseklik farkı büyüdükçe olasılık artar.

6. **Izgarada sütun sayısını ekran genişliğine bağla ve bir rozet ekle.** [TableVsCollectionLayouts.swift](../BookShelf/Features/Interview/Demos/UIKitLabs/TableVsCollection/TableVsCollectionLayouts.swift)'te `gridSection(columnCount:)` zaten section provider'dan sütun sayısı alıyor; iPad'de 4, iPhone yatayda 3 sütun olacak şekilde eşikleri düzenle. Ardından "öne çıkanlar" kartlarının köşesine `NSCollectionLayoutSupplementaryItem` ile "Yeni" rozeti ekle.
   *İpucu:* `environment.container.effectiveContentSize.width` ve `environment.traitCollection.horizontalSizeClass`. Rozet için `NSCollectionLayoutAnchor(edges: [.top, .trailing])` ve yeni bir `SupplementaryRegistration`; `TableVsCollectionTests`'e sütun sayısını doğrulayan bir test yaz.
