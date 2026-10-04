import XCTest
import os
@testable import BookShelf

/// XCTest'in **yaşam döngüsünü** (lifecycle) canlı olarak gösteren ve DOĞRULAYAN test sınıfı.
/// Ayrıntılı anlatım: docs/09-xctest.md.
///
/// XCTest her test metodu için bu sınıftan **yeni bir örnek** (instance) oluşturur ve şu sırayla çağırır:
/// ```
/// setUp() async throws → setUpWithError() → setUp()
///     → test metodu
///     → addTeardownBlock blokları (son eklenen ilk çalışır, LIFO)
/// → tearDown() → tearDownWithError() → tearDown() async throws
/// ```
/// Bu sınıf her adımı bir günlüğe yazar; testler ve en son çalışan `tearDown() async throws` sıranın gerçekten
/// böyle olduğunu `XCTAssert` ile denetler. Yani belgedeki sıra, her CI çalıştırmasında yeniden kanıtlanır.
///
/// Gerçek projede üç `setUp` çeşidini birden yazmazsın; ihtiyacına uyan BİRİNİ seçersin:
/// - Kurulum `await` gerektiriyorsa (ör. bir actor'e veri yazmak) → `setUp() async throws`
/// - Kurulum hata fırlatabiliyorsa (ör. `XCTUnwrap`, `XCTSkipIf`) → `setUpWithError()`
/// - Basit, senkron kurulum → `setUp()`
///
/// Test adları burada *given-when-then* biçiminde: `test_given<Başlangıç>_when<Eylem>_then<Beklenen>`.
/// Projenin geri kalanı `testLoadFailureMovesToFailedState` gibi düz camelCase kullanıyor; ikisi de geçerli,
/// önemli olan bir ekip içinde tutarlı olmak. XCTest yalnızca adın `test` ile başlamasını ister.
final class XCTestLifecycleTests: XCTestCase {
    /// Kurulum ve yıkım (teardown) çağrılarının beklenen sırası.
    private static let expectedSetUpOrder = ["setUp() async throws", "setUpWithError()", "setUp()"]
    private static let expectedTearDownOrder = ["tearDown()", "tearDownWithError()", "tearDown() async throws"]

    /// Her test örneğinin kendi günlüğü. `let` + `Sendable` olduğu için `addTeardownBlock`'un `@Sendable`
    /// closure'ına da verilebilir. (`self`'i veremeyiz: `XCTestCase` `Sendable` değil.)
    private let log = XCTestLifecycleLog()

    /// Bir test teardown bloğu eklerse, blokların yazması gereken kayıtları buraya koyar;
    /// `tearDown() async throws` bunları kontrol eder.
    private var expectedTeardownBlockEvents: [String] = []

    /// Test edilen sistem (SUT = System Under Test). `setUp`'ta kurulur, `tearDown`'da bırakılır.
    ///
    /// `!` (implicitly unwrapped optional): Değer init'te değil `setUp`'ta atandığı için Optional olmak zorunda;
    /// ama her test `setUp`'tan SONRA çalıştığı için test gövdesinde `nil` olamaz. Alternatif, bu projedeki
    /// `FavoritesViewControllerTests.makeSUT()` gibi her testin kendi SUT'unu kuran bir fabrika metodudur.
    private var store: FavoritesStore!
    private var service: StubBookService!

    // MARK: - Kurulum (her testten ÖNCE)

    /// 1. çağrılan. `async` olduğu için actor'e `await` ile veri yazabiliriz.
    override func setUp() async throws {
        try await super.setUp()
        log.record("setUp() async throws")

        let store = FavoritesStore()
        await store.add(1) // actor metodu → `await`
        self.store = store
    }

    /// 2. çağrılan. `throws`: Kurulum hata fırlatırsa test çalıştırılmaz ve hata teste yazılır.
    override func setUpWithError() throws {
        try super.setUpWithError()
        log.record("setUpWithError()")

        service = StubBookService(books: .success(Book.fixtures))
    }

    /// 3. çağrılan. En eski ve en basit çeşit.
    override func setUp() {
        super.setUp()
        log.record("setUp()")
    }

    // MARK: - Yıkım (her testten SONRA)

    override func tearDown() {
        log.record("tearDown()")
        super.tearDown()
    }

    override func tearDownWithError() throws {
        log.record("tearDownWithError()")
        try super.tearDownWithError()
    }

