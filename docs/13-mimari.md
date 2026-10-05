# Mimari: MVC, MVVM, VIPER, Clean Architecture ve Dependency Inversion

## Neden önemli?

- **Mülakatın sabit sorusu.** "Hangi mimariyi kullandın, neden?", "VIPER'da kim kimi tutar?", "Dependency Inversion ile Injection aynı şey mi?" soruları neredeyse her iOS mülakatında gelir. Ezber tanımla değil, **ödünleşimlerle** (trade-off) cevap vermek beklenir.
- **Test edilebilirliği mimari belirler.** İş kuralı view controller'ın içindeyse onu test etmek için ekran kurmak gerekir. Kural UI'sız bir tipteyse test milisaniyeler sürer.
- **Ekip büyüdükçe sınırlar önem kazanır.** Beş kişinin aynı 2000 satırlık view controller'a dokunması çakışma demektir; sorumluluklar ayrılınca herkes kendi parçasında çalışır.

Bu projede **Okuma Notları** özelliği bilerek iki kez yazıldı: **VIPER + UIKit** ve **MVVM + SwiftUI**. İkisi de aynı Domain katmanını (use case'ler + `NotesRepository` protokolü) kullanıyor. Mülakat sekmesinde "Clean Architecture, VIPER ve MVVM" konusunun **Demo** bölümünde ikisi arasında geçiş yapabilir, birinde eklediğin notu diğerinde görebilirsin.

İkinci VIPER örneği **Kitap Arama**: servis çağrısı yapan, yazarken arayan, eski aramayı iptal eden ve gerçek navigasyon yapan bir modül; dört farklı türde use case ve katman katman testleriyle (§11, Mülakat sekmesinde "VIPER'da bir servis çağrısı nasıl akar?").

## Temel kavramlar

### 1. Mimari ne çözer?

Her ekranda aynı işler var: veriyi bir yerden almak, iş kurallarını uygulamak (doğrulama, sıralama), veriyi gösterilecek metne çevirmek, kullanıcı olaylarını karşılamak, başka ekrana geçmek. Mimari kalıplar bu işleri **kimin** yapacağını söyler. Amaç dosya sayısı değil:

- Değişiklik tek yere dokunsun (depolama değişince ekran değişmesin).
- Her parça tek başına test edilebilsin.
- Yeni gelen biri kodu nereden okumaya başlayacağını bilsin.

### 2. MVC ve "Massive View Controller"

Apple'ın UIKit'teki MVC'sinde view controller hem **Controller** hem de View'ın yaşam döngüsünün sahibidir. Pratikte veri yükleme, biçimlendirme, doğrulama, navigasyon, tablo data source'u... hepsi VC'ye birikir. Şaka yollu adı: *Massive View Controller*.

Bu projede Favoriler sekmesi ([FavoritesViewController.swift](../BookShelf/Features/Favorites/FavoritesViewController.swift)) MVC'ye yakındır; ama durum mantığını UIKit'siz bir enum'a ([FavoritesState.swift](../BookShelf/Features/Favorites/FavoritesState.swift)) taşıyarak şişmeyi sınırlar. Küçük ekranlar için bu çoğu zaman yeterlidir; MVC "kötü" değil, büyüyünce pahalıdır.

### 3. MVVM

```
View  ──(eylem: load, saveDraft, delete)──▶  ViewModel  ──▶  Use case'ler
  ▲                                              │
  └──────────── gözlem (@Observable) ────────────┘
```

- **ViewModel** ekranın durumunu (`state`) ve eylemlerini tutar. View'ı **tanımaz**: `import SwiftUI` bile yok.
- **View** durumu okur ve çizer. SwiftUI'da `@Observable` sayesinde sadece okuduğu özellik değişince yeniden çizilir. UIKit'te bağlama elle (closure, Combine) yapılır.
- Geri referans olmadığı için weak/strong derdi yok; ViewModel `await viewModel.load()` diye doğrudan test edilir.

Projede: [NotesListViewModel.swift](../BookShelf/Features/ReadingNotes/Presentation/MVVM/NotesListViewModel.swift), [NotesListView.swift](../BookShelf/Features/ReadingNotes/Presentation/MVVM/NotesListView.swift).

### 4. VIPER

**V**iew · **I**nteractor · **P**resenter · **E**ntity · **R**outer. 2014'te objc.io'daki bir yazıyla yaygınlaştı; amacı UIKit'te Massive View Controller'ı sorumluluklara bölmektir.

| Parça | Görevi | Bu projede |
|---|---|---|
| View | Pasif: olayları iletir, söyleneni çizer | `NotesListViewController` |
| Presenter | Olaylara karar verir, sonucu ekran metnine çevirir; UIKit bilmez | `NotesListPresenter` |
| Interactor | İş mantığını (use case'leri) çalıştırır, sonucu bildirir | `NotesListInteractor` |
| Entity | Saf veri modeli | `ReadingNote` |
| Router | Navigasyon ve modül kurulumu (`build`) | `NotesListRouter` |

Her ok bir protokoldür ([NotesListContracts.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListContracts.swift)). Mülakatın en sevdiği kısım **sahiplik**:

| Referans | Tür | Neden |
|---|---|---|
| ViewController → Presenter | strong | Modülü yaşatan zincirin başı |
| Presenter → Interactor, Router | strong | Presenter onların tek sahibi |
| Presenter → View | **weak** | VC zaten presenter'ı tutuyor; strong olsaydı döngü |
| Interactor → Presenter (output) | **weak** | Presenter interactor'ı tutuyor |
| Router → ViewController | **weak** | VC'nin sahibi navigasyon yığını |

Modülün tek dış sahibi VC'yi gösteren yapıdır (navigation controller, SwiftUI). O bırakınca bütün modül serbest kalır. Bunun testi: `NotesListRouterTests.testReleasingViewControllerReleasesWholeModule`.

Modül nasıl kurulur? `NotesListRouter.build(repository:)`:

```swift
let interactor = NotesListInteractor(useCases: NotesUseCases(repository: repository))   // constructor injection
let router = NotesListRouter()
let presenter = NotesListPresenter(interactor: interactor, router: router, formatter: formatter)
let viewController = NotesListViewController(presenter: presenter)

presenter.view = viewController          // property injection (weak)
interactor.output = presenter            // property injection (weak)
router.viewController = viewController   // property injection (weak)
```

Strong bağımlılıklar `init` ile, weak geri referanslar property ile verilir. Neden? Presenter oluşturulurken VC henüz yoktur; VC ise init'inde presenter ister. Döngünün bir yönü, nesneler oluştuktan sonra bağlanmak zorundadır.

### 5. Presenter ile ViewModel farkı

| | Presenter (VIPER/MVP) | ViewModel (MVVM) |
|---|---|---|
| View'ı tanır mı? | Evet, bir protokol üzerinden (`view?.render(...)`) | Hayır |
| Veri akışı | İtme (push): presenter view'a komut verir | Gözlem: view durumu okur |
| View'a referans | `weak` | Yok |
| Test | Sahte view (spy) ile, senkron | Doğrudan durum okuyarak |

İkisinin ortak kuralı: **UIKit/SwiftUI olmadan test edilebilir olmak.** Bu projede presenter `import UIKit` etmez, view model `import SwiftUI` etmez.

### 6. Clean Architecture ve bağımlılık kuralı

Clean Architecture (Robert C. Martin) bir sunum kalıbı değil, **bütün uygulamanın** katmanlarını ve bağımlılık yönünü tarif eder. MVVM ve VIPER onun en dış halkasında, sunum katmanında yaşar.

```
┌──────────────────────── Presentation ────────────────────────┐
│  VIPER (UIKit)                         MVVM (SwiftUI)        │
└──────────────────────────────┬───────────────────────────────┘
                               │ bilir / çağırır
                               ▼
┌─────────────────────────── Domain ───────────────────────────┐
│  Entity: ReadingNote                                         │
│  Use case: FetchNotesUseCase, AddNoteUseCase, DeleteNote...  │
│  Protokol: NotesRepository           (sadece Foundation)     │
└──────────────────────────────▲───────────────────────────────┘
                               │ uygular (implements)
┌─────────────────────────── Data ─────────────────────────────┐
│  InMemoryNotesRepository, UserDefaults, dosya, Core Data...  │
└──────────────────────────────────────────────────────────────┘
```

**Bağımlılık kuralı:** Kaynak koddaki bütün oklar içeri, Domain'e bakar.

- Domain hiçbir dış katmanı bilmez: `import UIKit`, `SwiftUI`, `CoreData` yok.
- Data katmanı Domain'in protokolünü uygular. Çalışma anında çağrı dışarı gider (use case → depo) ama kaynak koddaki ok içeri bakar. Bu ters çevirme Dependency Inversion'dır (bkz. 9. bölüm).
- Sınırlardan **Domain tipleri** geçer. Core Data'nın `NSManagedObject`'i ekrana sızmaz; depo onu `ReadingNote` struct'ına çevirir (mapping).

**Use case nedir?** Uygulamaya özgü tek bir iş: "not ekle". İş kuralları burada yaşar: [AddNoteUseCase.swift](../BookShelf/Features/ReadingNotes/Domain/UseCases/AddNoteUseCase.swift) metni kırpar, boşsa ve 280 karakteri aşıyorsa `NoteValidationError` fırlatır. VIPER'daki alert ile MVVM'deki satır içi mesajın **aynı metni** göstermesinin sebebi bu.

**Pragmatik not:** Her özelliğe use case yazmak şart değildir. Mantık "depodan al, göster"den ibaretse ekstra katman tören olur. Use case'ler için ayrı protokol yazmamamızın gerekçesi [NotesUseCases.swift](../BookShelf/Features/ReadingNotes/Domain/UseCases/NotesUseCases.swift) dosyasında.

### 7. Coordinator: navigasyonu ayırmak

MVVM navigasyonun nerede yapılacağını söylemez. UIKit'te yaygın çözüm **Coordinator**'dır (MVVM-C): ekranlar "şu oldu" der, hangi ekranın açılacağına coordinator karar verir. VIPER'daki Router'ın görevine benzer, ama bir akışın (birden çok ekranın) sahibidir. Bu projede yok; kavram şöyle görünür:

```swift
@MainActor
final class NotesCoordinator {
    private let navigationController: UINavigationController
    private let repository: any NotesRepository

    init(navigationController: UINavigationController, repository: any NotesRepository) {
        self.navigationController = navigationController
        self.repository = repository
    }

    func start() {
        navigationController.pushViewController(NotesListRouter.build(repository: repository), animated: false)
    }
}
```

SwiftUI'da benzer işi `NavigationStack(path:)` ile durumdan (state) yönetilen navigasyon yapar.

### 8. Karşılaştırma ve nasıl seçilir?

| | MVC | MVVM | VIPER |
|---|---|---|---|
| Bu özellikte dosya | 1 VC | 2-3 | 5 (sözleşmeler + 4 sınıf) |
| Test edilebilirlik | Zor | İyi | Çok iyi |
| Tören (boilerplate) | Az | Orta | Çok |
| Navigasyon | VC içinde | View ya da Coordinator | Router |
| Doğal ortam | Küçük UIKit ekranları | SwiftUI, UIKit + bağlama | Büyük UIKit ekipleri |

Seçerken sorulacak sorular:

1. Ekranın ne kadar mantığı var? Bir ayar ekranı için VIPER fazla.
2. UI çatısı ne? SwiftUI'ın kendisi zaten durum odaklı; MVVM doğal oturur. VIPER'ın "presenter view'a komut verir" modeli SwiftUI'a uymaz: SwiftUI view'ı bir `struct`, ona (weak) referans tutulamaz.
3. Ekip ne kadar büyük, modül sınırları ne kadar sıkı olmalı?
4. Ekip kalıbı biliyor mu? Herkesin farklı yorumladığı bir VIPER, iyi uygulanmış bir MVVM'den kötüdür.

Önemli olan tutarlılık ve iş kuralının UI'dan ayrılması; harf sayısı değil.

### 9. SOLID ve Dependency Inversion

SOLID, nesne yönelimli tasarımın beş ilkesidir:

| | İlke | Tek cümle |
|---|---|---|
| S | Single Responsibility | Bir tipin değişmek için tek bir sebebi olsun. |
| O | Open/Closed | Genişletmeye açık, değiştirmeye kapalı. |
| L | Liskov Substitution | Alt tip, üst tipin beklendiği her yerde doğru çalışsın. |
| I | Interface Segregation | Kimse kullanmadığı metotlara bağımlı olmasın (küçük protokoller). |
| D | Dependency Inversion | Üst seviye kod alt seviyeye değil, soyutlamaya bağlı olsun. |

**Dependency Inversion Principle (DIP):**

1. Üst seviye modüller alt seviye modüllere bağlı olmamalı; ikisi de soyutlamalara bağlı olmalı.
2. Soyutlamalar ayrıntılara bağlı olmamalı; ayrıntılar soyutlamalara bağlı olmalı.

Kritik ve sık atlanan nokta: **soyutlamanın sahibi kim?** Protokol, politika tarafında (Domain) durmalı. [NotesRepository.swift](../BookShelf/Features/ReadingNotes/Domain/Repositories/NotesRepository.swift) Domain'de; depolar (bellek, dosya, Core Data...) onu uygular. Protokol Data katmanında dursaydı Domain yine Data'yı import etmek zorunda kalırdı ve hiçbir şey "tersine" dönmezdi.

"Inversion" neyi çeviriyor? **Kaynak kod bağımlılığının yönünü.** Klasik katmanlamada üst katman alt katmanı import eder. DIP'te alt katman, üst katmanın protokolünü uygular. Çalışma anındaki çağrı yönü değişmez.

### 10. Dependency Injection ve DIP'ten farkı

**Dependency Injection (DI)** bir **teknik**tir: nesne bağımlılığını kendisi oluşturmaz, dışarıdan alır.

| | DIP | DI |
|---|---|---|
| Ne? | Tasarım **ilkesi** | Uygulama **tekniği** |
| Cevapladığı soru | Bağımlılık **neye** (soyutlamaya mı, ayrıntıya mı)? | Bağımlılık **nasıl** gelir (içeride mi oluşur, dışarıdan mı)? |
| Biri olmadan diğeri | DI'sız DIP mümkün (ör. protokolü bir service locator'dan istemek: kod yine sadece soyutlamayı bilir) | DIP'siz DI mümkün (somut sınıf enjekte etmek) |

DI, DIP'i uygulamanın en yaygın yoludur ama aynı şey değildir. Demodaki üç sayaç ([DependencyExamples.swift](../BookShelf/Features/Interview/Demos/Architecture/DependencyExamples.swift)) farkı gösterir:

```swift
// (a) Ne DI ne DIP: bağımlılığını kendisi oluşturur.
struct TightlyCoupledNoteCounter {
    private let repository = InMemoryNotesRepository()
}

// (b) DI var, DIP yok: dışarıdan gelir ama somut tip. Core Data deposu verilemez.
struct ConcreteInjectedNoteCounter {
    let repository: InMemoryNotesRepository
}

// (c) DI + DIP: dışarıdan gelir ve Domain'in protokolü.
struct InjectedNoteCounter {
    let repository: any NotesRepository
}
```

**DI teknikleri:**

| Teknik | Örnek | Ne zaman? |
|---|---|---|
| Constructor (init) | `AddNoteUseCase(repository:now:)` | Varsayılan tercih. Zorunlu bağımlılık eksik kalamaz, `let` ile değişmez. |
| Property | `presenter.view = viewController` | Geri (weak) referanslar, storyboard'dan gelen VC'ler. Atanmayı unutma riski var. |
| Method | `NotesPlainTextExporter.export(_:using:)` | Bağımlılık çağrıdan çağrıya değişiyorsa. Standart kütüphanede: `sorted(by:)`. |
| SwiftUI Environment | `@Environment(\.noteFormatter)` | Değeri view ağacı boyunca aşağı taşımak. Verilmezse varsayılan sessizce kullanılır. |

**Composition root:** Somut tiplerin seçilip birbirine bağlandığı **tek** yer. Bu projede [AppDependencies.makeForLaunch](../BookShelf/App/AppDependencies.swift): UI testinde bellek deposu, normalde varsayılan depo. Geri kalan kod sadece protokolleri görür. `NotesListRouter.build` ise VIPER modülünün kendi küçük composition root'udur.

**DI container (Swinject vb.):** Bağımlılıkları kaydedip çözen bir kütüphane. Çok sayıda bağımlılık ve yaşam süresi (scope) yönetiminde işe yarar; ama şart değildir. Bu projede yok, elle DI yeterli.

**Service locator (anti-kalıp):** Nesne bağımlılığını global bir kayıttan kendisi ister:

```swift
// Bağımlılık imzada görünmüyor; test için global kaydı değiştirmek gerekiyor.
final class NotesScreenModel {
    func load() async throws -> [ReadingNote] {
        try await Locator.shared.resolve(NotesRepository.self).fetchAll()
    }
}
```

Sorunları: bağımlılık imzada görünmez, global durum testleri birbirine bağlar, eksik kayıt ancak çalışma anında çöker. DI'da ise bağımlılık `init`'te görünür ve derleyici denetler.

**IoC ile ilişkisi:** Inversion of Control daha geniş bir fikirdir: akışı senin kodun değil çerçeve yönetir ("bizi arama, biz seni ararız"). DI, IoC'nin bağımlılık oluşturmaya uygulanmış bir biçimidir.

### 11. VIPER'da servis çağrısı: adım adım

Okuma Notları'nın VIPER modülü yerel bir depoyla konuşur ve "navigasyonu" bir alert'tir. Mülakattaki VIPER sorusu ise çoğunlukla "ağdan veri çeken bir ekran"dır. Bunun için ikinci bir modül var: **Kitap Arama** ([Features/BookSearch/](../BookShelf/Features/BookSearch/)). Yazarken arar, 600 ms gecikmeli servisi (`LocalBookService`) çağırır, eski aramayı iptal eder, satıra dokununca detayı gerçekten push eder. Mülakat sekmesinde "VIPER'da bir servis çağrısı nasıl akar?" konusunun **Demo** bölümü bu modüldür.

```text
Features/BookSearch/
├── Domain/                4 use case + protokolleri, BookInsights, SearchQueryError, RecentSearchesStore (protokol)
├── Data/                  RecentSearchesStores.swift: UserDefaults ve bellek uygulamaları (ikisi de actor)
└── Presentation/VIPER/    Contracts, ViewController, Presenter, Interactor, Router, Configuration
```

**"atay" yazıldığında, adım adım:**

| # | Katman | Ne olur? | Kod |
|---|---|---|---|
| 1 | View | `UISearchBar` her harfte delegate'e haber verir. VC karar vermez, iletir. | `searchBar(_:textDidChange:)` → `presenter.didChangeSearchText("atay")` |
| 2 | Presenter | Metin boş değil: aramayı başlat. (Boş olsaydı: iptal + son aramalar.) | `interactor.search(query: "atay", trigger: .typing)` |
| 3 | Interactor | Önce uçuştaki aramayı iptal eder, sonra kuralı ANINDA sorar. Tek harf olsaydı ipucu hemen gelirdi; ne debounce ne ağ. | `cancelSearch()`, `search.validatedQuery("atay")` |
| 4 | Interactor | Bir `Task` açar ve 300 ms bekler (debounce). Bu sürede yeni harf gelirse bu task iptal edilir, servis hiç çağrılmaz. | `try await Task.sleep(for: delay)` |
| 5 | Interactor → Presenter → View | "Arama başladı" → yükleniyor göstergesi | `output?.didStartSearching(query:)` → `view?.render(.loading)` |
| 6 | Use case | Ana actor'den çıkılır: servis çağrılır, eşleştirilir, sıralanır. | `SearchBooksUseCase.execute(query:)` → `service.fetchBooks()` |
| 7 | Interactor | Ana actor'e dönülür. Bu arada yeni arama başladıysa sonuç ESKİ: atılır. Hata da öyle: iptal edilmiş aramanın hatası bildirilmez. | `try Task.checkCancellation()`, `catch _ where Task.isCancelled` |
| 8 | Presenter → View | `[Book]` → satırlar ("Oğuz Atay · 1972"); sonuç yoksa açıklayan mesaj | `didFindBooks(_:for:)` → `render(.results(rows:))` |
| 9 | Router | Satıra dokununca detay push edilir; satırı bulan sorgu geçmişe yazılır (kutudaki metin değil: debounce sırasında kutuda "atayz" yazarken satırlar hâlâ "atay"ın olabilir). | `didSelectBook(id:)` → `router.showBookDetail(book)`, `interactor.rememberSearch(resultsQuery)` |

Interactor'ın kalbi ([BookSearchInteractor.swift](../BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchInteractor.swift), kısaltılmış):

```swift
func search(query rawQuery: String, trigger: BookSearchTrigger) {
    cancelSearch()                                         // 1) son arama kazanır
    let search = useCases.search                           // task'tan ÖNCE yerel sabitlere kopyala (Sendable)
    let query: String
    do {
        query = try search.validatedQuery(rawQuery)        // typed throws: `error` doğrudan SearchQueryError
    } catch {
        output?.didRejectQuery(error)                      // 2) kural ihlali: anında, ağsız
        return
    }
    let delay = trigger == .typing ? configuration.debounce : .zero
    searchTask = Task { [weak self] in                     // ana actor'ü miras alır; self'i TUTMAZ
        do {
            if delay > .zero { try await Task.sleep(for: delay) }   // 3) debounce
            try Task.checkCancellation()
            self?.output?.didStartSearching(query: query)
            let books = try await search.execute(query: query)     // 4) ana actor'den çık… geri dön
            try Task.checkCancellation()                           // 5) geç gelen eski sonucu düşür
            self?.output?.didFindBooks(books, for: query)
            // 6) yalnızca açık istekle yapılıp sonuç veren arama geçmişe yazılır (aşağıda)
        } catch is CancellationError {
            // sessizce yut: kullanıcı yeni bir şey yazdı ya da ekran kapandı
        } catch _ where Task.isCancelled {
            // iptal edilmiş aramanın HATASI da bildirilmez (ör. URLSession'ın URLError(.cancelled)'ı)
        } catch {
            self?.output?.didFailSearch(error, query: query)
        }
    }
}
```

**İptal nerede yaşar, nasıl çalışır?**

- **Sahibi interactor.** Task'ı o açıyor, use case'i o `await` ediyor. Presenter senkron ve UIKit'siz kalır; task tutsaydı testleri bekleme gerektirir ve async mantık sunuma sızardı.
- `cancel()` task'ı zorla durdurmaz, bir **bayrak** kaldırır (cooperative cancellation). Bayrağa tepki veren yerler: `Task.sleep` (debounce ve servisin taklit gecikmesi hemen `CancellationError` fırlatır), servisin `Task.checkCancellation()`'ı ve interactor'ın `await`'ten sonraki kontrolü.
- `await`'ten sonraki kontrol neden şart? Servis iptali görmezden gelebilir ya da cevap tam iptal anında gelebilir. Kontrol olmasaydı "ata"nın geç gelen sonucu "atay"ın sonucunu ezerdi: data race olmadan bir **race condition**. Kanıtı: `BookSearchInteractorTests.testStaleResultIsDroppedEvenIfServiceIgnoresCancellation` (iptali hiç görmeyen, "inatçı" bir spy servisle).
- İptal edilmiş bir aramanın **hiçbir sonucu** bildirilmez: ne kitaplar ne **hata**. `await`'ten sonraki kural hatalar için de geçerli. İptal bir hata değildir, ama her zaman `CancellationError` olarak da gelmez: `URLSession` iptal edilen isteği `URLError(.cancelled)` ile bitirir; servis iptalden hemen önce gerçek bir hata da vermiş olabilir. Bu yüzden ölçüt hatanın türü değil task'ın durumu: `catch _ where Task.isCancelled`. Yalnızca `catch is CancellationError` yazsaydık gerçek ağda her yeni harfte bir an "Arama yapılamadı" görünür, eski aramanın hatası da yeni aramanın sonuçlarını silerdi. Kanıtı: `testCancelledSearchFailingWithURLErrorCancelledIsNotReported`, `testStaleErrorIsDroppedEvenIfServiceIgnoresCancellation`. Özet isteği ve `LoadBookInsightsUseCase` de aynı kuralı uygular.
- Modül kapanınca `deinit` uçuştaki aramayı iptal eder. Task `self`'i yalnızca `weak` tuttuğu için 600 ms'lik istek modülü hayatta tutmaz (`testReleasingInteractorCancelsInFlightSearch`).
- Favori bir **komut**tur; iptal edilmez ve task saklanmaz. Kullanıcı "favorile" dedi; ekran kapansa bile tamamlanmalı (Okuma Notları'ndaki "kaydet" ile aynı karar).

**Geçmişe ne yazılır? (`BookSearchTrigger`)** Aramayı neyin başlattığı hem zamanlamayı hem kaydı belirler:

| Tetikleyici | Ne zaman? | Debounce | Sonuç verirse geçmişe yazılır mı? |
|---|---|---|---|
| `.typing` | Her harfte | Evet (300 ms) | Hayır: "t", "tu", "tut"… geçmişi kirletirdi |
| `.submitted` | Ara düğmesi, geçmişten seçim, Tekrar dene | Hayır | Evet |
| `rememberSearch(_:)` | Yazarak bulunan bir sonuç açıldı | — | Evet: arama işe yaradı. Yazılan, kutudaki metin değil satırı bulan sorgu (`resultsQuery`) |

Bu kuralı ilk sürümde UI testi yakaladı: Her başarılı arama kaydediliyordu ve kutudaki metni harf harf silmek her öneki geçmişe yazıyordu. Birim testleri yeşildi; sorun, parçaların birleştiği yerdeydi. Uçtan uca testin değeri tam olarak bu.

**Neden hepsi `@MainActor`?** (Ayrıntısı [BookSearchContracts.swift](../BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchContracts.swift) başında.)

1. View bir `UIViewController`; SDK onu `@MainActor` işaretler. View protokolü de `@MainActor` olmalı ki presenter `view?.render(...)`'ı `await`'siz çağırabilsin.
2. Presenter view'ı, interactor presenter'ı **senkron** çağırır. Hepsi aynı actor'deyse bu çağrılar düz fonksiyon çağrısıdır: hop yok, `await` yok. Değişen durum (`searchText`, son sonuçlar, `searchTask`) tek bir seri yerde yaşar; data race olmadığını derleyici kanıtlar.
3. `@MainActor` "her şey ana thread'de" demek değildir. Yavaş iş nonisolated `async` use case'lerde; bu projenin ayarlarıyla (Approachable Concurrency kapalı) global concurrent executor'de çalışır. Her `await` ana actor'den çıkar ve geri döner. Formül: **durum ve koordinasyon ana actor'de, hesap ve bekleme dışarıda.**
4. Interactor'ı ayrı bir actor yapmak mümkündü ama kazanç yok: işi hesap değil koordinasyon. Bedeli: Her `output` çağrısı ana actor'e bir `await` (hop) olur. `MainActor.run` gerekmez; `@MainActor` bir metodu başka bir actor'den çağırmak için `await output?.didFindBooks(...)` yeter, geçişi derleyici yapar. Daha önemlisi presenter → interactor çağrıları da async olur: presenter senkron kalamaz ve durum iki actor arasında bölünür.
5. Xcode 26'nın yeni proje şablonları aynı fikri modül varsayılanı yapar: **Default Actor Isolation = MainActor** (SE-0466) ve **Approachable Concurrency** (`NonisolatedNonsendingByDefault`, SE-0461: nonisolated async fonksiyon çağıranın actor'ünde çalışır). O ayarlarla use case'ler varsayılan olarak `@MainActor` olurdu; dışarı çıkmak için `nonisolated`, async işi kesinlikle arka plana göndermek için `@concurrent` yazılır. Bu projede ikisi de kapalı (bkz. [01 Proje yapısı](01-proje-yapisi.md)); bu yüzden `@MainActor` açıkça yazılıyor.

**Dört farklı tür use case:**

| Use case | Tür | Kural / politika | Neden presenter ya da depo/servis değil? |
|---|---|---|---|
| [SearchBooksUseCase](../BookShelf/Features/BookSearch/Domain/SearchBooksUseCase.swift) | Sorgu + iş kuralı (uzak servis) | Kırp, en az 2 harf; Türkçe büyük/küçük harf ve aksan katlama (I, ı, İ, i aynı; "oguz" → "Oğuz"); önce başlık, sonra yazar, Türkçe alfabetik | "Hangi kitap uygun, hangi sırayla?" bir ürün kararı. Servis veri getirir; presenter yalnızca gösterir. |
| [LoadBookInsightsUseCase](../BookShelf/Features/BookSearch/Domain/LoadBookInsightsUseCase.swift) | Birleştirme (aggregation) | Yorumlar ve yazar `async let` ile paralel; **yorumlar zorunlu, yazar profili isteğe bağlı**; ortalama tek ondalık | Kısmi hata politikası bir iş kuralı. Presenter'a konsa iki sonucu ve iki hatayı bilmek zorunda kalırdı. |
| [ToggleFavoriteUseCase](../BookShelf/Features/BookSearch/Domain/ToggleFavoriteUseCase.swift) | Komut (paylaşılan durumda yan etki) | Yeni durumu döndürür | Bugün ince; asıl atomiklik `FavoritesStore.toggle`'da. Değeri sınırda: test dikişi ve kuralın ileride ekleneceği tek yer. |
| [RecentSearchesUseCase](../BookShelf/Features/BookSearch/Domain/RecentSearchesUseCase.swift) | Yerel depolama politikası | En fazla 5, tekrar yok (arama anahtarına göre), en yeni başta | Depo değişse (UserDefaults/bellek) kural değişmez; kural değişse depo değişmez. Kayıt `update(_:)` ile atomik. |

**Use case'lere neden burada protokol var, Okuma Notları'nda yok?** Okuma Notları'nda tek test dikişi depo; interactor testleri gerçek use case'leri bellek deposuyla çalıştırır (daha az tip, gerçek kurallar teste dahil). Burada interactor'ın asıl işi zamanlama: "ilk sorgu yavaş, ikincisi hızlı" gibi senaryoları sorgu başına kontrol edebilmek için spy use case gerekir. Bedeli: 4 protokol + 4 double ve spy gerçek davranıştan saparsa yanlış güven. Bu riski use case testleri ve UI testi azaltır. Gerekçenin tamamı [BookSearchUseCases.swift](../BookShelf/Features/BookSearch/Domain/BookSearchUseCases.swift) dosyasında.

**Gerçek navigasyon ve gömme.** Router detayı `UIHostingController(rootView: BookDetailView(...))` olarak push eder. Push için bir `UINavigationController` gerekir; ama konu ekranının SwiftUI çubuğu zaten üstte. [BookSearchVIPERContainer.swift](../BookShelf/Features/Interview/Demos/Architecture/BookSearchVIPERContainer.swift) yığını **çubuğu gizli** kurar (iki çubuk olmasın); geri dönüş, detayın alt araç çubuğundaki "Sonuçlara dön" düğmesidir. Araç çubuğunu ekran ekran açıp kapatan, representable'ın `Coordinator`'ıdır (`UINavigationControllerDelegate`). Aynı nedenle arama kutusu `UISearchController` değil, düz bir `UISearchBar`: `UISearchController` navigasyon çubuğunda yaşar.

**Ayar dışarıdan.** Debounce süresi `BookSearchConfiguration` ile enjekte edilir: uygulamada 300 ms, `-ui-testing` ile 0, birim testinde istenen süre. Interactor `ProcessInfo` okumaz; argümanları en dıştaki container okur.

Testlerin katman katman nasıl yazıldığı: [09 XCTest](09-xctest.md) → "VIPER katmanlarını test etmek".

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [ReadingNote.swift](../BookShelf/Features/ReadingNotes/Domain/Entities/ReadingNote.swift) | `ReadingNote` | Entity: sadece Foundation, depolama teknolojisinden bağımsız |
| [NotesRepository.swift](../BookShelf/Features/ReadingNotes/Domain/Repositories/NotesRepository.swift) | `NotesRepository` | Soyutlama Domain'de: DIP'in kalbi |
| [AddNoteUseCase.swift](../BookShelf/Features/ReadingNotes/Domain/UseCases/AddNoteUseCase.swift) | `validate(_:)`, `execute(text:bookID:)`, `NoteValidationError` | İş kuralı tek yerde; typed throws; "şu an" bile enjekte |
| [NotesUseCases.swift](../BookShelf/Features/ReadingNotes/Domain/UseCases/NotesUseCases.swift) | `NotesUseCases` | Bağımlılık kuralı; use case'ler için neden protokol yok |
| [NotesListContracts.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListContracts.swift) | 5 protokol, `NotesListViewState` | VIPER haritası ve sahiplik tablosu |
| [NotesListRouter.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListRouter.swift) | `build(repository:formatter:)`, `makeNoteEditor(onSave:)` | Constructor + property injection; `[weak alert]` |
| [NotesListPresenter.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListPresenter.swift) | `viewState(for:formatter:)` | UIKit'siz presenter, saf fonksiyon, `[weak self]` callback |
| [NotesListInteractor.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListInteractor.swift) | `loadNotes()`, `addNote(text:)` | Senkron olaydan async işe köprü; weak output |
| [NotesListViewController.swift](../BookShelf/Features/ReadingNotes/Presentation/VIPER/NotesListViewController.swift) | `configureTableView()`, `render(_:)` | Pasif view; self-sizing hücreler; kaydırarak silme |
| [NotesListViewModel.swift](../BookShelf/Features/ReadingNotes/Presentation/MVVM/NotesListViewModel.swift) | `NotesListViewModel` | Aynı use case'lerle MVVM; iyimser silme |
| [NoteFormatter.swift](../BookShelf/Features/ReadingNotes/Presentation/NoteFormatter.swift) | `NoteFormatter`, `DateNoteFormatter`, `LengthNoteFormatter` | Strategy kalıbı; testte sabit çıktılı biçimlendirici |
| [ReadingNotesDemoView.swift](../BookShelf/Features/Interview/Demos/Architecture/ReadingNotesDemoView.swift) | `ReadingNotesDemoView` | İki arayüz, tek depo; depo seçici = DIP'in canlı kanıtı |
| [DependencyExamples.swift](../BookShelf/Features/Interview/Demos/Architecture/DependencyExamples.swift) | Üç sayaç, `NotesPlainTextExporter` | Sıkı bağlılık, DIP'siz DI, DI + DIP; method injection |
| [DependencyInjectionDemoView.swift](../BookShelf/Features/Interview/Demos/Architecture/DependencyInjectionDemoView.swift) | `EnvironmentValues.noteFormatter` | SwiftUI Environment ile DI (`@Entry`) |
| [AppDependencies.swift](../BookShelf/App/AppDependencies.swift) | `makeForLaunch(arguments:)` | Composition root |
| [NotesListRouterTests.swift](../BookShelfTests/ReadingNotes/NotesListRouterTests.swift) | `testReleasingViewControllerReleasesWholeModule` | VIPER modülünde retain cycle olmadığının kanıtı |
| [NotesListPresenterTests.swift](../BookShelfTests/ReadingNotes/NotesListPresenterTests.swift) | `NotesListPresenterTests` | Sahte view/interactor/router ile senkron presenter testi |
| [NotesArchitectureDoubles.swift](../BookShelfTests/ReadingNotes/NotesArchitectureDoubles.swift) | `ViewSpy`, `InteractorSpy`, `FailingRepository` | Spy, stub, fake farkı |
| [BookSearchContracts.swift](../BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchContracts.swift) | `BookSearchViewState`, `BookSearchTrigger`, 5 protokol | Aramanın yolculuğu şeması; "Neden hepsi `@MainActor`?" |
| [BookSearchInteractor.swift](../BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchInteractor.swift) | `search(query:trigger:)`, `deinit` | Task saklama, son arama kazanır, debounce, iptal edilmiş aramanın sonucunu da hatasını da düşürmek, `[weak self]` |
| [BookSearchPresenter.swift](../BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchPresenter.swift) | `errorState(for:)`, `insightsSummary(for:)` | UIKit'siz, `await`'siz presenter; hata → mesaj + "tekrar denensin mi?" |
| [BookSearchRouter.swift](../BookShelf/Features/BookSearch/Presentation/VIPER/BookSearchRouter.swift) | `build(dependencies:recentSearchesStore:configuration:)`, `makeBookDetail(for:dependencies:)` | Modül kurulumu; `UIHostingController` push (gerçek navigasyon) |
| [SearchBooksUseCase.swift](../BookShelf/Features/BookSearch/Domain/SearchBooksUseCase.swift) | `searchKey(for:)`, `matches(in:for:)` | Türkçe katlama ve sıralama: sorgu + iş kuralı türü use case |
| [LoadBookInsightsUseCase.swift](../BookShelf/Features/BookSearch/Domain/LoadBookInsightsUseCase.swift) | `execute(for:)` | `async let` ile birleştirme; kısmi hata politikası; iptali yeniden fırlatmak |
| [BookSearchUseCases.swift](../BookShelf/Features/BookSearch/Domain/BookSearchUseCases.swift) | `BookSearchUseCases` | Dört use case türü tablosu; use case'lere neden burada protokol var |
| [BookSearchVIPERContainer.swift](../BookShelf/Features/Interview/Demos/Architecture/BookSearchVIPERContainer.swift) | `BookSearchVIPERContainer.Coordinator` | Çubuğu gizli `UINavigationController`; çift çubuk olmadan push |

## Sık yapılan hatalar

**1. VIPER'da geri referansı strong tutmak.**

```swift
// YANLIŞ: VC → presenter → view (VC) döngüsü. Ekran kapansa da modül bellekte kalır, deinit çalışmaz.
final class NotesListPresenter {
    var view: (any NotesListViewProtocol)?
}

// DOĞRU: Geri referans weak. Protokol `AnyObject` olmalı ki `weak` yazılabilsin.
@MainActor protocol NotesListViewProtocol: AnyObject { ... }
final class NotesListPresenter {
    weak var view: (any NotesListViewProtocol)?
}
```

**2. İş kuralını ViewModel'e (ya da VC'ye) gömmek.**

