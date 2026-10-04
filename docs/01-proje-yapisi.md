# Proje Yapısı: Hedefler, Şema ve Build Ayarları

Bu belge projenin haritası. Önce burayı oku; sonraki derslerde (02 → 11) hangi dosyanın nerede durduğunu ve neden orada durduğunu bileceksin.

## Neden önemli?

Bir Xcode projesi yalnızca dosyalardan oluşan bir liste değildir. Şu soruların cevabı projede yazılıdır:

- Hangi dosya hangi **ürüne** (uygulama, test paketi) giriyor?
- Testler uygulamanın **içinde** mi çalışıyor, yoksa **ayrı bir süreçte** mi?
- Derleyici hangi kurallarla çalışıyor (Swift 6 modu, minimum iOS sürümü, Objective-C köprüsü)?
- ⌘R ya da ⌘U'ya basınca veya CI `xcodebuild` çalıştırınca tam olarak ne oluyor?

Şu hataların hepsi proje yapısını bilmemekten kaynaklanır: "UI testinde `Book` tipini göremiyorum", "Test hedefi uygulamadaki tipi bulamıyor", "Release'te `@testable import` hata veriyor", "CI'da şema bulunamadı". Mülakatlarda da target/scheme/configuration farkı, hosted test ve `@testable import` sık sorulur.

## Temel kavramlar

### Klasör düzeni

```text
Assesments/                               depo kökü
├── BookShelf.xcodeproj/
│   ├── project.pbxproj                   hedefler, build ayarları, klasör bağlantıları
│   └── xcshareddata/xcschemes/
│       └── BookShelf.xcscheme            paylaşılan şema (git'e girer, CI bunu kullanır)
├── BookShelf/                            → uygulama hedefi (BookShelf.app)
│   ├── App/                              giriş noktası (@main), sekme iskeleti, bağımlılıklar
│   ├── Core/                             Models / Services / Stores: ekranların ortak sözleşmeleri
│   ├── Features/                         her sekme/ekran kendi klasöründe
│   │   ├── BookList/  BookDetail/        SwiftUI + async/await
│   │   ├── Favorites/                    UIKit
│   │   ├── ConcurrencyLab/               Task, TaskGroup, actor
│   │   └── Fundamentals/  ISBNChecker/   struct vs class, protocol'ler, Objective-C
│   ├── ObjC/                             Objective-C sınıfları + köprü başlığı (bridging header)
│   └── Resources/                        books.json, Assets.xcassets
├── Shared/                               → HEM uygulama HEM UI test hedefi (yalnızca Foundation)
├── BookShelfTests/                       → birim test hedefi (XCTest)
│   └── Support/                          StubBookService, Fixtures (ortak test yardımcıları)
├── BookShelfUITests/                     → UI test hedefi (XCUITest)
├── docs/                                 dersler (01 → 11)
├── scripts/ci.sh                         derleme + test betiği (lokalde ve CI'da aynı)
├── Makefile                              make build / test / ci kısa yolları
└── .github/workflows/ci.yml              GitHub Actions iş akışı
```

### Proje, hedef, ürün, şema, yapılandırma

| Kavram | Ne? | Bu projede |
|---|---|---|
| **Proje** (`.xcodeproj`) | Aslında bir klasör. İçindeki `project.pbxproj` hedefleri, ayarları ve dosya bağlantılarını tutan metin dosyasıdır. | `BookShelf.xcodeproj` |
| **Hedef** (target) | Bir ürünü üretmenin tarifi: hangi kaynaklar, hangi build ayarları, hangi bağımlılıklar. Bir hedef = bir ürün. | 3 hedef (aşağıda) |
| **Ürün** (product) | Hedefin çıktısı: `.app`, `.xctest`, framework… | `BookShelf.app`, `BookShelfTests.xctest`, `BookShelfUITests.xctest` |
| **Şema** (scheme) | "⌘R / ⌘U / Archive deyince ne olacak?" Hangi hedefler derlenir, hangi testler koşar, hangi yapılandırma ve hangi başlatma argümanları kullanılır. | `BookShelf` (paylaşılan) |
| **Yapılandırma** (build configuration) | Aynı hedefin farklı ayar setleri. | `Debug` ve `Release` |
| **Workspace** (`.xcworkspace`) | Birden çok projeyi bir arada açar. | Kullanmıyoruz (tek proje yeterli). |

**Build ayarlarının katmanları:** Xcode/SDK varsayılanı → **proje** düzeyi → **hedef** düzeyi. Alttaki katman üsttekini ezer (override). `$(inherited)` üst katmanın değerini dahil eder; `$(TARGET_NAME)` gibi ifadelerle ayarlar birbirine başvurur. Bu projede ortak ayarlar (ör. `SWIFT_VERSION`, uyarılar) proje düzeyinde, hedefe özgü olanlar (bundle id, `TEST_HOST`) hedef düzeyindedir.

