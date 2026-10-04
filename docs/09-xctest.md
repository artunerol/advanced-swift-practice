# XCTest ile birim testleri

## Neden önemli?

- **Değişiklik yapma cesareti verir.** Bir view model'i yeniden düzenlediğinde (refactor) bu projedeki birim testlerinin tamamı birkaç saniyede koşar ve "hiçbir davranış bozulmadı" der. Test yoksa aynı güveni ancak uygulamayı elle gezerek kazanırsın ve bir şeyi mutlaka atlarsın.
- **Tasarımı iyileştirir.** Test yazması zor olan kod genellikle kötü ayrıştırılmıştır. Bu projede ekranlar somut `LocalBookService`'e değil `BookServiceProtocol`'e bağlı, mantık da SwiftUI/UIKit'ten ayrı tiplerde duruyor (`BookListViewModel`, `FavoritesState`, `ConcurrencyLab`). Bunun ana sebebi test edilebilirlik.
- **Concurrency hatalarını erken yakalar.** Swift 6 data race'leri derleme anında yakalar; ama "iptal edilen yükleme hata gibi gösterilmesin", "aynı anda iki yükleme servisi iki kez çağırmasın" gibi *mantık* hatalarını ancak testler yakalar.
- **CI'ın temelidir.** [CI dersinde](11-ci.md) gördüğün pipeline, her push'ta bu testleri koşar. Kırmızı test = birleştirilmeyen kod.
- **Mülakatta kesin çıkar.** "Async bir fonksiyonu nasıl test edersin?", "Stub ile mock farkı?", "`@testable import` ne yapar?", "`@MainActor` bir view model'i Swift 6'da nasıl test edersin?" standart sorulardır.

Bu projede birim testleri **XCTest** ile yazıldı (Apple'ın 2013'ten beri kullanılan test çatısı). Xcode 16 ile gelen **Swift Testing** ile farkları dersin sonunda.

## Temel kavramlar

### 1. Test hedefi, `XCTestCase` ve test metodu

Birim testleri ayrı bir **hedefte** (`BookShelfTests`) durur ve `BookShelfTests.xctest` adlı bir pakete derlenir. Bir test dosyasının iskeleti:

```swift
import XCTest
@testable import BookShelf

final class FavoritesStateTests: XCTestCase {
    func testLoadingStateDoesNotClaimTheListIsEmpty() {
        let state = FavoritesState.loading
        XCTAssertFalse(state.showsEmptyMessage)
    }
}
```