```swift
// YANLIŞ: Kural arayüzde. VIPER ekranı da aynı kuralı yeniden yazmak zorunda; biri değişir, diğeri unutulur.
func saveDraft() async {
    guard !draftText.trimmingCharacters(in: .whitespaces).isEmpty else { ... }
}

// DOĞRU: Kural use case'te; arayüz sadece sonucu gösterir.
try await useCases.add.execute(text: draftText)   // NoteValidationError fırlatır
```

**3. Protokolü yanlış katmana koymak.**

```swift
// YANLIŞ: Soyutlama Data katmanında. Domain onu kullanmak için Data'yı import etmek zorunda; ok tersine dönmedi.
// Data/CoreDataNotesStore.swift
protocol CoreDataNotesStoreProtocol { ... }

// DOĞRU: Soyutlama, onu kullanan politika tarafında (Domain); Data onu uygular.
// Domain/Repositories/NotesRepository.swift
protocol NotesRepository: Sendable { ... }
```

**4. "DI kullanıyorum, o halde DIP de var" sanmak.**

```swift
// DI var ama üst seviye kod hâlâ Core Data'ya bağlı:
struct AddNoteUseCase {
    init(repository: CoreDataNotesRepository) { ... }
}
// DIP için tip, Domain'in protokolü olmalı:
struct AddNoteUseCase {
    init(repository: any NotesRepository) { ... }
}
```