Terminalden görmek için:

```bash
xcodebuild -list -project BookShelf.xcodeproj           # hedefler, yapılandırmalar, şemalar
xcodebuild -showBuildSettings -project BookShelf.xcodeproj \
  -target BookShelfTests -configuration Debug -sdk iphonesimulator | grep -E "TEST_HOST|ENABLE_TESTABILITY"
```

> Not: `-configuration` vermezsen ve `-scheme` de kullanmazsan xcodebuild **Release**'i seçer (`xcodebuild -list` bunu söyler). Release'te `ENABLE_TESTABILITY = NO` göreceksin; bunun neden önemli olduğu aşağıda.

**Debug ve Release farkı (bu projede):**

| Ayar | Debug | Release |
|---|---|---|
| `SWIFT_OPTIMIZATION_LEVEL` | `-Onone` (optimizasyon yok, hata ayıklaması kolay) | varsayılan `-O` |
| `SWIFT_COMPILATION_MODE` | artımlı (incremental) | `wholemodule` (tüm modül birlikte optimize edilir) |
| `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | `DEBUG` → `#if DEBUG` çalışır | yok |
| `ENABLE_TESTABILITY` | `YES` → `@testable import` mümkün | açık değil |
| `DEBUG_INFORMATION_FORMAT` | `dwarf` (hızlı) | `dwarf-with-dsym` (çökme raporlarını çözmek için dSYM) |

### Üç hedef

| Hedef | Ürün tipi (`productType`) | Derlenen klasörler | Nerede çalışır? |
|---|---|---|---|
| `BookShelf` | `application` → `BookShelf.app` | `BookShelf/`, `Shared/` | Simülatörde, uygulama olarak |
| `BookShelfTests` | `bundle.unit-test` → `BookShelfTests.xctest` | `BookShelfTests/` | Uygulamanın **içinde** (hosted) |
| `BookShelfUITests` | `bundle.ui-testing` → `BookShelfUITests.xctest` | `BookShelfUITests/`, `Shared/` | **Ayrı** bir çalıştırıcı süreçte |

İki test hedefinin de uygulama hedefine bağımlılığı (`PBXTargetDependency`) var: bir test hedefini derlemek önce uygulamayı derler.

#### Birim test hedefi: `TEST_HOST` ve `BUNDLE_LOADER`

`project.pbxproj` içinde `BookShelfTests` hedefinin ayarları:

```text
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/BookShelf.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/BookShelf";
BUNDLE_LOADER = "$(TEST_HOST)";
```

- **`TEST_HOST` (çalışma zamanı):** Test paketi, çalışan uygulamanın **içine** yüklenir. Sıra şöyle: simülatörde uygulama açılır (`BookShelfApp.init()` çalışır, ekran bile çizilir) → XCTest, test paketini aynı sürece yükler → testler koşar. Derleme sırasında paket uygulamanın içine gömülür: `BookShelf.app/PlugIns/BookShelfTests.xctest`.
- **`BUNDLE_LOADER` (bağlama/link zamanı):** Linker'a "bu paketteki tanımsız sembolleri şu çalıştırılabilir dosyada ara" der (`-bundle_loader`). Test paketi `Book`, `LocalBookService` gibi tiplerin ikinci bir kopyasını içermez; uygulamadakileri kullanır.
- **`BUNDLE_EXECUTABLE_FOLDER_PATH`:** iOS'ta uygulama paketi düzdür (flat), bu ayar boştur; macOS'ta `Contents/MacOS` olur. Aynı ifade iki platformda da doğru yolu verir.
- **`@testable import BookShelf`:** Modülün `internal` tiplerini testlere açar. Şartı, modülün `ENABLE_TESTABILITY = YES` ile derlenmesidir. Bu ayar projede yalnızca Debug'da açık; şemanın Test eylemi de Debug kullanıyor.
- **Önemli yan etki:** Test süreci = uygulama süreci, yani testte `Bundle.main` **uygulamanın** paketidir. [ProjectSetupTests](../BookShelfTests/ProjectSetupTests.swift) içindeki `LocalBookService`, `books.json`'u bu sayede bulur.

> **Hostless (logic) test** de mümkündür: `TEST_HOST` boş bırakılırsa testler uygulama açılmadan, daha hızlı koşar. Ama bir uygulama hedefine "bağlanamazsın". Test edilecek kodun bir framework'te veya Swift paketinde olması gerekir. Küçük projelerde hosted test en pratik seçenektir.

