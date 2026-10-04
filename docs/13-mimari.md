# Mimari: MVC, MVVM, VIPER, Clean Architecture ve Dependency Inversion

## Neden önemli?

- **Mülakatın sabit sorusu.** "Hangi mimariyi kullandın, neden?", "VIPER'da kim kimi tutar?", "Dependency Inversion ile Injection aynı şey mi?" soruları neredeyse her iOS mülakatında gelir. Ezber tanımla değil, **ödünleşimlerle** (trade-off) cevap vermek beklenir.
- **Test edilebilirliği mimari belirler.** İş kuralı view controller'ın içindeyse onu test etmek için ekran kurmak gerekir. Kural UI'sız bir tipteyse test milisaniyeler sürer.
- **Ekip büyüdükçe sınırlar önem kazanır.** Beş kişinin aynı 2000 satırlık view controller'a dokunması çakışma demektir; sorumluluklar ayrılınca herkes kendi parçasında çalışır.

Bu projede **Okuma Notları** özelliği bilerek iki kez yazıldı: **VIPER + UIKit** ve **MVVM + SwiftUI**. İkisi de aynı Domain katmanını (use case'ler + `NotesRepository` protokolü) kullanıyor. Mülakat sekmesinde "Clean Architecture, VIPER ve MVVM" konusunun **Demo** bölümünde ikisi arasında geçiş yapabilir, birinde eklediğin notu diğerinde görebilirsin.

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