**5. Zorunlu bağımlılığı property injection ile vermek.**

```swift
// YANLIŞ: `repository` atanmayı unutulursa nil kalır; çağrı sessizce hiçbir şey yapmaz.
final class NotesScreenModel {
    var repository: (any NotesRepository)?
    func load() async { _ = try? await repository?.fetchAll() }
}

// DOĞRU: Zorunlu bağımlılık init'te; derleyici eksik bırakmana izin vermez.
final class NotesScreenModel {
    private let repository: any NotesRepository
    init(repository: any NotesRepository) { self.repository = repository }
}
```

**6. Her ekrana (ve her tipe) aynı ağır kalıbı uygulamak.** Tek uygulaması olan, yan etkisiz bir tip için protokol; basit bir ayar ekranı için VIPER modülü, kazandırdığından fazlasını götürür. Soyutlama değişmesi muhtemel ya da testte değiştirilmesi gereken sınırlarda (depo, ağ, saat) değerlidir.

## Mülakatta sorulabilecekler

**1. Clean Architecture, MVVM ve VIPER arasındaki fark ne?**
MVVM ve VIPER sunum katmanını böler. Clean Architecture bütün uygulamanın katmanlarını ve bağımlılık yönünü tarif eder; içinde sunumu MVVM ile de VIPER ile de yazabilirsin. Bu projede iki sunum da aynı Domain'i paylaşıyor.