#### UI test hedefi: `TEST_TARGET_NAME`

```text
TEST_TARGET_NAME = BookShelf;
```

- "Bu UI test paketi `BookShelf` uygulamasını kullanır" demektir.
- Xcode, test paketini taşıyan ayrı bir **çalıştırıcı uygulama** üretir: `BookShelfUITests-Runner.app`. Testler bu süreçte koşar. `XCUIApplication().launch()` ise uygulamayı **ayrı bir süreç** olarak başlatır. Test, öğeleri erişilebilirlik (accessibility) ağacı üzerinden bulur ve onlara dokunur.
- Bu yüzden UI testleri uygulamanın tiplerini **göremez**. Test paketi uygulamaya bağlanmaz (`BUNDLE_LOADER` yok) ve başka bir süreçte çalışır. Ekranda ne görünüyorsa sadece onu bilir.
- İki taraf ortak sabitleri nasıl paylaşıyor? `Shared/` klasörü **iki hedefe birden** derlenir: `AccessibilityID` ve `LaunchArgument` hem uygulamada hem UI testlerinde vardır. Bu yüzden `Shared/` içindeki dosyalar yalnızca Foundation kullanır ve uygulamaya ait hiçbir tipe (`Book` gibi) başvuramaz.
- Testten uygulamaya bilgi göndermenin yolu `launchArguments` / `launchEnvironment`'tır (aşağıda "Başlatma argümanları").

### Paylaşılan şema

Şema dosyası `BookShelf.xcodeproj/xcshareddata/xcschemes/BookShelf.xcscheme` konumunda. `xcshareddata/` git'e girer. Kişisel şemalar ve ayarlar ise `xcuserdata/` altında durur ve `.gitignore`'dadır. CI `-scheme BookShelf` dediğinde bu dosyayı kullanır. Şema paylaşılmasaydı, başka bir makinede aynı test ayarlarının bulunacağının garantisi olmazdı.

Şemanın Test eylemi (kısaltılmış):

```xml
<TestAction buildConfiguration = "Debug"
            shouldUseLaunchSchemeArgsEnv = "YES"
            shouldAutocreateTestPlan = "YES">
   <Testables>
      <TestableReference skipped = "NO" parallelizable = "NO"> ... BookShelfTests ... </TestableReference>
      <TestableReference skipped = "NO" parallelizable = "NO"> ... BookShelfUITests ... </TestableReference>
   </Testables>
</TestAction>
```

- ⌘U her iki test paketini de Debug yapılandırmasıyla çalıştırır. CI tarafında `-only-testing:BookShelfTests` ile tek bir paket seçilir.
- `parallelizable = "NO"`: Testler simülatör kopyalarına dağıtılmaz, sırayla koşar.
- `shouldAutocreateTestPlan = "YES"`: Ayrı bir `.xctestplan` dosyası yok. Xcode test planını şemadan otomatik türetir.
- `shouldUseLaunchSchemeArgsEnv = "YES"`: Test eylemi, Run eyleminin argümanlarını ve ortam değişkenlerini kullanır.
- Run (Launch) eylemi Debug, Profile ve Archive eylemleri Release kullanır.

### Senkronize klasörler (Xcode 16+)

Proje `objectVersion = 77` biçiminde ve klasörler `PBXFileSystemSynchronizedRootGroup` olarak tanımlı:

```text
0B5E00000000000000000011 /* Shared */ = {
    isa = PBXFileSystemSynchronizedRootGroup;
    path = Shared;
    sourceTree = "<group>";
};

/* BookShelfUITests hedefi */
fileSystemSynchronizedGroups = (
    0B5E00000000000000000013 /* BookShelfUITests */,
    0B5E00000000000000000011 /* Shared */,
);
```

**Eskiden** her dosya `project.pbxproj`'da dört yerde anılırdı: dosya referansı, grup üyeliği, build dosyası kaydı ve Sources aşaması. İki kişi aynı anda dosya eklediğinde pbxproj'da birleştirme çakışması (merge conflict) kaçınılmazdı. Dosyayı diske koyup hedefe eklemeyi unutmak da "Cannot find type in scope" hatası verirdi.

**Şimdi** pbxproj dosyaları tek tek listelemez. Bizim projede tüm `PBXSourcesBuildPhase` aşamalarının `files = ( );` listesi boş. Kural basit: **bir klasördeki her dosya, o klasöre bağlı hedeflere otomatik girer.**

