# UIKit (ve SwiftUI ile birlikte çalışması)

## Neden önemli?

- **Mevcut kodun büyük kısmı UIKit.** Yıllardır yayında olan uygulamaların çoğu UIKit ile yazıldı. Yeni ekranlar SwiftUI ile yazılsa bile, bir işe girdiğinde büyük ihtimalle UIKit kodunu okuyacak, düzeltecek ve SwiftUI ile birleştireceksin.
- **SwiftUI'ın altında çoğu zaman UIKit var.** iOS'ta `List`, `NavigationStack`, `TabView` gibi bileşenler perde arkasında büyük ölçüde UIKit nesneleriyle çizilir (bu bir uygulama ayrıntısıdır, sürümden sürüme değişebilir). Yaşam döngüsünü, hücre yeniden kullanımını ve bellek yönetimini bilmek, SwiftUI'daki garip davranışları da anlamanı sağlar.
- **Her şey SwiftUI'da yok.** Bazı API'ler (ör. bazı kamera/harita/metin düzenleme ihtiyaçları, eski üçüncü parti SDK'lar) hâlâ yalnızca UIKit ile gelir. `UIViewRepresentable` / `UIHostingController` köprülerini bilmek zorunludur.
- **Mülakatlarda klasik sorular buradan gelir:** view controller yaşam döngüsü, hücre yeniden kullanımı, delegate kalıbı, retain cycle, Auto Layout.

Bu projede **Favoriler** sekmesi bilerek UIKit ile yazıldı ve SwiftUI'ın içine gömüldü; detay ekranı ise yine SwiftUI. Yani iki yönlü köprünün ikisini de gerçek kodda görebilirsin.

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
   `true` iken UIKit, view'ın `frame`/autoresizing mask'ini constraint'lere çevirir; kodla constraint yazarken bunları istemediğimiz için `false` yaparız. `frame` view'ın **üst view'ın** koordinat sistemindeki konum ve boyutudur; `bounds` view'ın **kendi** koordinat sistemindeki dikdörtgenidir (origin genellikle (0,0); scroll view'da kaydırınca `bounds.origin` değişir).

8. **Swift 6'da UIKit ve concurrency: UI'ı arka plan thread'inden güncellemeyi derleyici nasıl engeller? `deinit` neden özel?**
   UIKit tipleri `@MainActor`'dır; ana actor dışından onlara senkron erişim derleme hatasıdır. VC içinde açılan `Task` ana actor'ü miras alır. `deinit` ise varsayılan olarak nonisolated'dır; içinde `@MainActor` metot çağıramazsın, ama `Sendable` bir `Task`'ı `cancel()` edebilirsin (thread-safe). Gerekirse Swift 6.2 `isolated deinit` kullanılır.

## Alıştırmalar

1. **Sıralama menüsü ekle.** Navigasyon çubuğunun soluna "Sırala" düğmesi koy; menüde "Katalog sırası", "Başlığa göre", "Yıla göre" seçenekleri olsun. Sıralama mantığını `FavoritesState`'e (UIKit'siz) ekle ve [FavoritesStateTests.swift](../BookShelfTests/Favorites/FavoritesStateTests.swift)'e test yaz.
   *İpucu:* `UIBarButtonItem(title:image:primaryAction:menu:)` ile bir `UIMenu` ver; seçili olanı `UIAction`'ın `state = .on` özelliğiyle işaretle. Türkçe başlıkları doğru sıralamak için `title.compare(other, locale: Locale(identifier: "tr_TR"))` kullan ("Ç", "İ", "Ş" harflerine dikkat). Seçim değişince son bilinen favori kümesiyle yeniden `render` etmen gerekecek; onu nerede saklayacağını düşün.

2. **Boş durumu `UIContentUnavailableConfiguration` ile yeniden yaz (iOS 17+).** `emptyStateLabel` yerine sistemin boş durum görünümünü kullan: SF Symbol'lü bir başlık, açıklama ve "Kitaplara git" gibi bir düğme.
   *İpucu:* `UIViewController`'ın `contentUnavailableConfiguration` özelliği ve `updateContentUnavailableConfiguration(using:)` metodu var; durum değişince `setNeedsUpdateContentUnavailableConfiguration()` çağır. `UIContentUnavailableConfiguration.empty()` ile başla. XCUITest'in hâlâ bulabilmesi için kimliği nereye koyacağını düşün ve `AccessibilityID.Favorites.emptyState` sözleşmesini koru.

3. **Sızıntıyı kendi gözünle gör.** `startObservingFavorites()` içindeki `[weak self]` kalıbını bilerek boz (ör. döngüden önce `guard let self else { return }` yaz) ve `testViewControllerIsReleasedWhileObservingAndDeinitCancelsTask` testini çalıştır. Sonra uygulamayı çalıştırıp Favoriler sekmesine birkaç kez girip çık ve Xcode'un **Debug Memory Graph** düğmesiyle kaç tane `FavoritesViewController` yaşadığına bak. En son kalıbı geri al.
   *İpucu:* Test "VC bellekten silinmeli" mesajıyla zaman aşımına uğramalı. Uygulamada sekme değiştirmek VC'yi silmez (SwiftUI `TabView` sekmeleri saklar); sızıntıyı görmek için `FavoritesView`'ı koşullu gösterip gizleyen küçük bir deneme ekranı ya da yalnızca test yeterli. Memory Graph'ta döngüyü oluşturan referans okları da görünür.