**2. VIPER'da kim kimi tutar?**
VC → presenter strong; presenter → interactor ve router strong; presenter → view, interactor → presenter, router → VC weak. Modülün tek dış sahibi VC'yi gösteren yapıdır. Weak geri referanslar property injection ile bağlanır, çünkü presenter oluşturulurken VC henüz yoktur.

**3. Presenter ile ViewModel arasındaki fark ne?**
Presenter view'ı bir protokol üzerinden tanır ve ona komut verir; bu yüzden view'a weak referans tutar. ViewModel view'ı tanımaz; durumu yayınlar, view gözlemler. İkisi de UI olmadan test edilebilir olmalı.

**4. Bağımlılık kuralı nedir? Core Data nesnelerini ekrana verebilir miyim?**
Kaynak koddaki oklar içeri, Domain'e bakar; Domain UIKit, SwiftUI, Core Data bilmez. Managed object'leri ekrana vermek ekranı depolama teknolojisine bağlar ve thread sorunlarına açar (managed object'ler context'inin kuyruğuna bağlıdır); depo sınırda Domain struct'ına çevirmelidir.

**5. Dependency Inversion ile Dependency Injection aynı şey mi?**
Hayır. DIP bir ilke: üst seviye kod ayrıntıya değil soyutlamaya bağlı olmalı ve soyutlamanın sahibi politika tarafıdır. DI bir teknik: bağımlılık dışarıdan verilir. DI, DIP'i uygulamanın yaygın yoludur ama somut sınıf enjekte edersen DI var, DIP yok.

