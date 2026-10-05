# XCUITest ile UI testleri

## Neden önemli?

- **Parçaları değil, birleşmiş uygulamayı test eder.** Birim testleri view model'leri, actor'leri, Objective-C sınıflarını tek tek doğrular. "Detay ekranında kalbe dokununca UIKit ile yazılmış Favoriler sekmesindeki tablo güncelleniyor mu?" sorusunu ise ancak uygulamayı gerçekten açıp dokunan bir test cevaplar. Bu soruda SwiftUI, UIKit, `FavoritesStore` actor'ü ve `AsyncStream` birlikte çalışır.
- **Birim testlerinin göremediği hataları yakalar.** Bu dersin testleri yazılırken gerçek bir hata bulundu: Favoriler sekmesinden açılan detay ekranında kalp düğmesi **hiç yoktu**. View model doğruydu ve birim testleri geçiyordu. Sorun, SwiftUI'ın `.toolbar`'ının `UIHostingController` üzerinden UIKit'in navigasyon çubuğuna taşınmamasıydı. Bunu yalnızca ekrana bakan bir test görebilirdi (ayrıntılar: [UIKit dersi](07-uikit.md)).
- **Pahalıdır, bu yüzden bilinçli kullanılmalıdır.** Bu projede yaklaşık 480 birim testi birkaç saniyede biterken yaklaşık 50 UI testi lokalde 15 dakika kadar sürüyor. UI testleri az ve kritik akışlara odaklı olmalı. Dersin sonundaki test piramidi bölümü bunu anlatıyor.
- **Mülakatta kesin çıkar.** "Flaky UI testleriyle ne yaparsın?", "accessibilityIdentifier ile accessibilityLabel farkı?", "UI testinde ağı nasıl taklit edersin?", "Page Object nedir?" standart sorulardır.

## Temel kavramlar

### 1. İki ayrı süreç: test çalıştırıcısı ve uygulama

UI testleri ayrı bir hedefte (`BookShelfUITests`) durur. Xcode bu hedef için **`BookShelfUITests-Runner.app`** adlı bir çalıştırıcı uygulama üretir. Testler bu süreçte koşar. `XCUIApplication().launch()` ise `BookShelf.app`'i **başka bir süreç** olarak başlatır.

```
BookShelfUITests-Runner.app (testler)            BookShelf.app (uygulama)
  app.buttons["bookList.row.8"].tap()   ──────▶   dokunma olayı (sentezlenmiş)
  app.staticTexts[...].label            ◀──────   erişilebilirlik ağacının anlık görüntüsü
```

Bunun sonuçları:

- **Uygulamanın kodunu çağıramazsın.** UI test paketi uygulamaya bağlanmaz; `@testable import BookShelf` işe yaramaz. `Book` tipini, view model'i, actor'ü göremezsin. Test, ekranda ne varsa yalnızca onu bilir.
- **İletişim tek yönlü ve dolaylıdır.** Uygulamaya bilgi başlatırken argüman ve ortam değişkenleriyle gider (Kavram 5). Uygulamadan bilgi ise erişilebilirlik ağacı üzerinden gelir (Kavram 2).
- **Ortak sabitler iki hedefe birden derlenir.** `Shared/` klasöründeki `AccessibilityID` ve `LaunchArgument` hem uygulamada hem UI testlerinde vardır. Bu yüzden kimlik metinleri iki yerde ayrı ayrı yazılmaz ve yazım hatası riski kalmaz ([Proje yapısı](01-proje-yapisi.md)).

**API senkrondur.** `tap()` bir `async` fonksiyon değildir, bitene kadar testi bekletir. Test logundaki her dokunuş şu adımlardan oluşur:

```
Tap "bookList.row.8" Button
    Wait for dev.learning.BookShelf to idle
    Find the "bookList.row.8" Button
    Check for interrupting elements affecting "bookList.row.8" Button
    Synthesize event
    Wait for dev.learning.BookShelf to idle
```

"Idle" beklemesi, uygulamanın ana thread'i ve animasyonları durulana kadar sürer. Ama XCUITest senin `Task`'larını, actor çağrılarını ya da ağ isteklerini **bilmez**. Dokunuştan sonra başlayan async bir iş bittiğinde ekranın güncellenmesini ayrıca beklemek gerekir (Kavram 6).