- Xcode derleme aşamasını dosya tipine göre seçer: `.swift` ve `.m` dosyaları derlenir. `books.json` ve `Assets.xcassets` kaynak (resource) olarak kopyalanır; `books.json` paketin **köküne** gider, bu yüzden `Bundle.main.url(forResource: "books", withExtension: "json")` onu bulur. `.h` başlık dosyaları derlenmez, `#import` ile kullanılır.
- `Shared/` iki hedefin `fileSystemSynchronizedGroups` listesinde de var. Böylece bir dosya iki hedefe birden girer.
- Bir dosyayı bir hedeften hariç tutmak gerekirse Xcode'da File Inspector > Target Membership kullanılır. Bu, pbxproj'a bir "istisna" (`PBXFileSystemSynchronizedBuildFileExceptionSet`) ekler. Bizde hiç istisna yok.
- Sonuç: Yeni dosya eklemek için pbxproj'a **dokunmazsın**, dosyayı doğru klasörde oluşturman yeterli. pbxproj yalnızca ayar değiştiğinde değişir; daha az çakışma olur.

### Önemli build ayarları

| Ayar | Değer | Neden? |
|---|---|---|
| `SWIFT_VERSION` | `6.0` | **Swift 6 dil modu:** eşzamanlılık denetimi tam (complete) ve data race'ler derleme **hatasıdır**, uyarı değil. `Sendable`, actor izolasyonu ve `@MainActor` kurallarını derleyici zorlar. |
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` | `@Observable` makrosu (Observation framework'ü) iOS 17 ister. Uygulamanın `Info.plist`'inde `MinimumOSVersion = 17.0` olur. |
| `SWIFT_OBJC_BRIDGING_HEADER` | `BookShelf/ObjC/BookShelf-Bridging-Header.h` | Objective-C → Swift köprüsü. Buraya `#import` edilen başlıklar uygulama hedefindeki tüm Swift dosyalarında görünür. Test hedefi aynı tiplere `@testable import BookShelf` üzerinden erişir. |
| `GENERATE_INFOPLIST_FILE` | `YES` | Ortada `Info.plist` dosyası yok. Xcode onu `INFOPLIST_KEY_*` ayarlarından üretir; ör. `INFOPLIST_KEY_CFBundleDisplayName = "Kitaplık"` ana ekrandaki adı belirler. |
| `ENABLE_TESTABILITY` | Debug: `YES` | `@testable import` için gerekli. |
| `TEST_HOST` / `BUNDLE_LOADER` | birim test hedefi | Hosted birim testleri (yukarıda). |
| `TEST_TARGET_NAME` | UI test hedefi | UI testlerinin hangi uygulamayı kullanacağı. |
| `CODE_SIGN_STYLE` | `Automatic`, `DEVELOPMENT_TEAM` yok | Simülatör derlemeleri sertifika istemez, "Sign to Run Locally" ile imzalanır. Gerçek cihaz veya App Store için bir takım (team) gerekir. |
| `TARGETED_DEVICE_FAMILY` | `1,2` | 1 = iPhone, 2 = iPad. |
| `PRODUCT_BUNDLE_IDENTIFIER` | `dev.learning.BookShelf` (+`Tests`, `UITests`) | Her ürünün benzersiz kimliği. |
| `developmentRegion` | `tr` | Geliştirme dili Türkçe. |

#### Xcode 26 şablonlarından bilerek açmadıklarımız

Xcode 26'da File > New > Project ile oluşturulan bir uygulama birkaç ayarı farklı başlatır. Bu proje onları **bilerek** kullanmıyor:

| Ayar | Xcode 26 yeni proje şablonu | Bu proje |
|---|---|---|
| `SWIFT_VERSION` | `5.0` (Swift 5 dil modu) | `6.0` |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` (uygulama hedefinde) | ayarlı değil → `nonisolated` |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` | ayarlı değil → `NO` |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | `YES` | ayarlı değil |

- **Default Actor Isolation = MainActor** (SE-0466) modüldeki açıkça işaretlenmemiş **tüm** tipleri ve fonksiyonları `@MainActor` sayar. Uygulama kodu için rahattır, ama bir öğrenme projesinde izolasyonu gizler. Bizde kural şu: `@MainActor`'ü nerede görüyorsan orası ana aktördür, görmüyorsan değildir.
- **Approachable Concurrency** birkaç "upcoming feature" açar: `DisableOutwardActorInference`, `GlobalActorIsolatedTypesUsability`, `InferSendableFromCaptures`, `InferIsolatedConformances`, `NonisolatedNonsendingByDefault`. İlk üçü Swift 6 dil modunda zaten açıktır. Bizi en çok ilgilendiren fark **`NonisolatedNonsendingByDefault`** (SE-0461):