**6. DI çeşitleri neler? Hangisini tercih edersin?**
Constructor, property, method injection; SwiftUI'da Environment. Varsayılan constructor: zorunlu bağımlılık eksik kalamaz ve değişmez. Property injection geri referanslar ve storyboard VC'leri için; method injection çağrıya özel stratejiler için.

**7. Composition root ve service locator nedir?**
Composition root, somut tiplerin seçilip bağlandığı tek yerdir (bu projede `AppDependencies.makeForLaunch`). Service locator, nesnenin bağımlılığını global bir kayıttan kendisinin istemesidir; bağımlılığı gizlediği ve hataları çalışma anına ittiği için anti-kalıp sayılır.

**8. Her özellik için use case yazmalı mıyım?**
İş kuralı varsa evet: kural tek yerde olur, birden çok arayüz paylaşır, UI'sız test edilir. Sadece veri taşıyorsa ekstra katman tören olur; pragmatik ol.

**9. VIPER'da bir servis çağrısı nasıl akar? İptal nerede?**
View olayı iletir, presenter interactor'a "ara" der, interactor bir `Task` açıp use case'i `await` eder, use case servisi çağırıp kuralları uygular; sonuç output ile presenter'a, oradan ekran durumu olarak view'a döner. Async sınır ve iptal interactor'da: uçuştaki task saklanır, yeni sorgu öncekini iptal eder; iptal edilmiş aramanın ne sonucu ne hatası gösterilir. `await`'ten sonraki iptal kontrolü eski sonucu düşürür; hatada ölçüt `Task.isCancelled`'dır, çünkü `URLSession` iptali `URLError(.cancelled)` olarak gelir.