- **Test metodu nasıl bulunur?** XCTest, `XCTestCase` alt sınıflarında adı `test` ile başlayan, parametresiz ve `Void` döndüren her metodu test sayar. Metot `throws` ve/veya `async` olabilir.
- **`@testable import BookShelf`:** Uygulama modülünü, `internal` (Swift'in varsayılan erişim düzeyi) tipleri de görünecek şekilde içe aktarır. Bu yüzden `Book`, `BookListViewModel` gibi tiplere `public` yazmadan erişebiliriz. `private` ve `fileprivate` üyeler yine görünmez. Bunun çalışması için uygulamanın `ENABLE_TESTABILITY = YES` ile derlenmesi gerekir; bu ayar Debug'da açık, Release'te kapalıdır.
- **Hosted test:** Birim test paketi uygulamanın **içine** yüklenir (`TEST_HOST`) ve uygulamanın sembollerine karşı bağlanır (`BUNDLE_LOADER`). Testler başlamadan önce simülatörde uygulama açılır; bu yüzden testlerde `Bundle.main` uygulama paketidir ve `LocalBookService` `books.json`'u bulabilir. Ayrıntılar: [Proje yapısı](01-proje-yapisi.md).
- **Sıra:** XCTest bir sınıftaki testleri varsayılan olarak **ad sırasıyla** çalıştırır. Şemadaki test seçeneklerinden rastgele sıra açılabilir. Testlerin birbirinin sırasına **bağımlı olmaması** gerekir (bkz. yaşam döngüsü).

### 2. Yaşam döngüsü: `setUp` ve `tearDown`

**XCTest her test metodu için sınıftan YENİ bir örnek (instance) oluşturur.** Bir testte değiştirdiğin örnek özelliği bir sonraki teste taşınmaz. Her test için çağrı sırası şudur:

```
class func setUp()                  ← sınıftaki ilk testten önce BİR kez
│
├─ her test metodu için (yeni bir örnekte):
│     setUp() async throws
│     setUpWithError()
│     setUp()
│        test metodu
│        addTeardownBlock blokları   (son eklenen ilk çalışır: LIFO)
│     tearDown()
│     tearDownWithError()
│     tearDown() async throws
│
class func tearDown()               ← sınıftaki son testten sonra BİR kez
```

Bu sıra bir tahmin değil: [XCTestLifecycleTests.swift](../BookShelfTests/XCTestBasics/XCTestLifecycleTests.swift) her adımı bir günlüğe yazar ve en son çalışan `tearDown() async throws` içinde sırayı `XCTAssertEqual` ile doğrular. Sıra değişirse bu testler kırılır.

Gerçek kodda üçünü birden yazmazsın; ihtiyacına uyanı seçersin:

| Metot | Ne zaman? |
|---|---|
| `setUp() async throws` | Kurulum `await` gerektiriyorsa (ör. bir actor'e başlangıç verisi yazmak) |
| `setUpWithError() throws` | Kurulum hata fırlatabiliyorsa (`try XCTUnwrap(...)`, `try XCTSkipIf(...)`). Fırlatırsa test gövdesi çalışmaz, hata teste yazılır. |
| `setUp()` | Basit, senkron kurulum |
| `addTeardownBlock { }` | Test gövdesinin içinden "bitince bunu da temizle" demek; kaynağı açtığın satırın hemen yanına yazılır |

```swift
final class XCTestLifecycleTests: XCTestCase {
    private var store: FavoritesStore!

    override func setUp() async throws {
        try await super.setUp()
        let store = FavoritesStore()
        await store.add(1)       // actor → await; bu yüzden async setUp
        self.store = store
    }

    override func tearDown() async throws {
        store = nil              // test örnekleri koşu bitene kadar bellekte kalabilir; ağır nesneleri bırak
        try await super.tearDown()
    }
}
```

**`setUp` + özellik mi, `makeSUT()` fabrikası mı?** İkisi de yaygın. `setUp`'ta kurulan özellik (`store: FavoritesStore!`) her testte aynı başlangıcı garanti eder ama `!` ister. Fabrika metodu ([FavoritesViewControllerTests.swift](../BookShelfTests/Favorites/FavoritesViewControllerTests.swift)'teki `makeSUT(favoriteIDs:books:)`) her testin kendi başlangıç durumunu parametreyle vermesini sağlar, Optional gerektirmez ve testi okuyan kişi kurulumu testin içinde görür. SUT = *System Under Test*, yani test edilen nesne.

### 3. `XCTAssert` ailesi

| Doğrulama | Ne zaman? |
|---|---|
| `XCTAssertEqual(a, b)` / `XCTAssertNotEqual` | En çok kullanılan. `Equatable` ister; başarısızlıkta iki değeri de yazar. |
| `XCTAssertEqual(a, b, accuracy: 0.001)` | Kayan noktalı sayılar (`Double`) için |
| `XCTAssertTrue` / `XCTAssertFalse` | `Bool` koşullar. Başarısızlıkta sadece "false" der; mümkünse `XCTAssertEqual`'ı tercih et. |
| `XCTAssertNil` / `XCTAssertNotNil` | Optional'lar |
| `XCTAssertIdentical(a, b)` / `XCTAssertNotIdentical` | Aynı nesne mi? (`===`, class'lar için) |
| `XCTAssertGreaterThan`, `XCTAssertLessThanOrEqual`, ... | Sıralama; ör. süre ve sayaç sınırları |
| `XCTAssertThrowsError(try f()) { error in ... }` / `XCTAssertNoThrow` | Senkron fırlatan kod. **Async ifade almaz.** |
| `let x = try XCTUnwrap(optional)` | Optional'ı açar; `nil` ise testi o satırda durdurur. `!` ile çökertmekten iyidir. |
| `XCTFail("mesaj")` | Koşulsuz başarısızlık; ör. "buraya hiç gelinmemeliydi" |
| `try XCTSkipIf(koşul)` / `XCTSkipUnless` | Testi başarısız saymadan atla (ör. belirli bir iOS sürümünde) |

Pratik kurallar:

- **Son parametre mesajdır:** `XCTAssertTrue(isValid, "\(book.title) geçerli olmalı")`. Döngü içindeki doğrulamalarda hangi elemanın kırıldığını söyler ([ObjCISBNValidatorTests.swift](../BookShelfTests/ObjC/ObjCISBNValidatorTests.swift)).
- **Doğrulamalar senkron autoclosure alır.** İçlerinde `await` yazılamaz; önce değeri bir sabite al (bkz. "Actor'leri test etmek").
- **Yardımcı fonksiyonlara `file:` ve `line:` geçir.** Böylece hata, yardımcının içinde değil onu çağıran test satırında görünür:

```swift
@MainActor
private func bookListWaitUntil(_ condition: () -> Bool,
                               file: StaticString = #filePath, line: UInt = #line) async {
    for _ in 0..<10_000 {
        if condition() { return }
        await Task.yield()
    }
    XCTFail("Koşul zamanında sağlanmadı", file: file, line: line)
}
```

- **`continueAfterFailure = false`:** İlk başarısız doğrulamada testi durdurur. UI testlerinde yaygındır ([LaunchSmokeUITests.swift](../BookShelfUITests/LaunchSmokeUITests.swift)); birim testlerinde tek bir satırı durdurmak için `try XCTUnwrap` daha hedefli bir araçtır.

### 4. Async testler

Test metodunu `async` (ve gerekirse `throws`) yaz; XCTest metodun bitmesini bekler:

```swift
func testFetchBooksDecodesAllEightBooks() async throws {
    let books = try await service.fetchBooks()
    XCTAssertEqual(books.count, 8)
}
```

- **Nerede çalışır?** Bu projede (Approachable Concurrency kapalı) `@MainActor` olmayan bir `async` test metodu, nonisolated her async fonksiyon gibi **global concurrent executor**'de çalışır; ana thread'de değil. Senkron test metotlarını ise XCTest ana thread'de çağırır.
- **Fırlatmayı test etmek:** `XCTAssertThrowsError` async ifade almaz. `do/catch` kullan:

```swift
do {
    _ = try await service.fetchAuthorProfile(named: "Bilinmeyen Yazar")
    XCTFail("Hata fırlatılmalıydı")
} catch let error as BookServiceError {
    XCTAssertEqual(error, .authorNotFound("Bilinmeyen Yazar"))
}
```

- **İptali test etmek:** Task'ı başlat, hemen iptal et, `await task.value` ile sonucu al. `Task.sleep` iptal edilince hemen `CancellationError` fırlattığı için 10 saniyelik gecikme beklenmez ([LocalBookServiceTests.swift](../BookShelfTests/Core/LocalBookServiceTests.swift) → `testCancellationThrowsCancellationErrorPromptly`).
- **Sabit süre bekleme (`sleep`) YOK.** "Arka plandaki task bitmiştir herhalde" diye 0,5 sn beklemek hem yavaş hem de yüklü bir CI makinesinde kırılgandır. Bunun yerine ya task'ın kendisini `await` et, ya bir koşulu kısa aralıklarla yokla (polling: `bookListWaitUntil`, `waitUntil`), ya da bir callback'i `XCTestExpectation` ile bekle.
- **Zaman ölçen testlerde cömert ol.** Dar üst sınırlar yerine kesin alt sınırlar (3 × 200 ms sıralı iş en az 600 ms sürer) ve göreli karşılaştırmalar (paralel toplam < sıralı tahmin) kullan ([LabParallelismTests.swift](../BookShelfTests/ConcurrencyLab/LabParallelismTests.swift), [BookDetailViewModelTests.swift](../BookShelfTests/BookList/BookDetailViewModelTests.swift) → `testReviewsAndAuthorLoadConcurrently`).

### 5. `@MainActor` testler (Swift 6)

View model'ler `@MainActor`. Swift 6 dil modunda nonisolated bir test metodundan onların özelliklerine dokunmak **derleme hatasıdır**:

```
error: main actor-isolated property 'count' can not be referenced from a nonisolated autoclosure
```

Çözüm: Ana actor'deki tiplere dokunan **test metodunu** `@MainActor` işaretle.

```swift
final class BookListViewModelTests: XCTestCase {      // sınıf @MainActor DEĞİL
    @MainActor
    func testLoadSuccessMovesToLoadedState() async {  // metot @MainActor
        let service = StubBookService()
        let viewModel = BookListViewModel(service: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
    }
}
```

**Neden sınıfın tamamını değil de tek tek metotları?** `XCTestCase`'in `setUp()` ve `tearDown()` gibi senkron metotları nonisolated tanımlıdır. Sınıfı `@MainActor` yapsan bile bu metotların override'ları nonisolated kalır. Xcode 26.3'te (Swift 6.2) içlerinde ana actor'e bağlı bir özelliğe yazmak şu uyarıyı verir:

```
warning: main actor-isolated property 'viewModel' can not be mutated from a nonisolated context
```

Proje uyarısız derlenmeyi hedeflediği için kural basit: sınıfa değil, ana actor'e dokunan metoda `@MainActor` yaz. (Sınıf `@MainActor` iken `setUp() async throws` override'ı ana actor'de çalışabilir; ama senkron `setUp`/`tearDown`'la karışık kullanım kafa karıştırır.)

`@MainActor` bir test içinde açılan `Task { }` ana actor'ü **miras alır**. Test ile task aynı "tek şeritli yolda" sırayla ilerler; task ancak test bir `await` ile ana actor'ü bıraktığında çalışabilir. Bu, eşzamanlılık senaryolarını **deterministik** test etmeyi sağlar:

```swift
@MainActor
func testConcurrentLoadsCallServiceOnlyOnce() async {
    let service = StubBookService(delay: .milliseconds(50))
    let viewModel = BookListViewModel(service: service)

    let first = Task { await viewModel.load() }   // ikisi de ana actor'de
    let second = Task { await viewModel.load() }
    await first.value
    await second.value

    let calls = await service.fetchBooksCallCount
    XCTAssertEqual(calls, 1)                       // ikinci load `.loading` görüp döndü
}
```

[ConcurrencyLabViewModelTests.swift](../BookShelfTests/ConcurrencyLab/ConcurrencyLabViewModelTests.swift) → `testCancellingLongTaskReportsCancelled` aynı fikri kullanır: task'ın gövdesi, test `await` edene kadar başlayamaz; o ana kadar iptal bayrağı kalkmıştır ve iş 0 adımda durur.

### 6. `XCTestExpectation` + `await fulfillment(of:timeout:)`

Async bir API varsa doğrudan `await` et. Expectation, **callback ile** haber veren kod içindir: completion handler'lar, delegate'ler, bir `Task` içinde "şu an oldu" demek.

```swift
@MainActor
func testSwipeRemoveActionUpdatesStoreAndThenTable() async throws {
    // ...
    let completionCalled = expectation(description: "UIKit'e eylemin tamamlandığı bildirilmeli")
    removeAction.handler(removeAction, UIView()) { performed in
        XCTAssertTrue(performed)
        completionCalled.fulfill()
    }
    await fulfillment(of: [completionCalled], timeout: 1)
    // ...
}
```

- `fulfill()` çağrılmazsa `fulfillment` zaman aşımında testi başarısız sayar; test sonsuza dek asılı kalmaz. Zaman aşımını cömert tut (1–5 sn); normalde beklenti milisaniyeler içinde karşılanır.
- **Async testte `wait(for:timeout:)` kullanılamaz.** O çağrı thread'i bloklar; Swift 6'da derleme hatasıdır:
  `error: instance method 'wait' is unavailable from asynchronous contexts; Use await fulfillment(of:timeout:enforceOrder:) instead`
- Ek ayarlar: `expectedFulfillmentCount = 3` (üç kez çağrılmalı), `isInverted = true` ("bu olay OLMAMALI"; zaman aşımının tamamı beklenir, kısa tut), `enforceOrder: true` (birden çok beklentinin sırası), `assertForOverFulfill` (varsayılan `true`: fazladan `fulfill()` hata sayılır).
- Sonsuz olabilecek bir `await task.value`'yu zaman sınırına bağlamak için de kullanılır: [FavoritesViewControllerTests.swift](../BookShelfTests/Favorites/FavoritesViewControllerTests.swift) → `waitForCompletion(of:)`.

### 7. Actor'leri test etmek

Actor'ün her üyesine dışarıdan `await` ile erişilir. XCTest doğrulamaları `await` kabul etmediği için değeri önce bir sabite al:

```swift
let ids = await store.allIDs
XCTAssertEqual(ids, [2, 4])
```

Bu projede actor'lerle ilgili dört test kalıbı var:

| Kalıp | Örnek |
|---|---|
| **Durum geçişi:** metodu çağır, durumu oku | `FavoritesStoreTests.testToggleAddsThenRemovesAndReturnsNewState` |
| **Atomiklik:** aynı actor'e çok sayıda eşzamanlı çağrı yap, sonucun tam olduğunu doğrula | `testConcurrentAddsFromManyTasksAreAllRecorded` (1000 `add`), `testConcurrentTogglesAreAtomic` (çift sayıda `toggle` → başa dönüş) |
| **Akış (AsyncStream):** iterator al, her değişiklikten sonra `next()` ile bir sonraki değeri bekle | `testChangesYieldsCurrentSetImmediatelyThenEachChange` |
| **Yarışlı kodda değişmez (invariant):** sonucu şansa bağlı kodda tam değer yerine kesin bilinen sınırı doğrula | [LabSharedStateTests.swift](../BookShelfTests/ConcurrencyLab/LabSharedStateTests.swift): kilitsiz sayaç için yalnızca `≤ 1000` |

Actor'ün kendisi de bir **test double** olabilir: `StubBookService` bir actor. `BookServiceProtocol` `Sendable` istiyor ama stub sayaçları değiştirmek zorunda; actor ikisini birden sağlar. Stub'daki `Task.sleep` actor'ü bloklamaz (reentrancy), bu yüzden `async let` ile yapılan iki paralel çağrı gerçekten paralel bekler.

### 8. Test double'ları: dummy, stub, spy, mock, fake

Gerçek bağımlılığın yerine teste verilen nesnelere genel olarak *test double* denir (filmlerdeki dublör gibi). Bunu mümkün kılan şey protocol'e bağımlılıktır: `BookListViewModel(service: any BookServiceProtocol)` uygulamada `LocalBookService`, testte `StubBookService` alır.

| Tür | Ne yapar? | Bu projede |
|---|---|---|
| **Dummy** | İmzayı doldurmak için verilir, hiç kullanılmaz | `removeAction.handler(removeAction, UIView()) { ... }` içindeki `UIView()` |
| **Stub** | Önceden belirlenmiş cevapları döndürür | `StubBookService(books: .failure(.networkUnavailable))`, `setBooksResult(_:)` |
| **Spy** | Nasıl çağrıldığını kaydeder; doğrulamayı test yapar | `StubBookService.fetchBooksCallCount` → `XCTAssertEqual(calls, 1)` |
| **Mock** | Beklentileri önceden programlanır ve **kendisi doğrular** (`verify()`) | Projede yok; aşağıdaki örneğe ve Alıştırma 2'ye bak |
| **Fake** | Çalışan ama basitleştirilmiş gerçek uygulama | `LocalBookService(latency: .zero)`: sunucu yerine paketteki JSON'u okuyan servis |

Yani `StubBookService` hem stub hem spy'dır. Mock'u bir spy'dan ayıran şey doğrulamanın **nerede** durduğudur:

```swift
/// Mock: beklenen çağrıyı önceden bilir ve doğrulamayı kendisi yapar.
private actor BookDetailMockBookService: BookServiceProtocol {
    private let expectedReviewBookID: Book.ID
    private var receivedReviewBookIDs: [Book.ID] = []

    init(expectedReviewBookID: Book.ID) { self.expectedReviewBookID = expectedReviewBookID }

    func fetchReviews(for bookID: Book.ID) async throws -> [Review] {
        receivedReviewBookIDs.append(bookID)
        return []
    }
    func fetchBooks() async throws -> [Book] { [] }
    func fetchAuthorProfile(named authorName: String) async throws -> AuthorProfile { .fixture(name: authorName) }

    func verify(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(receivedReviewBookIDs, [expectedReviewBookID], file: file, line: line)
    }
}
```

Mock'lar testi uygulamanın *nasıl* çalıştığına (hangi metodu hangi sırayla çağırdığına) bağlar ve refactor'da kolay kırılır. Çoğu durumda stub + çıktının (durumun) doğrulanması yeterlidir; mock'u "bu çağrının yapılması davranışın ta kendisi" olduğunda kullan (ör. analitik olayı gönderildi mi?).

**Fixture'lar:** [Fixtures.swift](../BookShelfTests/Support/Fixtures.swift)'teki `Book.fixture(id:title:author:...)` varsayılan değerli parametrelerle test verisi üretir. Her test yalnızca kendisi için önemli alanı yazar (`Book.fixture(id: 7, author: "Yazar A")`); `Book` modeline yeni bir alan eklendiğinde de yüzlerce testi değil tek bir fonksiyonu güncellersin.

### 9. Kod kapsamı (code coverage)

Kapsam, testler çalışırken **yürütülen** satırların oranıdır. Derleyici koda sayaçlar ekler (`-enableCodeCoverage YES`); sonuç `.xcresult` paketine yazılır.

```bash
./scripts/ci.sh coverage                                             # hedef başına özet
xcrun xccov view --report build/results/unit.xcresult | grep ViewModel # dosya ve fonksiyon ayrıntısı
```

Xcode'da: Report Navigator (⌘9) → test çalıştırması → Coverage. Bu ders yazılırken birim testleri `BookShelf.app`'in yaklaşık %45'ini kapsıyordu: view model'ler ve `FavoritesStore` %95–100, çoğu SwiftUI `body`'si ise %0'a yakın (onları UI testleri çalıştırır; UI testleriyle kapsam %78'e çıkıyor, bkz. [XCUITest dersi](10-xcuitest.md)).

Kapsam **neyin test edilmediğini** gösterir; neyin *iyi* test edildiğini göstermez. Hiç doğrulama yapmayan bir test de satırları "kapsar". Yüzde hedefini bir araç olarak kullan (ör. "view model'ler %90'ın altına düşmesin"), amaç olarak değil. CI'daki kapsam adımı için: [CI](11-ci.md).

### 10. Performans testi: `measure { }`

```swift
func test_givenThousandISBNs_whenValidatingWithObjectiveC_thenPerformanceIsMeasured() {
    let isbns = Array(repeating: "978-605-000-001-6", count: 1_000)
    measure {
        for isbn in isbns { _ = ISBNValidator.isValidISBN13(isbn) }
    }
}
```

`measure` bloğu varsayılan olarak 10 kez çalıştırır ve ortalamayla sapmayı raporlar. **Taban çizgisi (baseline) yoksa hiçbir zaman başarısız olmaz.** Xcode'da sonucun yanındaki süreye tıklayıp "Set Baseline" dersen, sonraki çalıştırmalar belirgin şekilde yavaşlarsa test kırılır. Baseline makineye özeldir ve paylaşılan CI makinelerinde gürültülüdür. `measure(metrics: [XCTClockMetric(), XCTMemoryMetric()])` ile ölçülecek şeyi seçebilirsin. Bu bir "yavaşladı mı?" alarmıdır; nedenini bulmak için Instruments gerekir.

### 11. Adlandırma ve yapı: given-when-then

İyi bir test adı, test kırıldığında **kodu açmadan** neyin bozulduğunu söyler. `testLoad` kötü bir addır; `testLoadFailureMovesToFailedStateWithMessage` iyidir. İki yaygın biçim:

- **Düz camelCase** (projenin çoğu): `testCancelledLoadIsNotTreatedAsErrorAndCanStartAgain`
- **given-when-then**: `test_givenFreshStore_whenAddingFavorite_thenStoreHasBoth` ([XCTestLifecycleTests.swift](../BookShelfTests/XCTestBasics/XCTestLifecycleTests.swift))

Hangisini seçtiğin, bir ekipte tutarlı olmasından daha az önemlidir. Gövde de aynı üç parçaya ayrılır (*Arrange-Act-Assert* da denir). Bu projedeki testlerde parçalar boş satırlarla ayrılmış:

```swift
@MainActor
func testRetryAfterFailureLoadsAgain() async {
    let service = StubBookService(books: .failure(.networkUnavailable))   // given
    let viewModel = BookListViewModel(service: service)
    await viewModel.load()

    await service.setBooksResult(.success(Book.fixtures))                 // when
    await viewModel.load()

    XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))               // then
}
```

Bir test **tek bir davranışı** doğrulamalı. Adında "ve" geçiyorsa (ör. `testLoadsAndRefreshesAndFavorites`) muhtemelen ikiye bölünmelidir.

### 12. Swift Testing ile kısa karşılaştırma

Xcode 16'dan beri Apple'ın ikinci test çatısı **Swift Testing** de var. Makrolara dayanır ve aynı test hedefinde XCTest ile yan yana çalışabilir.

| | XCTest | Swift Testing |
|---|---|---|
| Test tanımı | `XCTestCase` alt sınıfı + `test` önekli metot | Herhangi bir fonksiyona `@Test` |
| Doğrulama | `XCTAssertEqual`, `XCTAssertTrue`, ... (20'yi aşkın ayrı fonksiyon) | `#expect(a == b)`, durdurmak için `try #require(x)` |
| `await` doğrulama içinde | Yazılamaz; önce sabite al | `#expect(await store.contains(7))` yazılabilir |
| Kurulum / yıkım | `setUp` / `tearDown` | Suite tipinin `init` / `deinit`'i (suite genelde `struct`) |
| Paralellik | Varsayılan olarak tek süreçte sırayla; paralel test ayrı simülatör kopyalarıyla | Varsayılan olarak aynı süreçte paralel; `.serialized` ile sıralı |
| Parametreli test | Döngü (tek test sayılır) | `@Test(arguments: [...])`: her girdi ayrı bir test |
| Callback bekleme | `XCTestExpectation` + `fulfillment(of:)` | `confirmation { confirm in ... }` |
| Hata fırlatma | `XCTAssertThrowsError` (senkron) | `#expect(throws: Hata.self) { try await ... }` (async de olur) |
| UI testi, `measure` | Var (`XCUIApplication`, `XCTMetric`) | Yok; bunlar için XCTest gerekir |

Aynı actor testi Swift Testing ile:

```swift
import Testing
@testable import BookShelf

@Suite("FavoritesStore")
struct FavoritesStoreSwiftTestingTests {
    let store = FavoritesStore()   // her test için yeni bir suite örneği → taze store

    @Test("toggle önce ekler, sonra çıkarır")
    func toggleAddsThenRemoves() async {
        #expect(await store.toggle(7) == true)
        #expect(await store.contains(7))
        #expect(await store.toggle(7) == false)
    }

    @Test func failingServiceThrows() async {
        let service = StubBookService(books: .failure(.networkUnavailable))
        await #expect(throws: BookServiceError.networkUnavailable) {
            try await service.fetchBooks()
        }
    }
}
```

Bu projede XCTest'i seçmemizin nedenleri: UI testleri ve `measure` zaten XCTest gerektiriyor, mevcut kod tabanlarının büyük çoğunluğu XCTest ile yazılı ve mülakatlarda hâlâ en çok o soruluyor. Yeni bir projede birim testleri için Swift Testing iyi bir varsayılandır; iki çatı aynı hedefte yan yana yaşayabildiği için geçiş dosya dosya yapılabilir.

## Bu projede nerede?

| Dosya | Tip / fonksiyon | Ne gösteriyor? |
|---|---|---|
| [XCTestLifecycleTests.swift](../BookShelfTests/XCTestBasics/XCTestLifecycleTests.swift) | `XCTestLifecycleTests` | Üç `setUp`, üç `tearDown`, `addTeardownBlock` (LIFO) sırasının kanıtı; her teste yeni örnek; `measure`; given-when-then adları |
| [StubBookService.swift](../BookShelfTests/Support/StubBookService.swift) | `StubBookService` (actor) | Stub + spy; `Result` ile ayarlanan cevaplar, çağrı sayaçları, isteğe bağlı gecikme |
| [Fixtures.swift](../BookShelfTests/Support/Fixtures.swift) | `Book.fixture(...)`, `Book.fixtures`, `Review.fixture(...)`, `AuthorProfile.fixture(...)` | Varsayılan parametreli test verisi üreticileri |
| [BookServiceProtocol.swift](../BookShelf/Core/Services/BookServiceProtocol.swift) | `BookServiceProtocol`, `BookServiceError` | Test double'ları mümkün kılan protocol; `Equatable` hata tipi |
| [ProjectSetupTests.swift](../BookShelfTests/ProjectSetupTests.swift) | `ProjectSetupTests` | `@testable import`, hosted testte `Bundle.main` |
| [BookListViewModelTests.swift](../BookShelfTests/BookList/BookListViewModelTests.swift) | `testConcurrentLoadsCallServiceOnlyOnce`, `testCancelledLoadIsNotTreatedAsErrorAndCanStartAgain`, `bookListWaitUntil` | Metot düzeyinde `@MainActor`, ana actor'de deterministik eşzamanlılık, polling yardımcısı ve `file:line:` |
| [BookDetailViewModelTests.swift](../BookShelfTests/BookList/BookDetailViewModelTests.swift) | `testReviewsAndAuthorLoadConcurrently`, `testISBNStatusAndReadingTimeComeFromObjectiveC` | `async let`'i cömert + göreli süre sınırıyla test etmek; ObjC sonucunu kendi çağrısıyla karşılaştırmak |
| [LocalBookServiceTests.swift](../BookShelfTests/Core/LocalBookServiceTests.swift) | `testUnknownAuthorThrowsAuthorNotFound`, `testCancellationThrowsCancellationErrorPromptly` | Async fırlatmayı `do/catch` ile test etmek; iptal |
| [FavoritesStoreTests.swift](../BookShelfTests/Core/FavoritesStoreTests.swift) | `testConcurrentTogglesAreAtomic`, `testChangesYieldsCurrentSetImmediatelyThenEachChange`, `testCancellingConsumerEndsItsLoopAndStoreKeepsWorking` | Actor atomikliği, `AsyncStream` iterator'ı, `expectation` + `fulfillment(of:)` |
| [FavoritesViewControllerTests.swift](../BookShelfTests/Favorites/FavoritesViewControllerTests.swift) | `makeSUT(favoriteIDs:books:)`, `waitUntil`, `waitForCompletion(of:)`, `testViewControllerIsReleasedWhileObservingAndDeinitCancelsTask` | SUT fabrikası, UIKit'i pencere olmadan test etmek, dummy, `weak var` ile bellek sızıntısı testi |
| [FavoritesStateTests.swift](../BookShelfTests/Favorites/FavoritesStateTests.swift) | `FavoritesStateTests` | Saf mantığın en basit hali: girdi ver, çıktıyı doğrula |
| [LabSharedStateTests.swift](../BookShelfTests/ConcurrencyLab/LabSharedStateTests.swift) | `testUnsafeCounterNeverExceedsExpectedTotal` | Yarışlı kodda tam değer değil, değişmez doğrulamak |
| [LabParallelismTests.swift](../BookShelfTests/ConcurrencyLab/LabParallelismTests.swift) | `LabParallelismTests` | Zamanlama testlerinde kesin alt sınır ve cömert üst sınır |
| [LabCancellationTests.swift](../BookShelfTests/ConcurrencyLab/LabCancellationTests.swift) | `testCancelledJobStopsEarlyAndReportsCancellation`, `LabProgressRecorder` | `sleep` yerine `AsyncStream` ile "tam o anda" iptal etmek; `@Sendable` closure'dan actor'e kayıt |
| [ConcurrencyLabViewModelTests.swift](../BookShelfTests/ConcurrencyLab/ConcurrencyLabViewModelTests.swift) | `testCancellingLongTaskReportsCancelled` | `XCTUnwrap` ile task tutamacını almak, `@MainActor` testte task'ın ne zaman başladığı |
| [ObjCISBNValidatorTests.swift](../BookShelfTests/ObjC/ObjCISBNValidatorTests.swift) | `testBundledBookEightHasChecksumMismatch` | `XCTAssertThrowsError` + hata kodunu incelemek, `XCTAssertNoThrow`, `XCTUnwrap` |
| [ci.sh](../scripts/ci.sh) | `cmd_unit`, `cmd_coverage` | Testleri komut satırından koşmak, `.xcresult`, kapsam özeti |

## Sık yapılan hatalar

**1. Doğrulamanın içinde `await`**

```swift
// YANLIŞ: derlenmez — 'await' in an autoclosure that does not support concurrency
XCTAssertEqual(await store.allIDs, [1])
```

```swift
// DOĞRU
let ids = await store.allIDs
XCTAssertEqual(ids, [1])
```

**2. Async testte `wait(for:)`**

```swift
// YANLIŞ: Swift 6'da hata — 'wait' is unavailable from asynchronous contexts
func testConsumer() async {
    let received = expectation(description: "değer geldi")
    // ...
    wait(for: [received], timeout: 1)
}
```

```swift
// DOĞRU
func testConsumer() async {
    let received = expectation(description: "değer geldi")
    // ...
    await fulfillment(of: [received], timeout: 1)
}
```

**3. Arka plan işini sabit süreyle beklemek**

```swift
// YANLIŞ: yavaş (her koşuda 0,5 sn) ve yüklü CI makinesinde yine de yetmeyebilir
Task { await viewModel.load() }
try await Task.sleep(for: .milliseconds(500))
XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
```

```swift
// DOĞRU: task'ı tut ve sonucunu bekle; ya da bir koşulu sınırlı sayıda yokla
let load = Task { await viewModel.load() }
await load.value
XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
```

**4. Testler arasında paylaşılan durum**

```swift
// YANLIŞ: `static` tüm testlerde ortak. Bir test favori eklerse sonraki test onu görür;
// sonuç testlerin çalışma sırasına bağlı olur.
final class FavoritesTests: XCTestCase {
    static let store = FavoritesStore()
}
```

```swift
// DOĞRU: her test kendi taze nesnesini alır (setUp'ta ya da makeSUT ile)
final class FavoritesTests: XCTestCase {
    private var store: FavoritesStore!
    override func setUp() {
        super.setUp()
        store = FavoritesStore()
    }
}
```

**5. Yarışlı ya da zamana bağlı kodda kesin değer beklemek**

```swift
// YANLIŞ: kilitsiz sayaç bazen şans eseri 1000 çıkar, bazen çıkmaz → ara sıra kırılan (flaky) test
XCTAssertNotEqual(report.finalValue, 1000)
// YANLIŞ: paralel iş ≈ 200 ms sürer ama yüklü makinede 260 ms de sürebilir
XCTAssertLessThan(report.elapsed, .milliseconds(220))
```

```swift
// DOĞRU: yalnızca kesin olarak bilinen şeyi doğrula
XCTAssertLessThanOrEqual(report.finalValue, 1000)                 // fazladan artış imkânsız
XCTAssertLessThan(report.elapsed, .milliseconds(500))             // sıralı olsaydı ≥ 600 ms
XCTAssertLessThan(extras.timing.total, extras.timing.sequentialEstimate) // göreli karşılaştırma
```

**6. Test sınıfını `@MainActor` yapmak**

```swift
// YANLIŞ: senkron setUp override'ı nonisolated kalır; Xcode 26.3'te iki uyarı:
// warning: main actor-isolated property 'viewModel' can not be mutated from a nonisolated context
// warning: call to main actor-isolated initializer 'init(service:)' in a synchronous nonisolated context
@MainActor
final class BookListViewModelTests: XCTestCase {
    var viewModel: BookListViewModel!
    override func setUp() {
        super.setUp()
        viewModel = BookListViewModel(service: StubBookService())
    }
}
```

```swift
// DOĞRU: ana actor'e dokunan metodu işaretle, SUT'u metodun içinde kur
final class BookListViewModelTests: XCTestCase {
    @MainActor
    func testLoadSuccessMovesToLoadedState() async {
        let viewModel = BookListViewModel(service: StubBookService())
        await viewModel.load()
        XCTAssertEqual(viewModel.state, .loaded(Book.fixtures))
    }
}
```

**7. Gerçek gecikmeli servisle birim testi**

```swift
// YANLIŞ: her test 600 ms+ bekler; ağ olsaydı internete de bağımlı olurdu
let viewModel = BookListViewModel(service: LocalBookService())
```

```swift
// DOĞRU: sıfır gecikmeli stub; sonucu ve hatayı test belirler
let viewModel = BookListViewModel(service: StubBookService(books: .failure(.networkUnavailable)))
```

## Mülakatta sorulabilecekler

1. **`setUp`, `setUpWithError` ve `setUp() async throws` arasındaki fark ve çağrılma sırası nedir?**
   Üçü de her testten önce çağrılır; sıra `setUp() async throws` → `setUpWithError()` → `setUp()`. Yıkım tersidir: teardown blokları (LIFO) → `tearDown()` → `tearDownWithError()` → `tearDown() async throws`. `async` sürüm kurulumda `await` gerektiğinde, `WithError` sürümü kurulum fırlatabildiğinde kullanılır. XCTest her test metodu için sınıftan yeni bir örnek oluşturur; `class func setUp()` ise sınıf başına bir kez çalışır.

2. **XCTest'te async kodu nasıl test edersin?**
   Test metodunu `async throws` yapıp doğrudan `await` ederim. Callback tabanlı API'ler için `XCTestExpectation` + `await fulfillment(of:timeout:)` kullanırım; async bağlamda `wait(for:)` Swift 6'da derleme hatasıdır. Arka planda başlayan işi sabit `sleep` ile değil, task'ın kendisini `await` ederek veya zaman sınırlı bir koşul yoklamasıyla beklerim. Fırlatan async kod için `XCTAssertThrowsError` async ifade almadığından `do/catch` + `XCTFail` kullanırım.

3. **Stub, spy, mock ve fake arasındaki fark nedir?**
   Stub hazır cevap döndürür. Spy çağrıları kaydeder, doğrulamayı test yapar. Mock beklentileri önceden bilir ve kendisi doğrular. Fake çalışan ama basitleştirilmiş bir uygulamadır (bellek içi veritabanı, paketteki JSON'dan okuyan servis). Dummy yalnızca imzayı doldurur. Hepsi, kodun somut tipe değil bir protocol'e bağımlı olmasıyla mümkün olur.

4. **`@testable import` ne yapar? Sınırları nelerdir?**
   Modülü, `internal` üyeleri de görünecek şekilde içe aktarır; `private`/`fileprivate` görünmez. Modülün `ENABLE_TESTABILITY = YES` ile derlenmiş olmasını ister (Debug'da açık, Release'te kapalı). UI testlerinde kullanılamaz, çünkü UI testi uygulamadan ayrı bir süreçte çalışır ve ona bağlanmaz.

5. **Swift 6'da `@MainActor` bir view model'i nasıl test edersin? Neden test sınıfını `@MainActor` yapmıyorsun?**
   View model'e dokunan test metodunu `@MainActor` işaretlerim; metot `async` olabilir. Sınıfı işaretlersem `XCTestCase`'in senkron `setUp`/`tearDown` override'ları nonisolated kalır ve içlerinde ana actor durumuna dokunmak uyarı verir. Bonus: `@MainActor` testte açılan `Task`'lar ana actor'ü miras alır; test `await` etmedikçe çalışamazlar, bu da eşzamanlılık senaryolarını deterministik yapar.

6. **Paylaşılan durum veya data race içeren kodu nasıl test edersin?**
   Durumu bir actor'e (ya da kilide) koyar, çok sayıda eşzamanlı çağrıyla (`withTaskGroup`) sonucun tam olduğunu doğrularım. Yarışlı kodda sonucun tam değerini değil değişmezini (ör. `≤ N`) doğrularım; aksi halde test ara sıra kırılır. Data race'leri çalışma anında bulmak için Thread Sanitizer kullanırım; bilerek yarışlı kod içeren testler varsa TSan'ı o koşuda kapalı tutarım.

7. **Kod kapsamı neyi söyler, neyi söylemez?**
   Testler sırasında hangi satırların çalıştığını söyler; test edilmemiş kod yollarını bulmaya yarar. Doğrulamaların doğru olduğunu söylemez: hiç `XCTAssert` içermeyen bir test de kapsamı artırır. Hedef yüzde bir araçtır; kritik mantığın (view model, servis) yüksek, SwiftUI `body`'lerinin düşük olması normaldir.

8. **XCTest ile Swift Testing arasındaki temel farklar nelerdir?**
   Swift Testing `@Test` makrosunu herhangi bir fonksiyona uygular, `#expect`/`#require` ile doğrular (içinde `await` yazılabilir), suite'leri genelde `struct` ve her test için yeni örnek, testleri varsayılan olarak paralel koşar, `@Test(arguments:)` ile parametreli test ve trait'ler (`.disabled`, `.tags`, `.timeLimit`) sunar. XCTest ise UI testleri (`XCUIApplication`) ve performans ölçümleri için hâlâ gereklidir. İkisi aynı hedefte birlikte çalışabilir.

## Alıştırmalar

1. **Kapsam raporundaki boşluğu kapat.** `BookListViewModel.refresh()` içindeki `guard !isRefreshing else { return }` kolu şu an hiçbir testte çalışmıyor. Bir yenileme sürerken ikinci bir yenileme başlatıldığında servisin yalnızca bir kez daha çağrıldığını doğrulayan bir test yaz ([BookListViewModelTests.swift](../BookShelfTests/BookList/BookListViewModelTests.swift)).
   *İpucu:* Test metodunu `@MainActor` işaretle. `StubBookService(delay: .milliseconds(100))` ile önce `await viewModel.load()` yap. Birinci yenilemeyi `let first = Task { await viewModel.refresh() }` ile başlat ve başladığını `bookListWaitUntil { viewModel.isRefreshing }` ile bekle. Sonra ikincisini doğrudan `await viewModel.refresh()` ile çağır: hemen dönmeli. En sonda `await first.value`. Beklenen `fetchBooksCallCount` 2'dir (1 yükleme + 1 yenileme). Sonucu `./scripts/ci.sh build && ./scripts/ci.sh unit`, sonra `xcrun xccov view --report build/results/unit.xcresult | grep refresh` ile kontrol et.

2. **Bir mock yaz ve spy ile karşılaştır.** `BookDetailViewModel.load()`'un yorumları **doğru kitap id'siyle** ve yazar profilini **kitabın yazar adıyla** istediğini doğrulayan bir test yaz. Önce Kavramlar 8'deki gibi `verify()` metodu olan bir mock actor ile, sonra aynı testi "argümanları kaydeden, doğrulamayı teste bırakan" bir spy ile yaz. Hangisi daha okunaklı, hangisi refactor'a daha dayanıklı?
   *İpucu:* `StubBookService` değiştirilmemeli (paylaşılan sözleşme); yeni double'ı test dosyasında `private actor` olarak tanımla ve adına özellik öneki ver (`BookDetail...`). `BookServiceProtocol`'ün üç metodunu da uygulaman gerekir. Actor'ün kaydettiği diziyi okumak için `await` gerekecek.

3. **Bir test sınıfını Swift Testing'e taşı.** [FavoritesStateTests.swift](../BookShelfTests/Favorites/FavoritesStateTests.swift)'i yeni bir dosyada Swift Testing ile yeniden yaz (XCTest sürümünü silme; ikisi yan yana çalışsın). `testFromCatalogKeepsCatalogOrderRegardlessOfSetOrder` gibi benzer testleri tek bir `@Test(arguments:)` ile birleştir.
   *İpucu:* `import Testing` + `@testable import BookShelf`; `@Suite struct FavoritesStateSwiftTestingTests`. `XCTAssertEqual(a, b)` → `#expect(a == b)`, `XCTAssertTrue(x)` → `#expect(x)`. Tüm testler tek modülde derlendiği için tip adı benzersiz olmalı. Parametre olarak `(favoriteIDs, expectedIDs)` çiftlerinden oluşan bir dizi verebilirsin; tuple'lar `Sendable` olduğu sürece sorun olmaz. `./scripts/ci.sh unit` çıktısında Swift Testing sonuçlarının da göründüğünü kontrol et.