**Swift 6 notu:** `XCUIApplication`, `XCUIElement` ve `XCUIElementQuery` güncel SDK'da `@MainActor` olarak işaretli. Xcode 26'da bu tipler `XCUIAutomation` adlı ayrı bir çatıda duruyor (XCTest'in eski başlık dosyaları oraya yönlendiriyor); `import XCTest` onu da getirir. Bu yüzden bu tiplere dokunan her test metodu `@MainActor` olmalı. Test sınıfının tamamını değil, metotları işaretliyoruz; nedeni [XCTest dersinde](09-xctest.md) anlatılıyor.

### 2. Erişilebilirlik ağacı

XCUITest ekranı piksel olarak değil, **erişilebilirlik ağacı** (accessibility tree) olarak görür. Bu, VoiceOver'ın kullandığı yapının aynısıdır. Her düğümün bir **türü** (`Button`, `StaticText`, `Cell`...) ve öznitelikleri vardır: `identifier`, `label`, `value`, `frame`, `isEnabled`...

Ağacı görmek için testte `print(app.debugDescription)` yaz ya da bir kesme noktasında (breakpoint) `po app` de. Kitap listesinin gerçek çıktısından bir parça (iOS 26.2):

```
CollectionView, {{0.0, 0.0}, {402.0, 874.0}}, identifier: 'bookList.list'
  Cell, {{16.0, 168.0}, {370.0, 76.3}}
    Button, {{16.0, 168.0}, {370.0, 76.3}}, identifier: 'bookList.row.1', label: 'Tutunamayanlar, Oğuz Atay · 1972'
      StaticText, {{32.0, 185.0}, {128.0, 20.3}}, label: 'Tutunamayanlar'
      StaticText, {{32.0, 209.3}, {116.0, 18.0}}, label: 'Oğuz Atay · 1972'
```

SwiftUI ve UIKit öğelerinin ağaçtaki karşılıkları (bu projede görülenler):

| Kodda | Ağaçta |
|---|---|
| SwiftUI `List`, `Form` | `CollectionView` (satırlar `Cell`) |
| `NavigationLink`, `Button` | `Button` (içindeki metinler `label`'da virgülle birleşir) |
| `Text` | `StaticText` |
| `TextField` | `TextField` (yazılan metin `value`'da) |
| `Picker` + `.pickerStyle(.segmented)` | `SegmentedControl`, bölümleri `Button` |
| `.accessibilityElement(children: .contain)` olan kap | `Other` |
| `UITableView` / `UITableViewCell` | `Table` / `Cell` |
| `UIAlertController` | `Alert` |

Tür bilgisi önemlidir: `app.buttons[...]` yalnızca `Button` türündeki öğelere bakar. Mesela detay ekranındaki kalp düğmesi araç çubuğundayken ağaçta aynı kimlikle iki kez görünür: SwiftUI'ın sarmalayıcısı (`Other`) ve asıl düğme (`Button`). `app.buttons[...]` tek eşleşme bulur; türü önemsemeyen `app.descendants(matching: .any)[...]` ise "Multiple matching elements" hatası verirdi.

Ağacı incelemenin görsel yolu **Accessibility Inspector**'dır (Xcode → Open Developer Tool → Accessibility Inspector). Simülatördeki bir öğenin üzerine gelince kimliğini, etiketini ve değerini gösterir.

### 3. `XCUIApplication`, `XCUIElement`, `XCUIElementQuery`

- **`XCUIApplication`**: Test edilen uygulamanın vekilidir (proxy). `launch()`, `terminate()`, `launchArguments`, `launchEnvironment`, `state` gibi üyeleri vardır. Kendisi de ağacın kökü olan bir `XCUIElement`'tir.
- **`XCUIElementQuery`**: "Şu türdeki şu öğeleri bul" tarifi. `app.buttons`, `app.descendants(matching: .button)`'ın kısaltmasıdır. Sorgular zincirlenir:

```swift
app.tabBars.buttons["Favoriler"]                                   // sekme çubuğundaki düğmeler içinden
app.segmentedControls["fundamentals.structVsClass.experimentPicker"].buttons["ARC"]
app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "bookList.row."))
app.collectionViews.firstMatch.children(matching: .cell).element(boundBy: 0)
```

- **`XCUIElement`**: Sorgudan tek bir öğe seçer: alt simge (`["..."]`), `firstMatch`, `element(boundBy:)`. Alt simge öğeyi kimlikle arar; XCUITest'in eşleştirmesi erişilebilirlik kimliğinin yanında etiketi de kapsar. Sekme düğmelerini `buttons["Favoriler"]` diye etiketle bulabilmemizin sebebi bu. Logda bu sorgu `"x" IN identifiers` olarak görünür.

**`XCUIElement` bir sonuç değil, bir tariftir.** Oluşturulduğu anda hiçbir şey aramaz. Her kullanımda (`tap()`, `label`, `exists`) sorgu o anki ekranda yeniden çözülür. Bu yüzden:

- Ekran değiştikten sonra aynı `XCUIElement` değişkeni güvenle yeniden kullanılır.
- `exists` hata vermez; `true`/`false` döner. Ama olmayan bir öğeye `tap()` demek ya da `label`'ını okumak testi **kırar** ("No matches found").
- Birden fazla öğe eşleşirse eylem "Multiple matching elements" hatasıyla kırılır. `.firstMatch` ilk eşleşmeyi seçer ve ağacın tamamını taramadan durduğu için daha hızlıdır.

Sık kullanılan öznitelikler: `exists`, `isHittable` (dokunma noktası gerçekten bu öğeye düşüyor mu?), `isEnabled`, `label`, `value`, `placeholderValue`, `identifier`, `frame`.

### 4. Kimlik mi, etiket mi?

| | `accessibilityIdentifier` | `accessibilityLabel` |
|---|---|---|
| Kim için? | Sadece testler (kullanıcıya görünmez, VoiceOver okumaz) | Kullanıcı ve VoiceOver |
| Değişir mi? | Hayır, sabit bir sözleşme | Evet: çeviri, metin düzeltmesi, duruma göre değişen metin |
| Örnek | `"bookDetail.favoriteButton"` | `"Favorilere ekle"` → dokununca `"Favorilerden çıkar"` |

Kalp düğmesi iyi bir örnek. Etiketi duruma göre değişiyor; `app.buttons["Favorilere ekle"]` ile bulan bir test, dokunduktan sonra aynı düğmeyi **bulamaz**. Kimlik ise hiç değişmez. Durum bilgisi de etikete değil `accessibilityValue`'ya konur ("Favori" / "Favori değil"). Bu hem teste sabit bir değer verir hem de VoiceOver kullanıcısına durumu okur.

```swift
// SwiftUI
Button { ... } label: { Image(systemName: "heart") }
    .accessibilityLabel(isFavorite ? "Favorilerden çıkar" : "Favorilere ekle")
    .accessibilityValue(isFavorite ? AccessibilityID.BookValue.favorite : AccessibilityID.BookValue.notFavorite)
    .accessibilityIdentifier(AccessibilityID.BookDetail.favoriteButton)

// UIKit
tableView.accessibilityIdentifier = AccessibilityID.Favorites.table
cell.accessibilityIdentifier = AccessibilityID.Favorites.cell(bookID: book.id)
```

Kurallar:

- **Kimliği, testin sorgulayacağı öğenin tam kendisine ver.** Düğmeyse `Button`'a, okunacak bir değerse o değeri taşıyan `Text`'e. Laboratuvardaki sonuç satırlarında simge ve metin bir `HStack`'te duruyor ve kimlik `HStack`'e değil `Text`'e veriliyor. Böylece `app.staticTexts[...]` tam o metni okuyor.
- **Kimliği olan bir kap** (container) içindeki öğeler kendi kimliklerini korumalı. Hata ekranı `.accessibilityElement(children: .contain)` ile bir kap yapıldı. `List`/`Form`'a verilen kimlik de (`bookList.list`, `lab.form`) yalnızca kaba (`CollectionView`) gider.
- **Etiket mecburen kullanılıyorsa** metni `Shared/` altındaki bir sabitten al ki uygulama ve test aynı metni kullansın. Bu projede üç yerde böyle: Sekme düğmeleri (`AccessibilityID.Tab`), satır kaydırma eylemi "Kaldır" (`UIContextualAction` bir `UIView` değil, kimliği yok) ve segmented `Picker`'ın bölümleri.
- **Sistemin ürettiği öğelerin kimliğine güvenme.** iOS 26 simülatöründe sekme düğmelerinin kimliği bazen boş, bazen seçili sekmenin SF Symbol adı (Favoriler seçiliyken `heart`, Laboratuvar seçiliyken `flask`). Geri düğmesinin kimliği iOS 26'da `"BackButton"`, ama bu sürüme bağlı bir ayrıntı. `Screen.tapBackButton()` bu yüzden navigasyon çubuğundaki **ilk** düğmeye dokunuyor.

### 5. Test modu: `launchArguments` ve `launchEnvironment`

UI testi uygulamanın kodunu değiştiremez, ama uygulamaya **nasıl başlayacağını** söyleyebilir:

```swift
// Test tarafı (BookShelfUITestCase.launchApp)
let app = XCUIApplication()
app.launchArguments = [LaunchArgument.uiTesting, LaunchArgument.simulateNetworkError]
app.launchEnvironment = ["BOOKSHELF_API_URL": "http://localhost:8080"]   // örnek; bu projede kullanılmıyor
app.launch()

// Uygulama tarafı (AppDependencies.makeForLaunch)
let arguments = ProcessInfo.processInfo.arguments
let isUITesting = arguments.contains(LaunchArgument.uiTesting)
let service = LocalBookService(
    latency: isUITesting ? .zero : .milliseconds(600),
    simulatesFailure: arguments.contains(LaunchArgument.simulateNetworkError)
)
```

Bu projede `-ui-testing` şunları yapar:

| Nerede? | Ne değişir? | Neden? |
|---|---|---|
| `AppDependencies.makeForLaunch(arguments:)` | Servis gecikmesi 600 ms → 0 | Hızlı ve deterministik testler |
| `BookShelfApp.init()` | `UIView.setAnimationsEnabled(false)` | Animasyonlar "idle" beklemesini uzatır ve geçiş sırasında öğeler iki yerde görünebilir |
| `ConcurrencyLab.Settings.uiTesting` | Paralellik işleri kısalır; uzun iş 40 kısa adım (≈ 6 sn) sürer | Testler hızlı kalır ama "İptal et"e yetişmek için güvenli bir zaman payı olur |

`-simulate-network-error` ise servisin her istekte hata fırlatmasını sağlar. Böylece hata ekranı, gerçek ağı kesmeden test edilir (`ErrorStateUITests`).

Bu, bağımlılık enjeksiyonunun (dependency injection) UI testlerindeki karşılığıdır. Ekranlar somut servise değil `BookServiceProtocol`'e bağlı olduğu için, başlatma anında hangi uygulamanın (implementation) verileceği tek bir yerde seçilir. Gerçek bir sunucu kullanan uygulamalarda aynı fikir `launchEnvironment` ile bir test sunucusunun adresini vermek ya da uygulamaya gömülü sahte bir servis seçmek şeklinde uygulanır.

**Her `launch()` sıfırdan başlar.** Uygulama zaten çalışıyorsa önce kapatılır. Favoriler bellekte tutulduğu için her test boş bir listeyle açılır ve testler birbirini etkilemez. Diske yazan bir uygulamada (UserDefaults, dosya, veritabanı) bu bağımsızlık kendiliğinden gelmez. O zaman "test modunda kalıcı durumu sıfırla" diyen bir argüman eklemek gerekir.

### 6. Beklemek: `waitForExistence`, predicate expectation

Dokunuşla ekranın güncellenmesi arasında zaman geçer. Kalbe dokununca bir `Task` açılır, `FavoritesStore` actor'ü `await` edilir, sonra `@Observable` view model değişir ve SwiftUI yeniden çizer. Dokunuştan hemen sonra `value`'yu okuyan test eski değeri görebilir.

**Yanlış çözüm `sleep(2)`'dir.** Hızlı makinede boşa bekler, yavaş CI makinesinde yetmez. Doğru çözüm **beklenen koşulu tarif edip** bir üst sınırla beklemektir:

```swift
// Öğe görünene kadar (en fazla 10 sn). Bool döner, kendisi testi kırmaz.
XCTAssertTrue(detail.title.waitForExistence(timeout: 10))

// Öğe kaybolana kadar (Xcode 16 ile geldi)
XCTAssertTrue(favorites.cell(bookID: 1).waitForNonExistence(timeout: 10))

// Bir özniteliğin belirli bir değere gelmesi (Xcode 16 ile geldi, key path ile)
XCTAssertTrue(detail.title.wait(for: \.label, toEqual: "Huzur", timeout: 10))

// Genel yol: herhangi bir NSPredicate
let isFavorite = NSPredicate(format: "value == %@", AccessibilityID.BookValue.favorite)
let expectation = XCTNSPredicateExpectation(predicate: isFavorite, object: detail.favoriteButton)
XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed)
```

- **Süre bir gecikme değil, üst sınırdır.** Koşul sağlandığı an bekleme biter. Bu yüzden cömert süreler geçen testleri yavaşlatmaz; sadece bir hatanın ne kadar sonra raporlanacağını belirler. Bu projedeki süreler `UITestTimeout`'ta toplanmış (açılış 20 sn, normal 10 sn, uzun işlemler 30 sn).
- **`XCTWaiter().wait` ile `wait(for:timeout:)` farkı:** `XCTestCase.wait(for:timeout:)` zaman aşımında testi kendisi kırar. `XCTWaiter().wait` ise sonucu (`.completed`, `.timedOut`...) döndürür. Bu projedeki yardımcılar ikincisini kullanıyor ve hata mesajını **gerçek değerle** kendileri yazıyor:

```
XCTAssertTrue failed - Label /İptal edildi: ([0-9]|[1-3][0-9]) / 40 adımda durdu/ kalıbına uymuyor. Gerçek: "Tamamlandı: 40 / 40"
```

(Bu mesaj, "İptal et"i bilerek bozduğumuz bir denemeden alındı; bkz. Alıştırmalar öncesindeki not.)

- **Olmayan öğenin özniteliğini okuma.** Predicate'ler `exists == true AND label == %@` biçiminde yazıldı. `AND` ilk koşul yanlışsa ikincisini değerlendirmez; böylece henüz görünmeyen bir öğe için "No matches found" hatası yerine sadece "henüz değil" sonucu çıkar.

Bu projede bekleme, doğrulamanın parçası: `assertLabel(_:equals:)`, `assertValue(_:equals:)`, `assertAppears(_:)`, `assertDisappears(_:)` (`BookShelfUITestCase`). Her biri önce bekler, başarısız olursa gerçek değeri yazar ve hatayı `file:line:` ile testteki satıra bağlar.

### 7. Tembel listeler, kaydırma ve `isHittable`

SwiftUI `List`/`Form` ve `UITableView` **tembeldir** (lazy): yalnızca ekrana giren satırları oluşturur. Ekranın altındaki bir satır erişilebilirlik ağacında henüz **yoktur**. `waitForExistence` onu 10 saniye boyunca da arasa bulamaz. Laboratuvar ekranında "Actor: 1000 / 1000" satırı, sayfa kaydırılana kadar ağaçta yoktu.

Bir de iOS 26'nın **yüzen sekme çubuğu** var. Liste onun altından da akar. Sekme çubuğunun altında kalan bir satır ağaçta "var" ama ona dokunmak sekme çubuğuna dokunmak olur. `isHittable` tam bunu söyler: Öğenin dokunma noktası gerçekten ona mı düşüyor?

```swift
// XCUIElement+Waiting.swift
@discardableResult
func scrollUp(toReveal target: XCUIElement, maxSwipes: Int = 8) -> Bool {
    var swipes = 0
    while !(target.exists && target.isHittable) {
        guard swipes < maxSwipes else { return false }
        swipeUp(velocity: .slow)
        swipes += 1
    }
    return true
}
```

Kaydırma kabın kendisine uygulanır (`lab.form`, `bookList.list`, `bookDetail.list`). Koordinat yoktur; bu yüzden farklı ekran boyutlarında da aynı şekilde çalışır. `.slow` hız, hedefi atlayıp geçmeye yol açacak ivmeyi azaltır. `maxSwipes` ise liste bittiğinde sonsuz döngüyü önler.

### 8. Page Object kalıbı

Testler doğrudan `app.buttons["bookList.row.8"].tap()` yazsaydı, bir kimlik ya da ekran yapısı değiştiğinde onlarca testi tek tek düzeltmek gerekirdi. **Page Object** (ekran nesnesi) kalıbında her ekran için bir tip yazılır. Bu tip, ekrandaki öğeleri nasıl bulacağını ve ekranda neler yapılabileceğini bilir:

```swift
@MainActor
protocol Screen {
    var app: XCUIApplication { get }
    var rootElement: XCUIElement { get }   // ekran açıkken HER ZAMAN var olan öğe
}

@MainActor
struct BookListScreen: Screen {
    let app: XCUIApplication
    var rootElement: XCUIElement { list }
    var list: XCUIElement { app.collectionViews[AccessibilityID.BookList.list] }

    func row(bookID: Int) -> XCUIElement { app.buttons[AccessibilityID.BookList.row(bookID: bookID)] }

    func openBook(id bookID: Int, file: StaticString = #filePath, line: UInt = #line) -> BookDetailScreen {
        revealRow(bookID: bookID).tap()
        return BookDetailScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }
}
```

Test ise kullanıcının niyetini anlatır:

```swift
let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()
let detail = bookList.openBook(id: 2)
detail.toggleFavorite()
assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.favorite)
let favorites = detail.tabBar.openFavorites().waitUntilDisplayed()
assertAppears(favorites.cell(bookID: 2))
```

Bu projedeki kararlar:

- **Ekranlar `struct`.** Durumları yoktur, sadece `app`'i taşırlar. Öğeler hesaplanan özelliktir, çünkü `XCUIElement` zaten bir sorgu tarifidir.
- **Navigasyon tip taşır.** `openBook(id:)` bir `BookDetailScreen`, `tabBar.openFavorites()` bir `FavoritesScreen` döndürür. Hangi ekranda olduğun kodun tipinden okunur.
- **Doğrulama testte yapılır.** Ekran nesnesi öğeleri ve eylemleri sunar, "doğru mu?" kararını test verir. Tek istisna ekranın açıldığını doğrulayan `waitUntilDisplayed()`; o navigasyonun bir parçası.
- **`file:line:` iletilir.** Ekran nesnesinin içindeki bir doğrulama başarısız olursa Xcode hatayı ekran dosyasında değil, testteki çağrı satırında gösterir.
- **Farklar tek yerde saklanır.** Kalp düğmesi SwiftUI'dan açılınca araç çubuğunda, UIKit'ten açılınca içerikte duruyor. Kimliği aynı olduğu için `BookDetailScreen.favoriteButton` iki durumda da çalışıyor; testler bu farkı hiç bilmiyor. "Tümünü temizle" penceresindeki düğmelerin ağaçta iki kez görünmesi (`.firstMatch` gerekiyor) de yalnızca `FavoritesScreen`'de biliniyor.

### 9. Okunabilir raporlar: `XCTContext.runActivity` ve ekler

Uzun bir UI testi kırıldığında "hangi adımda?" sorusu önemlidir. `XCTContext.runActivity(named:)` testi adlandırılmış adımlara böler. Xcode'un test raporunda ve `.xcresult` paketinde her adım ayrı bir satır olur, başarısız olan adım işaretlenir. Blok bir değer de döndürebilir:

```swift
let detail = XCTContext.runActivity(named: "Favori hücresine dokun: UIKit içinde SwiftUI detay açılır") { _ in
    favorites.openBook(id: 3)
}
```

**Ekler (attachment)** rapora dosya ekler: ekran görüntüsü, metin, JSON...

```swift
XCTContext.runActivity(named: "Ekranın üst kısmının görüntüsünü rapora ekle") { activity in
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Kitap detayı - Tutunamayanlar"
    screenshot.lifetime = .keepAlways   // varsayılan: .deleteOnSuccess
    activity.add(screenshot)
}
```

- Varsayılan ömür **`.deleteOnSuccess`**: Test geçerse ek silinir. Ekler çoğunlukla hata ayıklamak için olduğundan mantıklı bir varsayılan. Her zaman görmek istediğin ekler için `.keepAlways` kullan.
- Ekleri görmek için Xcode'da Report navigator'ı (⌘9) aç, sonra testi ve adımı seç. Komut satırında: `xcrun xcresulttool export attachments --path build/results/ui.xcresult --output-path /tmp/ekler`.
- Xcode 26.3 ile başarısız bir UI testi için `.xcresult`'a kendiliğinden ekran kaydı (video) ve uygulamanın UI hiyerarşisi de ekleniyor (bu dersin denemelerinde görüldü). CI'da `.xcresult` artifact olarak saklandığı için ([CI dersi](11-ci.md)) kırılan bir testi makineye erişmeden inceleyebilirsin.

### 10. Flaky testler: nedenleri ve çareleri

**Flaky test**, kod değişmediği halde bazen geçip bazen kalan testtir. UI testlerinde en sık görülen sebepler ve bu projedeki çareleri:

| Sebep | Belirti | Bu projedeki çare |
|---|---|---|
| Sabit süreli bekleme (`sleep`) | Yavaş makinede kırılır | Koşul bekleyen `assert...` yardımcıları |
| Ağ gecikmesi, gerçek sunucu | Süre ve sonuç değişken | `-ui-testing`: sıfır gecikmeli, paketteki JSON'dan okuyan servis |
| Animasyonlar | Geçiş sırasında öğe iki yerde, "idle" gecikir | `UIView.setAnimationsEnabled(false)` |
| Değişen metinle sorgu | Çeviri ya da durum değişince bulunamaz | Kimlik + `accessibilityValue` |
| Testler arası paylaşılan durum, sıra bağımlılığı | Tek başına geçer, toplu koşuda kalır | Her test `launchApp()` ile sıfırdan başlar |
| Tembel liste, sekme çubuğu altı | Küçük ekranda bulunamaz ya da dokunuş sekme çubuğuna gider | `scrollUp(toReveal:)` + `isHittable` |
| Zamanlamaya bağlı akış | İş, "İptal et"e dokunmadan biter | Test modunda uzun iş ≈ 6 sn; test sayıyı değil "bitmeden durdu" kuralını doğrular |
| Yarışlı ya da ölçülen değerler | Değer her koşuda farklı | Regex ile biçim: `Kilitsiz class: [0-9]+ / 1000...`, `TaskGroup: [0-9]+,[0-9]+ sn` |
| Birden çok eşleşme | "Multiple matching elements" | Türe özgü sorgu (`app.buttons`), gerekirse `.firstMatch` |
| Sistem uyarıları (izin pencereleri) | Beklenmeyen pencere dokunuşu engeller | `addUIInterruptionMonitor`, `resetAuthorizationStatus(for:)` (bu projede izin yok) |
| Paylaşılan / görünür simülatör | Dışarıdan bir dokunuş uygulamayı arka plana atar | Her koşu için ayrı simülatör (`SIMULATOR_ID`) |

Son satır bu dersi yazarken yaşandı: İlk deneme koşusunda test dışından gelen dokunuşlar (sekme değişimi, ana ekrana dönme hareketi) uygulamayı arka plana attı ve test "application is not running" hatasıyla düştü. Ekran kaydı, testin yapmadığı hareketleri gösteriyordu. Kodda hata yoktu; yeniden koşunca geçti. Çözüm, UI testlerini kimsenin elle kullanmadığı, o iş için oluşturulmuş bir simülatörde koşmak.

**Tekrar deneme (retry) son çaredir.** `scripts/ci.sh ui`, başarısız bir UI testini bir kez daha dener (`-retry-tests-on-failure -test-iterations 2`). Bu, bizden bağımsız tek seferlik aksaklıklara karşı bir sigortadır; flaky bir testi düzeltmenin yerini tutmaz. Bu projedeki UI testleri art arda tam koşularda, tekrar denemeye hiç ihtiyaç duymadan geçti. Bir testi lokalde defalarca koşturmak için Xcode'da testin elmasına sağ tıklayıp **Run Repeatedly** seçebilirsin.

### 11. Xcode'da UI testi kaydetmek

Xcode, uygulamayı kullanırken yaptığın dokunuşları koda çevirebilir: İmleci bir UI test metodunun gövdesine koy ve Xcode'un kayıt (●) düğmesine bas. Uygulama simülatörde açılır; her dokunuş ve yazma test metoduna bir satır olarak eklenir. Xcode 26'da kayıt deneyimi yenilendi ve kaydedilen her öğe için alternatif sorgular sunuluyor.

Kayıt keşif için iyi bir başlangıçtır: "Bu öğeye nasıl ulaşılır?" sorusunun cevabını hızla verir. Ama üretilen kod olduğu gibi bırakılmamalı:

- Kimliği olmayan öğeler için etiket ya da indeks kullanır. Önce uygulamaya kimlik ekle.
- Beklemez. Dokunuş sonrası async güncellemeler için bekleyen doğrulamalar ekle.
- Doğrulama yazmaz; yalnızca eylemleri kaydeder. Neyin doğru olduğunu sen söylemelisin.
- Her şeyi tek bir metoda yazar. Tekrar eden kısımları Page Object'lere taşı.

### 12. Test piramidi: hangi test nereye?

```
            ▲  UI testleri (~50)          yavaş, pahalı, uçtan uca güven
           ▲▲▲
          ▲▲▲▲▲  birim testleri (~480)    hızlı, kesin, çok sayıda
```

| | Birim testi (XCTest) | UI testi (XCUITest) |
|---|---|---|
| Bu projede | ~480 test ≈ 10 sn | ~50 test ≈ 15 dk (test başına ≈ 18 sn) |
| Neye erişir? | Kodun kendisine (`@testable import`) | Yalnızca ekrana (erişilebilirlik ağacı) |
| Neyi iyi test eder? | Mantık, kenar durumlar, hata dalları, eşzamanlılık | Akışlar, ekranlar arası bağlantı, çatıların (SwiftUI ↔ UIKit) birlikte çalışması |
| Kırıldığında | Hangi fonksiyonun bozulduğunu söyler | Kullanıcının neyi yapamadığını söyler, sebebi aramak gerekir |

Pratik kural: Bir davranış birim testiyle doğrulanabiliyorsa orada doğrula. UI testini kullanıcı için kritik akışlara ayır: kitabı aç, favorile, favorilerde gör, kaldır. Bu projede ISBN algoritmasının tüm kenar durumları birim testlerinde (`ObjCISBNValidatorTests`). UI testinde ise yalnızca "geçerli ve geçersiz girdi ekranda doğru sonucu gösteriyor" akışı var.

Kod kapsamı açısından da iki test türü birbirini tamamlar. `scripts/ci.sh` UI testlerini de `-enableCodeCoverage YES` ile koşuyor. Bu ders yazılırken ölçülen değerler:

| | Birim testleri (`unit.xcresult`) | UI testleri (`ui.xcresult`) |
|---|---|---|
| `BookShelf.app` toplam | %45 | %78 |
| `BookDetailView.swift` | %2 | %93 |
| `ConcurrencyLabView.swift` | %1 | %99 |
| `ProtocolsView.swift` | %0 | %1 (UI testi yok; bkz. Alıştırma 2) |

UI kapsamını görmek için: `xcrun xccov view --report --only-targets build/results/ui.xcresult`. Dosya ayrıntısı için `--only-targets`'ı kaldır. Yüksek UI kapsamı doğrulamaların iyi olduğunu kanıtlamaz; sadece hangi ekranların hiç gezilmediğini gösterir.

### 13. Performans: `XCTApplicationLaunchMetric`

Açılış süresi, kullanıcının uygulamadan ilk izlenimidir. XCTest bunu bir UI testinde ölçebilir:

```swift
@MainActor
func testLaunchPerformance() {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
        XCUIApplication().launch()
    }
}
```

- `XCTApplicationLaunchMetric()` uygulamanın **ilk kareyi** ekrana çizene kadar geçen süreyi ölçer. `XCTApplicationLaunchMetric(waitUntilResponsive: true)` ise ana thread'in kullanıcı girdisine hazır olmasını da bekler.
- Blok birkaç kez koşar (yineleme sayısı `XCTMeasureOptions.iterationCount` ile ayarlanır). Xcode'da bir **baseline** kaydedersen sonraki koşular ona göre değerlendirilir ve gerileme (regression) testi kırar.
- Anlamlı sayılar için gerçek cihazda ve Release yapılandırmasında ölç. Simülatör Mac'in işlemcisini kullanır ve Debug derlemesi optimize edilmemiştir. Bu yüzden bu test bu projenin CI'ında yok; birkaç açılış tüm UI testi süresine eklenirdi ve simülatördeki sayılar yanıltıcı olurdu.
- Diğer metrikler: `XCTClockMetric`, `XCTCPUMetric`, `XCTMemoryMetric`, `XCTStorageMetric`, `XCTOSSignpostMetric` (ör. kaydırma akıcılığı için `XCTOSSignpostMetric.scrollingAndDecelerationMetric`).

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [BookShelfUITestCase.swift](../BookShelfUITests/Support/BookShelfUITestCase.swift) | `BookShelfUITestCase`, `launchApp(extraArguments:)`, `assertLabel`, `assertValue`, `assertAppears`, `assertDisappears` | Ortak üst sınıf; `continueAfterFailure = false`; her zaman `-ui-testing`; bekleyen ve gerçek değeri yazan doğrulamalar |
| [XCUIElement+Waiting.swift](../BookShelfUITests/Support/XCUIElement+Waiting.swift) | `waitUntil(_:timeout:)`, `waitForLabel`, `waitForValue`, `waitUntilEnabled`, `scrollUp(toReveal:maxSwipes:)` | `XCTNSPredicateExpectation` + `XCTWaiter`; tembel liste ve `isHittable` |
| [UITestTimeout.swift](../BookShelfUITests/Support/UITestTimeout.swift) | `UITestTimeout` | Üst sınır olarak bekleme süreleri |
| [Screen.swift](../BookShelfUITests/Screens/Screen.swift) | `Screen`, `waitUntilDisplayed()`, `tabBar`, `tapBackButton()` | Page Object sözleşmesi; sistem geri düğmesi |
| [TabBarScreen.swift](../BookShelfUITests/Screens/TabBarScreen.swift) | `TabBarScreen` | Sekme düğmelerini etiketle bulmak; iOS 26'da değişken kimlikler |
| [BookListScreen.swift](../BookShelfUITests/Screens/BookListScreen.swift), [BookDetailScreen.swift](../BookShelfUITests/Screens/BookDetailScreen.swift) | `openBook(id:)`, `favoriteButton`, `revealExtras()`, `goBackToBookList()` | Tip taşıyan navigasyon; aynı kimlikle iki öğe ve türe özgü sorgu |
| [FavoritesScreen.swift](../BookShelfUITests/Screens/FavoritesScreen.swift) | `removeWithSwipe(bookID:)`, `clearAllConfirmButton`, `openBook(id:)` | UIKit ekranını test etmek; `swipeLeft()`; `UIAlertController` ve `.firstMatch` |
| [LabScreen.swift](../BookShelfUITests/Screens/LabScreen.swift) | `revealCounters()`, `revealLongTask()`, `runTaskGroup()` | Uzun bir `Form`'da bölümleri görünür hale getirmek |
| [InterviewHubScreen.swift](../BookShelfUITests/Screens/InterviewHubScreen.swift), [InterviewTopicScreen.swift](../BookShelfUITests/Screens/InterviewTopicScreen.swift) | `openTopic(_:)`, `showAnswer()`, `showDemo()`, `showCode()` | Mülakat sekmesi: uzun listede kaydırarak satır bulmak; her demoya aynı yoldan gitmek |
| [StructVsClassScreen.swift](../BookShelfUITests/Screens/StructVsClassScreen.swift), [ISBNCheckerScreen.swift](../BookShelfUITests/Screens/ISBNCheckerScreen.swift), [ProtocolQuizScreen.swift](../BookShelfUITests/Screens/ProtocolQuizScreen.swift) | `selectExperiment(_:)`, `type(_:)`, `check(_:)`, `answerCompiles()` | Segmented control; `typeText` ve klavye odağı; ekranın altındaki sabit düğmeler |
| [BookBrowsingUITests.swift](../BookShelfUITests/BookBrowsingUITests.swift) | `testTappingRowOpensDetailWithObjectiveCValues` | `XCTContext.runActivity`, ekran görüntüsü eki (`.keepAlways`), regex ile değişken süre |
| [FavoritesFlowUITests.swift](../BookShelfUITests/FavoritesFlowUITests.swift) | `testOpeningFavoriteShowsSwiftUIDetailInsideUIKit`, `testClearAllAsksForConfirmationAndRemovesEveryFavorite` | SwiftUI → actor → UIKit akışı uçtan uca; bu dersin bulduğu hatanın testi |
| [ErrorStateUITests.swift](../BookShelfUITests/ErrorStateUITests.swift) | `testNetworkErrorShowsErrorViewWithRetryButton` | `-simulate-network-error` ile hata ekranı |
| [ConcurrencyLabUITests.swift](../BookShelfUITests/ConcurrencyLabUITests.swift) | `testCancellingLongTaskStopsItBeforeTheEnd` | Değişken sonuçlarda değer yerine biçim ve değişmez doğrulamak |
| [FundamentalsUITests.swift](../BookShelfUITests/FundamentalsUITests.swift) | `testMutatingCopiesLeavesStructOriginalButChangesClassOriginal`, `testEditingInputClearsPreviousResult` | struct/class farkını ekrandan doğrulamak; `waitForNonExistence` |
| [LaunchSmokeUITests.swift](../BookShelfUITests/LaunchSmokeUITests.swift) | `testAppLaunchesWithFourTabs` | En küçük UI testi (duman testi) |
| [AccessibilityID.swift](../Shared/AccessibilityID.swift) ve `AccessibilityID+*.swift` | `AccessibilityID`, `BookValue` | Uygulama ve testin paylaştığı kimlik sözleşmesi |
| [LaunchArgument.swift](../Shared/LaunchArgument.swift) | `uiTesting`, `simulateNetworkError` | Test modu argümanları |
| [AppDependencies.swift](../BookShelf/App/AppDependencies.swift) | `makeForLaunch(arguments:)` | Argümana göre servis seçimi |
| [BookShelfApp.swift](../BookShelf/App/BookShelfApp.swift) | `BookShelfApp.init()` | Test modunda animasyonları kapatmak |
| [ConcurrencyLab.swift](../BookShelf/Features/ConcurrencyLab/ConcurrencyLab.swift) | `ConcurrencyLab.Settings.uiTesting` | Zamanlamaya bağlı akışta güvenlik payı |
| [BookDetailView.swift](../BookShelf/Features/BookDetail/BookDetailView.swift) | `FavoriteButtonPlacement` | UI testinin bulduğu hatanın düzeltmesi |
| [ci.sh](../scripts/ci.sh) | `cmd_ui` | UI testlerini komut satırından koşmak, tekrar deneme, `.xcresult` |

## Sık yapılan hatalar

**1. Sabit süre beklemek**

```swift
// YANLIŞ: hızlı makinede boşa bekler, yavaş CI'da yetmez
detail.toggleFavorite()
sleep(2)
XCTAssertEqual(detail.favoriteButton.value as? String, "Favori")
```

```swift
// DOĞRU: koşul sağlandığı an devam eder, en fazla 10 sn bekler
detail.toggleFavorite()
assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.favorite)
```

**2. Eylemden hemen sonra anlık okuma**

```swift
// YANLIŞ: dokunuş bir Task açar, actor'ü bekler; value o an henüz değişmemiş olabilir
detail.toggleFavorite()
XCTAssertEqual(detail.favoriteButton.value as? String, AccessibilityID.BookValue.favorite)
```

```swift
// DOĞRU: DEĞİŞİKLİK beklenen yerde bekleyen doğrulama.
// Anlık okuma yalnızca başlangıç durumu ya da zaten beklenmiş bir değişikliğin yan sonucu için uygundur.
assertValue(detail.favoriteButton, equals: AccessibilityID.BookValue.favorite)
```

**3. Değişen metinle sorgulamak**

```swift
// YANLIŞ: etiket duruma göre değişir; dokunduktan sonra düğme "Favorilerden çıkar" olur ve bulunamaz
app.buttons["Favorilere ekle"].tap()
app.buttons["Favorilere ekle"].tap()   // "No matches found"
```

```swift
// DOĞRU: kimlik sabittir, durum value'dadır
let heart = app.buttons[AccessibilityID.BookDetail.favoriteButton]
heart.tap()
assertValue(heart, equals: AccessibilityID.BookValue.favorite)
```

**4. Sistemin ürettiği kimliğe güvenmek**

```swift
// YANLIŞ: iOS 26'da bu kimlik yalnızca Favoriler sekmesi seçiliyken var
app.tabBars.buttons["heart"].tap()
```

```swift
// DOĞRU: sekme düğmesini, uygulamanın da kullandığı başlık sabitiyle bul
app.tabBars.buttons[AccessibilityID.Tab.favorites].tap()
```

**5. Değişken sonucu tam değerle doğrulamak**

```swift
// YANLIŞ: süre ve kaybolan artış sayısı her koşuda farklı
XCTAssertEqual(lab.taskGroupResult.label, "TaskGroup: 0,11 sn")
XCTAssertEqual(lab.unsafeCounterResult.label, "Kilitsiz class: 917 / 1000 (83 artış kayboldu)")
```

```swift
// DOĞRU: değişmeyen kısmı (biçimi) doğrula; tam değeri yalnızca deterministik olanlar için iste
assertLabel(lab.taskGroupResult, matches: "TaskGroup: [0-9]+,[0-9]+ sn")
assertLabel(lab.unsafeCounterResult, matches: "Kilitsiz class: [0-9]+ / 1000( \\([0-9]+ artış kayboldu\\))?")
assertLabel(lab.actorCounterResult, equals: "Actor: 1000 / 1000")
```

**6. Birbirine bağımlı testler**

```swift
// YANLIŞ: ikinci test, birincinin eklediği favoriye güveniyor. Tek başına ya da farklı sırayla koşunca kalır.
func test1_FavoriteBook() { /* kitap 1'i favorile */ }
func test2_FavoritesTabShowsBook() { /* Favoriler'de kitap 1'i ara */ }
```

```swift
// DOĞRU: her test ihtiyaç duyduğu durumu kendisi kurar (uygulama her testte sıfırdan açılır)
func testSwipeToRemoveShowsEmptyState() {
    let bookList = BookListScreen(app: launchApp()).waitUntilDisplayed()
    let detail = bookList.openBook(id: 1)
    detail.toggleFavorite()
    // ...
}
```

**7. Ekran dışındaki satırı kaydırmadan aramak**

```swift
// YANLIŞ: List tembel; küçük ekranda 8. satır henüz ağaçta yok. Bekleme sonuçsuz biter.
XCTAssertTrue(app.buttons[AccessibilityID.BookList.row(bookID: 8)].waitForExistence(timeout: 10))
```

```swift
// DOĞRU: satır dokunulabilir olana kadar listeyi kaydır
let row = app.buttons[AccessibilityID.BookList.row(bookID: 8)]
app.collectionViews[AccessibilityID.BookList.list].scrollUp(toReveal: row)
row.tap()
```

**8. `XCUIApplication`'a nonisolated bir metottan dokunmak**

```swift
// YANLIŞ: Xcode 26.3 / Swift 6 modunda şu uyarıları verir:
// "call to main actor-isolated initializer 'init()' in a synchronous nonisolated context"
// "call to main actor-isolated instance method 'launch()' in a synchronous nonisolated context"
func testLaunch() {
    let app = XCUIApplication()
    app.launch()
}
```

```swift
// DOĞRU: XCUIApplication'a dokunan test metodu ana actor'de
@MainActor
func testLaunch() {
    let app = XCUIApplication()
    app.launch()
}
```

## Mülakatta sorulabilecekler

1. **XCUITest nasıl çalışır? Birim testinden farkı nedir?**
   Testler ayrı bir çalıştırıcı süreçte (`...-Runner.app`) koşar. Uygulama `XCUIApplication().launch()` ile başka bir süreç olarak başlatılır. Test uygulamanın kodunu göremez (`@testable import` yok); ekranı erişilebilirlik ağacı üzerinden görür ve dokunma olaylarını sentezler. Birim testi kodu doğrudan çağırır, milisaniyeler sürer ve hangi fonksiyonun bozulduğunu söyler. UI testi saniyeler sürer ve kullanıcının neyi yapamadığını söyler.

2. **`accessibilityIdentifier` ile `accessibilityLabel` farkı nedir? Testte hangisini kullanırsın?**
   Label kullanıcıya ve VoiceOver'a yöneliktir; çeviriyle, metin düzeltmesiyle ve duruma göre değişir. Identifier yalnızca testler içindir, görünmez ve sabittir. Testte identifier kullanırım. Durum bilgisini `accessibilityValue`'ya koyarım; o da hem teste sabit bir değer verir hem VoiceOver'a durumu okur. Label'ı yalnızca kimlik verilemeyen öğelerde (sistem sekme düğmeleri, `UIContextualAction`) ve paylaşılan bir sabitten alarak kullanırım.

3. **UI testinde ağı ve veriyi nasıl deterministik yaparsın?**
   Uygulamayı `launchArguments`/`launchEnvironment` ile test modunda başlatırım. Uygulama bu modda bağımlılık enjeksiyonuyla sahte ya da yerel bir servis kurar. Bu projede `-ui-testing` sıfır gecikmeli, paketteki JSON'dan okuyan servisi seçiyor; `-simulate-network-error` ise hata veren servisi. Alternatifler: yerel bir sahte sunucu (adresi `launchEnvironment` ile verilir) ya da `URLProtocol` ile yanıtları taklit etmek. Kalıcı durum varsa (UserDefaults, veritabanı) test modunda sıfırlanır.

4. **Flaky UI testlerinin sebepleri ve çözümleri nelerdir?**
   Sabit `sleep` yerine koşul beklemek (`waitForExistence`, predicate expectation). Animasyonları kapatmak, ağı taklit etmek, metin yerine kimlik kullanmak. Testleri bağımsız yapmak (her test sıfırdan açılır ve kendi durumunu kurar). Tembel listelerde kaydırmak, değişken değerlerde biçim ya da değişmez doğrulamak, zamanlamaya bağlı akışlarda güvenlik payı bırakmak. Retry'ı son çare olarak kullanır, tekrar edilen testleri raporlayıp kök nedenini düzeltirim.

5. **Bir öğenin görünmesini ya da değişmesini nasıl beklersin? Neden `sleep` değil?**
   `waitForExistence(timeout:)`, `waitForNonExistence(timeout:)`, `wait(for:toEqual:timeout:)` ya da genel durumlar için `XCTNSPredicateExpectation` + `XCTWaiter` kullanırım. Süre bir üst sınırdır; koşul sağlandığı an bekleme biter. `sleep` ise hızlı makinede boşa zaman harcar, yavaş makinede yetmez; hem yavaş hem flaky olur.

6. **Page Object kalıbı nedir, ne kazandırır?**
   Her ekran için öğeleri nasıl bulacağını ve ekranda yapılabilecek eylemleri bilen bir tip yazılır. Testler sorgu ayrıntısı yerine kullanıcının niyetini anlatır. Bir kimlik ya da ekran yapısı değiştiğinde tek dosya güncellenir. Navigasyon metotları bir sonraki ekranın tipini döndürür. Doğrulamalar testte kalır; ekran nesnesi sadece "ekran açıldı mı?" bekler.

7. **Hangi davranışları UI testiyle, hangilerini birim testiyle test edersin?**
   Test piramidi: çok sayıda hızlı birim testi, az sayıda kritik akış için UI testi. Mantık, kenar durumlar ve hata dalları birim testine gider. Ekranlar arası akışlar, farklı katmanların (SwiftUI, UIKit, actor) birlikte çalışması ve "kullanıcı bunu yapabiliyor mu?" soruları UI testine gider. Bir davranış birim testiyle doğrulanabiliyorsa UI testine taşımam.

8. **İzin pencereleri gibi sistem uyarılarını UI testinde nasıl yönetirsin?**
   `addUIInterruptionMonitor(withDescription:handler:)` ile bir işleyici kaydederim. Uyarı bir etkileşimi engellediğinde XCUITest işleyiciyi çağırır, işleyici uyarıdaki düğmeye dokunup `true` döner. İzin durumunu testten önce `app.resetAuthorizationStatus(for: .location)` gibi çağrılarla sıfırlayabilirim. Mümkünse test modunda izin isteyen servisi de sahtesiyle değiştiririm; böylece uyarı hiç çıkmaz.

## Alıştırmalar

Not: Bir testin gerçekten bir şeyi doğruladığını anlamanın yolu onu bilerek kırmaktır. Bu dersin testleri böyle denendi. `ConcurrencyLabViewModel.cancelLongTask()` boş bırakılınca iptal testi "Gerçek: "Tamamlandı: 40 / 40"" mesajıyla kaldı. `FavoritesViewController`'daki `favoriteButtonPlacement: .header` kaldırılınca Favoriler'den açılan detay testi "öğe bulunamadı" ile kaldı. Aşağıdaki alıştırmalarda da testini yazdıktan sonra bir kez bilerek kır.

1. **Actor reentrancy deneyini UI testiyle doğrula.** `ConcurrencyLabUITests`'e, "Reentrancy deneyini çalıştır" düğmesine dokunup "Arada await yok: 1000 / 1000" sonucunu bekleyen bir test ekle. Yarışlı olan "Arada await var: ..." satırı için yalnızca biçimi doğrula.
   *İpucu:* Önce [LabScreen.swift](../BookShelfUITests/Screens/LabScreen.swift)'e `runReentrancyButton`, `reentrancyResult`, `reentrancyFixedResult` öğelerini ve bir `runReentrancy()` eylemi ekle. Kimlikler `AccessibilityID.Lab` içinde hazır. Bölüm, sayaçlarla iptal arasında duruyor; `form.scrollUp(toReveal: reentrancyFixedResult)` ile görünür yap. Kalıp için sayaç testindeki `"Kilitsiz class: [0-9]+ / 1000( \\([0-9]+ artış kayboldu\\))?"` ifadesini uyarlayabilirsin.

2. **Protocol'ler ekranı için bir Page Object ve sıralama testi yaz.** `ProtocolsScreen` oluştur ve karışık listede "Süre" sıralamasına geçince ilk satırın değiştiğini doğrula.
   *İpucu:* Ekrana Mülakat sekmesinden gidilir: `openTopic(TopicID.protocolAsType).showDemo()` quiz'i açar, quiz'in altındaki `AccessibilityID.Fundamentals.ProtocolQuiz.liveExampleLink` bağlantısı da `ProtocolsView`'u push eder. [ProtocolQuizScreen](../BookShelfUITests/Screens/ProtocolQuizScreen.swift)'e `openProtocols()` ekle (bağlantı ekranın altında olabilir; `scrollUp(toReveal:)` kullan). Kimlikler `AccessibilityID.Fundamentals.Protocols` içinde: sıralama seçicisi `sortPicker`, bölüm etiketleri `sortByTitleLabel` / `sortByDurationLabel`, satır başlıkları `rowTitle(index:)`. Seçicideki düğmeyi `app.segmentedControls[Protocols.sortPicker].buttons[Protocols.sortByDurationLabel]` ile bul. Önce `rowTitle(index: 0)`'ın label'ını oku, sonra sıralamayı değiştirip `assertLabel` ile yeni değeri bekle. Hangi başlığın ilk sıraya geleceğini [ReadingItemTypes.swift](../BookShelf/Features/Fundamentals/Protocols/ReadingItemTypes.swift)'teki verilerden hesapla.

3. **Erişilebilirlik denetimi ekle.** Kitap listesi ve detay ekranı için `try app.performAccessibilityAudit()` çağıran bir test yaz ve ilk koşuda çıkan sorunları incele.
   *İpucu:* API Xcode 15 ve iOS 17 ile geldi, `throws` ve `@MainActor`. Denetim her sorunu ayrı bir test hatası olarak raporlar. Belirli türlerle sınırlamak için `performAccessibilityAudit(for: [.contrast, .dynamicType])` kullan. Bilinçli olarak kabul ettiğin bir sorunu atlamak için kapanışta `true` döndür: `{ issue in issue.auditType == .contrast }`. Bulunan gerçek bir sorunu (ör. dokunma alanı küçük bir öğe) uygulamada düzelt ve testi yeniden koş.