**10. Neden bütün VIPER modülü `@MainActor`? Ana thread tıkanmaz mı?**
View zaten `@MainActor`; presenter ve interactor onu senkron çağırdığı için aynı actor'de olmaları hop'suz, race'siz tek bir durum yeri sağlar. Tıkanmaz, çünkü yavaş iş nonisolated async use case'lerde: her `await` ana actor'den çıkar ve geri döner. Xcode 26 şablonlarındaki "Default Actor Isolation = MainActor" aynı fikri modül varsayılanı yapar.

## Alıştırmalar

**1. Not düzenlemeyi ekle.**
Bir satıra dokununca notu düzenleyen bir akış ekle: Domain'de `UpdateNoteUseCase` (aynı doğrulama kuralları), VIPER'da presenter → router → editör, MVVM'de aynı sayfa. Önce use case testini yaz.
*İpucu:* Depo `save` metodu zaten upsert (aynı `id` varsa günceller). Doğrulamayı tekrar yazma: `AddNoteUseCase.validate(_:)`'ı paylaşmanın bir yolunu bul (ör. ayrı bir `NoteTextPolicy` tipi). VIPER tarafında editörün başlangıç metnini router'a nasıl ileteceğini düşün.

**2. Retain cycle'ı kendi gözünle gör.**
`NotesListPresenter.view`'daki `weak`'i sil ve `NotesListRouterTests.testReleasingViewControllerReleasesWholeModule` testini çalıştır. Sonra eski haline getir ve aynısını `NotesListInteractor.output` için dene.
*İpucu:* Kod yine derlenir (strong özellik her zaman yazılabilir; hatayı derleyici değil test yakalar). `view` strong olunca VC ↔ presenter döngüsü kurulur ve test "VC serbest kalmalı" mesajıyla kırılır. `output` strong olunca VC serbest kalır ama presenter ↔ interactor döngüsü yüzünden "Presenter serbest kalmalı" kırılır. Xcode'un Debug Memory Graph'ı döngüyü ok olarak gösterir.

