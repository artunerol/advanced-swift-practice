import XCTest
@testable import BookShelf

/// Okuma hızı ayarı: UserDefaults'ta küçük bir tercih → kitap detayındaki tahmini okuma süresi.
///
/// View model UserDefaults'u bilmez; ekran değeri okuyup `pagesPerHour` olarak verir (dependency injection).
/// Bu yüzden iki ayrı şeyi ayrı ayrı test edebiliyoruz: (1) ayarın okunması, (2) view model'in verilen hızı kullanması.
final class ReadingSpeedSettingTests: XCTestCase {
    private var location: PersistenceLocation!

    override func setUp() {
        super.setUp()
        location = .isolated(name: "ReadingSpeed-\(UUID().uuidString)")
    }

    override func tearDown() {
        location.erase()
        location = nil
        super.tearDown()
    }

    func testMissingSettingFallsBackToDefault() {
        XCTAssertEqual(BookDetailViewModel.readingSpeed(in: location.defaults), ReadingPace.defaultPagesPerHour)
    }

    func testStoredSettingIsUsed() {
        location.defaults.set(55.0, forKey: BookDetailViewModel.readingSpeedKey)
        XCTAssertEqual(BookDetailViewModel.readingSpeed(in: location.defaults), 55)
    }

    /// Bozuk ya da anlamsız bir değer (0, negatif) hesaplamayı bozmamalı.
    func testInvalidStoredSettingFallsBackToDefault() {
        for invalid in [0.0, -10.0] {
            location.defaults.set(invalid, forKey: BookDetailViewModel.readingSpeedKey)
            XCTAssertEqual(BookDetailViewModel.readingSpeed(in: location.defaults), ReadingPace.defaultPagesPerHour)
        }
    }

    /// 724 sayfa ÷ saatte 45 sayfa = 16,09 saat ≈ 965 dakika = 16 sa 5 dk. (Varsayılan 40 ile 18 sa 6 dk olurdu.)
    @MainActor
    func testViewModelUsesInjectedReadingSpeed() {
        let viewModel = BookDetailViewModel(
            book: .fixture(pageCount: 724),
            service: StubBookService(),
            favorites: FavoritesStore(),
            pagesPerHour: 45
        )
        XCTAssertEqual(viewModel.readingTimeText, "16 sa 5 dk")
    }

    /// Parametre verilmezse eski davranış: saatte 40 sayfa.
    @MainActor
    func testViewModelDefaultsToFortyPagesPerHour() {
        let viewModel = BookDetailViewModel(book: .fixture(pageCount: 724), service: StubBookService(), favorites: FavoritesStore())
        XCTAssertEqual(viewModel.readingTimeText, "18 sa 6 dk")
    }
}