```swift
// BU PROJEDE (Swift 6 modu, NonisolatedNonsendingByDefault KAPALI):
struct LocalBookService: BookServiceProtocol {          // hiçbir actor'e bağlı değil (nonisolated)
    func fetchBooks() async throws -> [Book] { ... }    // nonisolated async → global concurrent executor'de çalışır
}
// @MainActor'deki bir view model `try await service.fetchBooks()` dediğinde gövde ana thread'den ÇIKAR;
// JSON çözme arka planda yapılır.

// NonisolatedNonsendingByDefault AÇIK olsaydı:
// aynı fonksiyon ÇAĞIRANIN actor'ünde (burada ana actor) çalışırdı. Arka plana geçmek için açıkça
// `@concurrent func fetchBooks() async throws -> [Book]` yazmak gerekirdi.
```

İki model de geçerli ve güvenlidir. Biz davranışın kodda **açıkça** görünmesi için varsayılanları seçtik. Ayrıntılar [05 – async/await](05-async-await.md) ve [06 – Concurrency ve actor](06-concurrency-ve-actor.md) derslerinde.

### Başlatma argümanları

[`LaunchArgument`](../Shared/LaunchArgument.swift) iki argüman tanımlar:

| Argüman | Etkisi |
|---|---|
| `-ui-testing` | Servis gecikmesi sıfırlanır ve `UIView` animasyonları kapanır. UI testleri hızlı ve kararlı olur. |
| `-simulate-network-error` | Servis her istekte `BookServiceError.networkUnavailable` fırlatır. Hata ekranı test edilebilir. |

```swift
// Uygulama tarafı — BookShelfApp.init()
let arguments = ProcessInfo.processInfo.arguments
dependencies = AppDependencies.makeForLaunch(arguments: arguments)

// UI test tarafı — ayrı süreçten uygulamaya bilgi göndermenin yolu
let app = XCUIApplication()
app.launchArguments = [LaunchArgument.uiTesting, LaunchArgument.simulateNetworkError]
app.launch()
```

Elle denemek için Xcode'da Product > Scheme > Edit Scheme… > Run > Arguments > "Arguments Passed On Launch" bölümüne `-simulate-network-error` ekleyebilirsin. Dikkat: Şema paylaşılan bir dosya olduğu için bu değişiklik git'te görünür. Ayrıca `shouldUseLaunchSchemeArgsEnv = YES` nedeniyle birim testleri sırasında açılan host uygulama da bu argümanla başlar. Denemeden sonra kutucuğu kapat.

### Öğrenme sırası

| # | Ders | Konu |
|---|---|---|
| 01 | Proje yapısı (bu belge) | Hedefler, şema, build ayarları |
| 02 | [struct vs class](02-struct-vs-class.md) | Değer ve referans semantiği, kopyalama, kimlik |
| 03 | [Protocol'ler](03-protocoller.md) | Sözleşmeler, `some` / `any`, bağımlılık tersine çevirme |
| 04 | [SwiftUI](04-swiftui.md) | View, `@State`, `@Observable`, navigasyon |
| 05 | [async/await](05-async-await.md) | Askıya alma, `async let`, iptal, `.task` |
| 06 | [Concurrency ve actor](06-concurrency-ve-actor.md) | Task, TaskGroup, actor, `Sendable`, data race |
| 07 | [UIKit](07-uikit.md) | UIViewController, diffable data source, SwiftUI ↔ UIKit |
| 08 | [Objective-C](08-objective-c.md) | Köprü başlığı, `NS_SWIFT_NAME`, nullability, NSError → `throws` |
| 09 | [XCTest](09-xctest.md) | Birim testleri, stub, async testler |
| 10 | [XCUITest](10-xcuitest.md) | UI testleri, erişilebilirlik kimlikleri, başlatma argümanları |
| 11 | [CI](11-ci.md) | GitHub Actions, `xcodebuild`, sonuç paketleri, kapsam |

### Nasıl çalıştırılır?

**Xcode'da:** `make open` (ya da `BookShelf.xcodeproj`'a çift tıkla). Üstten `BookShelf` şemasını ve bir iPhone simülatörünü seç.

| Kısayol | İş |
|---|---|
| ⌘B | Derle |
| ⌘R | Çalıştır |
| ⌘U | Tüm testleri çalıştır (birim + UI) |
| ⌘6 | Test Navigator. Tek bir testi ya da sınıfı buradan veya kod satırının yanındaki elmas (◇) simgesinden çalıştırabilirsin. |
| ⇧⌘K | Clean Build Folder (tuhaf derleme hatalarında ilk çare) |

**Terminalde:**