    /// En son çağrılan metot: buraya kadar olan her şeyin sırasını doğrulayabiliriz.
    /// Buradaki `XCTAssert` başarısız olursa hata, o an çalışan testin sonucuna yazılır.
    override func tearDown() async throws {
        log.record("tearDown() async throws")

        let events = log.events
        XCTAssertEqual(Array(events.prefix(3)), Self.expectedSetUpOrder)
        let tail = Array(events.suffix(expectedTeardownBlockEvents.count + Self.expectedTearDownOrder.count))
        XCTAssertEqual(tail, expectedTeardownBlockEvents + Self.expectedTearDownOrder)

        // Test örnekleri test bitince hemen yok edilmeyebilir; XCTest onları çalıştırma sonuna kadar tutabilir.
        // Ağır nesneleri (büyük diziler, açık dosyalar) burada bırakmak bellek kullanımını düşük tutar.
        store = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - Testler

    /// Test gövdesi çalışmaya başladığında üç kurulum metodu da belgelenen sırayla bitmiş olmalı.
    func test_givenNewTestInstance_whenTestBodyStarts_thenAllSetUpMethodsRanInOrder() {
        XCTAssertEqual(log.events, Self.expectedSetUpOrder)
    }

    /// Bu test ve bir sonraki, aynı başlangıç durumunu (`[1]`) görür ve onu FARKLI yönlerde değiştirir.
    /// Hangisi önce çalışırsa çalışsın ikisi de geçer; çünkü her test taze bir örnek ve taze bir `store` alır.
    /// Testler arasında durum sızsaydı (ör. `store` bir `static` olsaydı) ikinciyi çalışan test kırılırdı.
    func test_givenFreshStore_whenRemovingSeededFavorite_thenStoreBecomesEmpty() async {
        let initial = await store.allIDs
        XCTAssertEqual(initial, [1], "Her test setUp'taki başlangıç durumunu görmeli")

        await store.remove(1)

        let final = await store.allIDs
        XCTAssertEqual(final, [])
    }

    func test_givenFreshStore_whenAddingFavorite_thenStoreHasBoth() async {
        let initial = await store.allIDs
        XCTAssertEqual(initial, [1], "Her test setUp'taki başlangıç durumunu görmeli")

        await store.add(2)

        let final = await store.allIDs
        XCTAssertEqual(final, [1, 2])
    }

    /// `setUpWithError`'da kurulan stub'ı kullanan async test. Stub aynı zamanda bir *spy*: çağrı sayısını tutar.
    func test_givenStubbedService_whenFetchingBooks_thenFixturesAreReturnedAndCallIsCounted() async throws {
        let books = try await service.fetchBooks()

        XCTAssertEqual(books, Book.fixtures)
        let callCount = await service.fetchBooksCallCount
        XCTAssertEqual(callCount, 1)
    }

    /// `addTeardownBlock`: Test gövdesinin İÇİNDEN "bu test bitince şunu da yap" demenin yolu.
    /// Bloklar test metodu döndükten sonra, `tearDown()`'dan ÖNCE ve eklenme sırasının TERSİNE (LIFO) çalışır.
    /// Tipik kullanım: testte açtığın bir kaynağı (geçici dosya, dinleyici, UserDefaults anahtarı)
    /// açtığın satırın hemen yanında temizlemeyi kaydetmek.
    func test_givenTwoTeardownBlocks_whenTestEnds_thenTheyRunInReverseOrderBeforeTearDown() {
        addTeardownBlock { [log] in log.record("teardown bloğu 1") }
        addTeardownBlock { [log] in log.record("teardown bloğu 2") }

        // Beklenti `tearDown() async throws` içinde doğrulanıyor (bloklar ancak test gövdesinden sonra çalışır).
        expectedTeardownBlockEvents = ["teardown bloğu 2", "teardown bloğu 1"]
    }

    /// Performans testi: `measure` bloğu varsayılan olarak 10 kez çalıştırır ve süreleri raporlar.
    ///
    /// Taban çizgisi (baseline) kaydedilmediği sürece `measure` testi başarısız ETMEZ; sadece ölçer.
    /// Xcode'da test sonucundaki süre rozetine tıklayıp "Set Baseline" dersen, sonraki çalıştırmalar bu
    /// değerden belirgin şekilde yavaşsa test kırılır. Baseline makineye özeldir; paylaşılan CI makinelerinde
    /// gürültülü olabilir. Ölçümü Instruments'ın yerine değil, "bu fonksiyon yavaşladı mı?" alarmı olarak düşün.
    func test_givenThousandISBNs_whenValidatingWithObjectiveC_thenPerformanceIsMeasured() {
        let isbns = Array(repeating: "978-605-000-001-6", count: 1_000)

        measure {
            for isbn in isbns {
                _ = ISBNValidator.isValidISBN13(isbn)
            }
        }
    }
}

/// Yaşam döngüsü günlüğü: thread-safe, `Sendable` bir dizi.
///
/// Neden kilit? Teardown blokları `@Sendable` closure'lardır; derleyici içlerine yalnızca `Sendable` değerlerin
/// yakalanmasına izin verir. Günlüğe ayrıca farklı thread'lerden yazılıyor: teardown blokları ana thread'de,
/// `async` test gövdesi ise (ana actor'e bağlı olmadığı için) global concurrent executor'de çalışır.
/// Çağrılar sırayla gelse de, derleyicinin denetleyebileceği bir güvenlik istiyoruz. `OSAllocatedUnfairLock`
/// durumu kilidin içinde saklar; derleyici sınıfın `Sendable` olduğunu kendisi doğrular (`@unchecked` gerekmez).
/// Aynı kalıp `ConcurrencyLab.LockedCounter`'da.
/// `private`: Tüm test dosyaları tek modülde derlenir; dosyaya özel tutmak ad çakışmasını önler.
private final class XCTestLifecycleLog: Sendable {
    private let storage = OSAllocatedUnfairLock<[String]>(initialState: [])

    func record(_ event: String) {
        storage.withLock { $0.append(event) }
    }

    var events: [String] {
        storage.withLock { $0 }
    }
}