**3. Coordinator ile navigasyon.**
Favoriler sekmesine "Notlarım" adında bir düğme ekle ve VIPER modülünü (`NotesListRouter.build`) bir coordinator üzerinden push et. Favoriler ekranı notlar modülünün iç yapısını bilmemeli.
*İpucu:* Coordinator'ı `FavoritesView.makeUIViewController` içinde oluşturabilirsin; `UINavigationController`'ı zaten orada. Coordinator'ı kimin tuttuğuna dikkat et: hiçbir şey tutmazsa hemen serbest kalır.

**4. Sayaç için bir "decorator" depo yaz.**
`NotesRepository`'yi uygulayan ve başka bir depoyu saran `LoggingNotesRepository` yaz: her çağrıyı sayıp asıl depoya iletsin. Demo ekranlarının kodunu değiştirmeden, sadece bağımlılığı değiştirerek kullan.
*İpucu:* Sayaç değişken durum; tipi `actor` yap. Bu, DIP'in Open/Closed ile birlikte nasıl çalıştığının örneği: davranış eklendi, mevcut kod değişmedi.

**5. Arama sonuçlarını önbelleğe al.**
Kitap Arama her sorguda servisi baştan çağırıyor. Aynı oturumda servisten gelen kitap listesini bir kez alıp sonraki sorgularda yeniden kullanan bir katman ekle; ekran ve interactor kodu değişmesin.
*İpucu:* `BookServiceProtocol`'ü uygulayan ve başka bir servisi saran bir `actor CachingBookService` yaz (decorator). Aynı anda gelen iki ilk isteğin servisi iki kez çağırmaması için, devam eden isteği bir `Task` olarak saklayıp ikinci çağıranın da onu `await` etmesini sağla (actor reentrancy). Önce `BookSearchUseCaseTests`'e "iki arama, tek `fetchBooksCallCount`" testini yaz.