| Komut | Ne yapar? |
|---|---|
| `make` / `make help` | Hedefleri listeler |
| `make build` | Uygulamayı ve test paketlerini derler |
| `make unit` | Derler ve birim testlerini çalıştırır |
| `make ui` | Derler ve UI testlerini çalıştırır |
| `make test` | Derler, birim ve UI testlerini çalıştırır |
| `make ci` | CI'daki akışın aynısı, sonunda kod kapsamı özeti |
| `make clean` | `build/` klasörünü siler |
| `make open` | Projeyi Xcode'da açar |

Simülatör otomatik seçilir: seçili Xcode'un SDK'sıyla uyumlu en yeni iOS sürümündeki bir iPhone. Belirli bir simülatör için: `make test SIMULATOR_ID=<UDID>`. UDID'leri `xcrun simctl list devices available` listeler. Hangi hedefin seçileceğini hiçbir şey başlatmadan görmek için: `./scripts/ci.sh destination`.

## Bu projede nerede?

| Dosya | Ne görmelisin? |
|---|---|
| [project.pbxproj](../BookShelf.xcodeproj/project.pbxproj) | Üç `PBXNativeTarget`, dört `PBXFileSystemSynchronizedRootGroup`, boş `PBXSourcesBuildPhase` listeleri; `XCBuildConfiguration` içinde `SWIFT_VERSION`, `TEST_HOST`, `BUNDLE_LOADER`, `TEST_TARGET_NAME`, `SWIFT_OBJC_BRIDGING_HEADER`, `INFOPLIST_KEY_*` |
| [BookShelf.xcscheme](../BookShelf.xcodeproj/xcshareddata/xcschemes/BookShelf.xcscheme) | Paylaşılan şema: `TestAction` (Debug, iki `TestableReference`, `parallelizable = "NO"`) |
| [BookShelfApp.swift](../BookShelf/App/BookShelfApp.swift) | `BookShelfApp` (`@main`): `init()` içinde başlatma argümanlarını okur, `-ui-testing`'de animasyonları kapatır |
| [AppDependencies.swift](../BookShelf/App/AppDependencies.swift) | `AppDependencies.makeForLaunch(arguments:)`: argümana göre servisi kurar |
| [RootTabView.swift](../BookShelf/App/RootTabView.swift) | `RootTabView`: dört sekme ve her sekmenin öğrettiği konu |
| [Features/](../BookShelf/Features/) | Her ekran kendi klasöründe: [BookList](../BookShelf/Features/BookList/), [BookDetail](../BookShelf/Features/BookDetail/), [Favorites](../BookShelf/Features/Favorites/), [ConcurrencyLab](../BookShelf/Features/ConcurrencyLab/), [Fundamentals](../BookShelf/Features/Fundamentals/), [ISBNChecker](../BookShelf/Features/ISBNChecker/) |
| [LaunchArgument.swift](../Shared/LaunchArgument.swift) | `LaunchArgument`: iki hedefte ortak sabitler |
| [AccessibilityID.swift](../Shared/AccessibilityID.swift) | `AccessibilityID`. Her özellik kendi `AccessibilityID+<Özellik>.swift` dosyasında genişletir. |
| [BookShelf-Bridging-Header.h](../BookShelf/ObjC/BookShelf-Bridging-Header.h) | Köprü başlığı: `BKISBNValidator.h` ve `BKReadingTimeEstimator.h` |
| [ProjectSetupTests.swift](../BookShelfTests/ProjectSetupTests.swift) | `ProjectSetupTests`: `@testable import`, hosted testte `Bundle.main`, ObjC köprüsünün testten görünmesi |
| [LaunchSmokeUITests.swift](../BookShelfUITests/LaunchSmokeUITests.swift) | `LaunchSmokeUITests`: ayrı süreç, `launchArguments`, `Shared/` sabitleri |
| [BookShelfTests/Support/](../BookShelfTests/Support/) | `StubBookService`, `Book.fixture(...)`: tüm birim testlerinin ortak yardımcıları |
| [.gitignore](../.gitignore) | `xcuserdata/` dışarıda, `xcshareddata/` içeride |
| [scripts/ci.sh](../scripts/ci.sh), [Makefile](../Makefile), [ci.yml](../.github/workflows/ci.yml) | Derleme/test komutları; ayrıntılar [11 – CI](11-ci.md) |

## Sık yapılan hatalar

**1. UI testinde uygulamanın tiplerini kullanmaya çalışmak**

```swift
// YANLIŞ (BookShelfUITests içinde)
@testable import BookShelf                      // UI test paketi uygulamaya bağlanmaz ve ayrı süreçte koşar
let rowID = "bookList.row.\(Book.fixture().id)" // `Book` burada yok

// DOĞRU: Shared/ içindeki sabitler iki hedefte de derlenir
let rowID = AccessibilityID.BookList.row(bookID: 1)
XCTAssertTrue(app.buttons[rowID].waitForExistence(timeout: 5))
```

**2. `Shared/` içinden uygulamaya ait bir tipe başvurmak**

```swift
// YANLIŞ: Shared/AccessibilityID+BookList.swift
static func row(for book: Book) -> String { "bookList.row.\(book.id)" }
// UI test hedefi de bu dosyayı derler ama orada `Book` yok → "Cannot find type 'Book' in scope"

// DOĞRU: sadece Foundation / temel tipler
static func row(bookID: Int) -> String { "bookList.row.\(bookID)" }
```

**3. Dosyayı yanlış klasöre koymak**

```text
YANLIŞ: BookShelf/Testing/StubBookService.swift        → test kodu uygulamayla birlikte kullanıcıya gider
YANLIŞ: BookShelfTests/Helpers/PriceFormatter.swift    → uygulama bu tipi göremez
DOĞRU : test yardımcıları BookShelfTests/Support/ altında, uygulama kodu BookShelf/ altında
```

Senkronize klasörlerde klasör = hedef üyeliği. Bir dosyanın nereye gireceğini klasörü belirler.

**4. `@testable import`'u Release'te kullanmak**

```bash
# YANLIŞ
xcodebuild test -scheme BookShelf -configuration Release ...
# → "Module 'BookShelf' was not compiled for testing" (Release'te ENABLE_TESTABILITY açık değil)

# DOĞRU: testleri Debug'da çalıştır (şemanın Test eylemi zaten Debug)
xcodebuild test -scheme BookShelf -configuration Debug ...
```

**5. Klasöre elle `Info.plist` eklemek**

```text
YANLIŞ: BookShelf/Info.plist oluşturup içine CFBundleDisplayName yazmak
        → Dosya kaynak olarak kopyalanmaya çalışılır, Xcode'un ürettiği Info.plist ile çakışır:
          "Multiple commands produce '.../BookShelf.app/Info.plist'"
DOĞRU : Build Settings'te INFOPLIST_KEY_CFBundleDisplayName = "Kitaplık"
        (GENERATE_INFOPLIST_FILE = YES olduğu sürece anahtarlar build ayarlarından üretilir)
```

**6. Hosted testlerde uygulamanın durumuna güvenmek**

```swift
// YANLIŞ: testin, host uygulamanın açılışta kurduğu nesnelere veya global duruma bağlı olması
// (BookShelfApp.init() test sürecinde de çalışır; ama onun oluşturduğu nesneler testin kontrolünde değildir)

// DOĞRU: her test ihtiyacını kendisi kurar ve başka hiçbir şeye bağlı kalmaz
func testTogglingAddsFavorite() async {
    let store = FavoritesStore()
    await store.toggle(1)
    let isFavorite = await store.contains(1)
    XCTAssertTrue(isFavorite)
}
```

**7. Şemayı paylaşmamak veya kişisel dosyaları commit etmek**

```text
YANLIŞ: Şema sadece xcuserdata/ altında → CI makinesinde senin şeman yok; test ayarların orada geçerli olmaz
YANLIŞ: xcuserdata/ ve *.xcuserstate commit etmek → her açılışta değişen, çakışan kişisel dosyalar
DOĞRU : Product > Scheme > Manage Schemes… > "Shared" işaretli; xcuserdata/ .gitignore'da
```

## Mülakatta sorulabilecekler

1. **Project, target, scheme ve workspace arasındaki fark nedir?**
   Proje hedefleri ve ayarları tutar. Hedef bir ürünün (app, test paketi, framework) tarifidir. Şema hangi hedeflerin hangi eylemde (Run/Test/Archive) hangi yapılandırmayla derlenip çalışacağını söyler. Workspace birden çok projeyi bir arada açar.

2. **Hosted (application) test ile hostless (logic) test farkı nedir? `TEST_HOST` ve `BUNDLE_LOADER` ne yapar?**
   Hosted testte test paketi çalışan uygulamanın içine yüklenir (`TEST_HOST`) ve uygulamanın sembollerine karşı bağlanır (`BUNDLE_LOADER`, `-bundle_loader`). Uygulama kodu, `Bundle.main` ve UIKit ortamı kullanılabilir. Hostless test uygulama açmadan çalışır, daha hızlıdır ama kodun bir framework/pakette olmasını gerektirir.

3. **`@testable import` nasıl çalışır, şartı nedir?**
   `internal` sembolleri test modülüne `public` gibi açar. `public` sınıflar da testte `open` gibi davranır, yani alt sınıflanabilir ve override edilebilir. Modülün `ENABLE_TESTABILITY = YES` (`-enable-testing`) ile derlenmiş olması gerekir. Bu genelde yalnızca Debug'da açıktır. `private` ve `fileprivate` yine görünmez.

4. **UI testleri neden uygulama kodunu doğrudan çağıramaz? Uygulamaya nasıl bilgi aktarılır?**
   UI testleri ayrı bir çalıştırıcı süreçte koşar ve uygulamayı başka bir süreç olarak başlatır. Uygulamayı yalnızca erişilebilirlik ağacı üzerinden, bir kullanıcı gibi görürler. Bilgi `launchArguments` / `launchEnvironment` ile aktarılır. Ortak sabitler iki hedefe birden derlenen dosyalarla (bizde `Shared/`) paylaşılır.

5. **Xcode 16'daki senkronize klasörler neyi çözer?**
   pbxproj artık dosyaları tek tek listelemez; klasördeki dosyalar otomatik olarak bağlı hedeflere girer. Birleştirme çakışmaları ve "dosya diskte var ama hedefte yok" hataları büyük ölçüde ortadan kalkar. İstisnalar Target Membership ile tanımlanır.

6. **Swift 6 dil modu neyi değiştirir? Approachable Concurrency ve Default Actor Isolation nedir?**
   Swift 6 modunda tam eşzamanlılık denetimi açıktır ve olası data race'ler derleme hatasıdır. Default Actor Isolation = MainActor, işaretsiz tüm kodu `@MainActor` sayar (SE-0466). Approachable Concurrency bir grup upcoming feature açar. Swift 6 modunda asıl farkı `nonisolated async` fonksiyonların çağıranın actor'ünde çalışmasıdır (`NonisolatedNonsendingByDefault`, SE-0461); arka plana geçmek için `@concurrent` gerekir.

7. **Bridging header ne işe yarar? Ters yön nasıl çalışır?**
   Bridging header'a `#import` edilen Objective-C başlıkları uygulama hedefindeki tüm Swift dosyalarına açılır. Ters yönde Xcode `<ModülAdı>-Swift.h` başlığını üretir (bizde `BookShelf-Swift.h`). `.m` dosyası bunu import ederek `@objc` ile işaretli Swift API'lerini kullanır.

8. **Debug ve Release arasındaki farklar nelerdir?**
   Debug'da optimizasyon kapalıdır (`-Onone`), `DEBUG` koşulu tanımlıdır ve testability açıktır. Release'te optimizasyon ve whole-module derleme açıktır ve dSYM üretilir. Performans ölçümleri Release'te yapılmalıdır.

## Alıştırmalar

**1. Yeni bir başlatma argümanı ekle: `-seed-favorites`**
Uygulama bu argümanla açıldığında 1 ve 2 numaralı kitaplar favori olarak başlasın. Sonra bunu kullanan küçük bir UI testi yaz.
*İpucu:* Sabiti `Shared/LaunchArgument.swift`'e ekle (iki hedef de görsün). `AppDependencies.makeForLaunch(arguments:)` içinde `FavoritesStore(initialFavorites: [1, 2])` ile kur. UI testinde `app.launchArguments` dizisine ekle ve Favoriler sekmesinde `AccessibilityID.Favorites.cell(bookID: 1)` kimliğini ara.

**2. Senkronize klasörü kendi gözünle gör**
`Shared/` altına `AccessibilityID+Demo.swift` adında yeni bir dosya ekle, içinde tek bir sabit tanımla ve bu sabiti hem bir uygulama ekranında hem de bir UI testinde kullan. pbxproj'un değişmediğini doğrula.
*İpucu:* Dosyayı eklemeden önce ve sonra `shasum BookShelf.xcodeproj/project.pbxproj` çalıştır; iki çıktı aynı olmalı. Dosyada `import Foundation` dışında bir şey import etme.

**3. İzolasyon varsayılanlarını deneyerek karşılaştır**
Uygulama hedefinde geçici olarak `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` ayarla ve derle. Hangi uyarı veya hataların çıktığını, `LocalBookService`'in hangi actor'e bağlı sayıldığını not et. Sonra ayarı geri al.
*İpucu:* Build Settings'te "Default Actor Isolation" diye ara. `LocalBookService.fetchBooks()` içine bir breakpoint koy ve iki ayarla çalıştır. Debug Navigator'da (⌘7) durulan thread'e bak: ana thread "Thread 1" olarak, `com.apple.main-thread` etiketiyle görünür. (`Thread.isMainThread` async bir fonksiyonun içinde doğrudan kullanılamaz; Swift 6'da derleme hatası verir.) `LocalBookService`'in belgesindeki "global concurrent executor" açıklamasının hangi ayarda geçerli olduğunu düşün. Deneyden sonra `git diff` ile pbxproj'un eski haline döndüğünü kontrol et.
