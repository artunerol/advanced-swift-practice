import SwiftUI
import UIKit
import XCTest
@testable import BookShelf

/// `FavoritesViewController` testleri: yaşam döngüsü, actor → tablo veri akışı, iptal ve bellek yönetimi.
///
/// Ekranı bir pencereye (window) koymadan test ediyoruz:
/// - `loadViewIfNeeded()` → `viewDidLoad` çalışır.
/// - `beginAppearanceTransition` / `endAppearanceTransition` → `viewWillAppear`/`viewDidAppear`
///   (veya `viewWillDisappear`/`viewDidDisappear`) çağrılır. Bunlar UIKit'in container view controller'lar
///   için sunduğu genel (public) API'lerdir; testlerde "ekran göründü/kayboldu" durumunu taklit etmenin temiz yoludur.
///
/// Sınıf `@MainActor` DEĞİL (XCTestCase'in `setUp` gibi metotlarını ezmek zorlaşırdı); UIKit'e dokunan
/// her test metodu tek tek `@MainActor` ve `async` işaretli.
final class FavoritesViewControllerTests: XCTestCase {

    // MARK: - İlk kurulum

    @MainActor
    func testViewDidLoadConfiguresUIButDoesNotStartObserving() {
        let (viewController, _, _) = makeSUT(favoriteIDs: [1])

        XCTAssertEqual(viewController.title, "Favoriler")
        XCTAssertEqual(viewController.tableView.accessibilityIdentifier, AccessibilityID.Favorites.table)
        XCTAssertTrue(viewController.navigationItem.rightBarButtonItem === viewController.clearAllButton)
        XCTAssertEqual(viewController.clearAllButton.accessibilityIdentifier, AccessibilityID.Favorites.clearAllButton)
        // Görünmeden önce: yükleniyor durumu, ama dinleme HENÜZ başlamadı (viewWillAppear'da başlar).
        XCTAssertEqual(viewController.state, .loading)
        XCTAssertTrue(viewController.loadingIndicator.isAnimating)
        XCTAssertTrue(viewController.emptyStateLabel.isHidden)
        XCTAssertNil(viewController.observationTask)
    }

    // MARK: - Actor → tablo veri akışı

    @MainActor
    func testAppearingShowsFavoritesInCatalogOrder() async {
        let (viewController, _, service) = makeSUT(favoriteIDs: [3, 1])

        simulateAppearance(of: viewController)

        await waitUntil("favoriler tabloda katalog sırasıyla görünmeli") {
            viewController.displayedBookIDs == [1, 3]
        }
        XCTAssertEqual(viewController.tableView.numberOfRows(inSection: 0), 2)
        XCTAssertTrue(viewController.emptyStateLabel.isHidden)
        XCTAssertFalse(viewController.loadingIndicator.isAnimating)
        XCTAssertTrue(viewController.clearAllButton.isEnabled)
        let fetchCount = await service.fetchBooksCallCount
        XCTAssertEqual(fetchCount, 1)
    }

    @MainActor
    func testCellsCarryBookContentAndAccessibilityIdentifier() async throws {
        let (viewController, _, _) = makeSUT(favoriteIDs: [2])
        simulateAppearance(of: viewController)
        await waitUntil("kitap 2 görünmeli") { viewController.displayedBookIDs == [2] }

        // Hücreyi tablonun data source'una (diffable data source) doğrudan soruyoruz; pencere gerekmez.
        let tableDataSource = try XCTUnwrap(viewController.tableView.dataSource)
        let cell = tableDataSource.tableView(viewController.tableView, cellForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(cell.accessibilityIdentifier, AccessibilityID.Favorites.cell(bookID: 2))
        let content = try XCTUnwrap(cell.contentConfiguration as? UIListContentConfiguration)
        XCTAssertEqual(content.text, "İkinci Kitap")
        XCTAssertEqual(content.secondaryText, "Yazar B · 2000")
    }

    @MainActor
    func testEmptyStateIsVisibleWhenThereAreNoFavorites() async {
        let (viewController, _, _) = makeSUT(favoriteIDs: [])

        simulateAppearance(of: viewController)

        await waitUntil("boş liste durumu gelmeli") { viewController.state == .loaded([]) }
        XCTAssertFalse(viewController.emptyStateLabel.isHidden)
        XCTAssertTrue(viewController.errorLabel.isHidden)
        XCTAssertFalse(viewController.clearAllButton.isEnabled)
        XCTAssertEqual(viewController.tableView.numberOfRows(inSection: 0), 0)
    }

    @MainActor
    func testAddingFavoriteInStoreUpdatesTable() async {
        let (viewController, store, _) = makeSUT(favoriteIDs: [])
        simulateAppearance(of: viewController)
        await waitUntil("önce boş liste") { viewController.state == .loaded([]) }

        // Başka bir ekran (ör. SwiftUI detay ekranındaki kalp düğmesi) actor'ü değiştirmiş gibi.
        await store.add(2)

        await waitUntil("yeni favori tabloya gelmeli") { viewController.displayedBookIDs == [2] }
        XCTAssertTrue(viewController.emptyStateLabel.isHidden)
    }

    @MainActor
    func testRemovingFavoritesInStoreUpdatesTableUntilEmpty() async {
        let (viewController, store, _) = makeSUT(favoriteIDs: [1, 2])
        simulateAppearance(of: viewController)
        await waitUntil("iki favori") { viewController.displayedBookIDs == [1, 2] }

        await store.remove(1)
        await waitUntil("kitap 1 kalkmalı") { viewController.displayedBookIDs == [2] }

        await store.remove(2)
        await waitUntil("liste boşalmalı") { viewController.displayedBookIDs.isEmpty }
        XCTAssertFalse(viewController.emptyStateLabel.isHidden)
        XCTAssertFalse(viewController.clearAllButton.isEnabled)
    }

    @MainActor
    func testSwipeRemoveActionUpdatesStoreAndThenTable() async throws {
        let (viewController, store, _) = makeSUT(favoriteIDs: [1, 2])
        simulateAppearance(of: viewController)
        await waitUntil("iki favori") { viewController.displayedBookIDs == [1, 2] }

        let configuration = try XCTUnwrap(viewController.tableView(
            viewController.tableView,
            trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)
        ))
        let removeAction = try XCTUnwrap(configuration.actions.first)
        XCTAssertEqual(removeAction.title, AccessibilityID.Favorites.removeActionTitle)
        XCTAssertEqual(removeAction.style, .destructive)

        // Kullanıcının "Kaldır"a dokunmasını, UIKit'in yapacağı gibi handler'ı çağırarak taklit ediyoruz.
        let completionCalled = expectation(description: "UIKit'e eylemin tamamlandığı bildirilmeli")
        removeAction.handler(removeAction, UIView()) { performed in
            XCTAssertTrue(performed)
            completionCalled.fulfill()
        }
        await fulfillment(of: [completionCalled], timeout: 1)

        await waitUntil("satır, actor'ün yayınıyla kalkmalı") { viewController.displayedBookIDs == [2] }
        let remainingIDs = await store.allIDs
        XCTAssertEqual(remainingIDs, [2])
    }

    @MainActor
    func testClearAllRemovesEveryFavorite() async {
        let (viewController, store, _) = makeSUT(favoriteIDs: [1, 2, 3])
        simulateAppearance(of: viewController)
        await waitUntil("üç favori") { viewController.displayedBookIDs == [1, 2, 3] }

        await viewController.clearAllFavorites().value

        let remainingIDs = await store.allIDs
        XCTAssertTrue(remainingIDs.isEmpty)
        await waitUntil("tablo boşalmalı") { viewController.state == .loaded([]) }
        XCTAssertFalse(viewController.emptyStateLabel.isHidden)
        XCTAssertFalse(viewController.clearAllButton.isEnabled)
    }

    @MainActor
    func testClearAllConfirmationOffersCancelAndDestructiveConfirm() {
        let (viewController, _, _) = makeSUT()

        let alert = viewController.makeClearAllConfirmation()

        XCTAssertEqual(alert.preferredStyle, .alert)
        XCTAssertEqual(alert.view.accessibilityIdentifier, AccessibilityID.Favorites.clearAllAlert)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .destructive])
        XCTAssertEqual(
            alert.actions.map(\.accessibilityIdentifier),
            [AccessibilityID.Favorites.clearAllCancelButton, AccessibilityID.Favorites.clearAllConfirmButton]
        )
    }

    // MARK: - Hata durumu ve target-action

    @MainActor
    func testLoadFailureShowsErrorAndRetryButtonRecovers() async {
        let (viewController, _, service) = makeSUT(
            favoriteIDs: [1],
            books: .failure(.networkUnavailable)
        )
        simulateAppearance(of: viewController)

        await waitUntil("hata mesajı görünmeli") { !viewController.errorLabel.isHidden }
        XCTAssertEqual(viewController.errorLabel.text, BookServiceError.networkUnavailable.errorDescription)
        XCTAssertFalse(viewController.retryButton.isHidden)
        XCTAssertTrue(viewController.emptyStateLabel.isHidden)
        XCTAssertFalse(viewController.loadingIndicator.isAnimating)

        // Servis düzeldi; kullanıcı "Tekrar dene"ye dokunuyor. `sendActions(for:)` target-action zincirini
        // gerçek bir dokunuştaki gibi tetikler.
        await service.setBooksResult(.success(Book.fixtures))
        viewController.retryButton.sendActions(for: .touchUpInside)

        await waitUntil("tekrar denemeden sonra favoriler gelmeli") { viewController.displayedBookIDs == [1] }
        XCTAssertTrue(viewController.errorLabel.isHidden)
        XCTAssertTrue(viewController.retryButton.isHidden)
    }

    // MARK: - Yaşam döngüsü ve iptal

    @MainActor
    func testAppearingTwiceKeepsASingleObservationTask() async throws {
        let (viewController, _, service) = makeSUT(favoriteIDs: [1])
        simulateAppearance(of: viewController)
        await waitUntil("ilk yükleme") { viewController.displayedBookIDs == [1] }
        let firstTask = try XCTUnwrap(viewController.observationTask)

        // `viewWillAppear` kaybolmadan tekrar çağrılsa bile ikinci bir task açılmamalı.
        simulateAppearance(of: viewController)

        XCTAssertEqual(viewController.observationTask, firstTask)
        let fetchCount = await service.fetchBooksCallCount
        XCTAssertEqual(fetchCount, 1)
    }

    @MainActor
    func testDisappearingCancelsTaskSoLaterStoreChangesDoNotUpdateTable() async throws {
        let (viewController, store, _) = makeSUT(favoriteIDs: [1])
        simulateAppearance(of: viewController)
        await waitUntil("ilk yükleme") { viewController.displayedBookIDs == [1] }
        let task = try XCTUnwrap(viewController.observationTask)

        simulateDisappearance(of: viewController)

        XCTAssertNil(viewController.observationTask)
        XCTAssertTrue(task.isCancelled)
        // İptal işbirlikçidir: `cancel()` bir bayrak kaldırır. Task'ın `for await` döngüsünden gerçekten
        // çıktığını, bitmesini bekleyerek kanıtlıyoruz. İptale tepki vermeseydi bu bekleme zaman aşımına uğrardı.
        await waitForCompletion(of: task)

        await store.add(2)

        // Dinleyen tek task bitti; artık tabloyu güncelleyebilecek kimse yok. Yine de olası yanlış bir
        // güncellemeye fırsat tanımak için ana actor'ü kısa bir süre serbest bırakıyoruz.
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(viewController.displayedBookIDs, [1])
    }

    @MainActor
    func testReappearingShowsChangesMadeWhileHidden() async {
        let (viewController, store, _) = makeSUT(favoriteIDs: [1])
        simulateAppearance(of: viewController)
        await waitUntil("ilk yükleme") { viewController.displayedBookIDs == [1] }
        simulateDisappearance(of: viewController)

        // Ekran görünmezken (ör. kullanıcı Kitaplar sekmesinde) favori eklendi.
        await store.add(3)
        simulateAppearance(of: viewController)

        // Yeni abonelik, actor'ün güncel durumunu hemen yayınlar.
        await waitUntil("geri dönünce güncel liste") { viewController.displayedBookIDs == [1, 3] }
    }

    // MARK: - Navigasyon (UIKit içinde SwiftUI)

    @MainActor
    func testSelectingRowPushesHostingControllerWithBookDetail() async throws {
        let (viewController, _, _) = makeSUT(favoriteIDs: [1])
        let navigationController = UINavigationController(rootViewController: viewController)
        simulateAppearance(of: viewController)
        await waitUntil("ilk yükleme") { viewController.displayedBookIDs == [1] }

        viewController.tableView(viewController.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(navigationController.viewControllers.count, 2)
        let detail = try XCTUnwrap(navigationController.topViewController as? UIHostingController<BookDetailView>)
        XCTAssertEqual(detail.title, "Birinci Kitap")
    }

    // MARK: - Bellek yönetimi

    /// `[weak self]` doğru kullanılmazsa (ör. task `self`'i güçlü yakalarsa) VC hiç bellekten silinmez.
    /// Bu test, ekran dinleme yaparken son referansı bırakınca VC'nin serbest kaldığını ve `deinit`'in
    /// task'ı iptal ettiğini doğrular. (Bilerek `simulateDisappearance` çağırmıyoruz: `deinit` yolunu test ediyoruz.)
    @MainActor
    func testViewControllerIsReleasedWhileObservingAndDeinitCancelsTask() async throws {
        let dependencies = AppDependencies(
            bookService: StubBookService(),
            favorites: FavoritesStore(initialFavorites: [1])
        )
        weak var weakViewController: FavoritesViewController?
        var observationTask: Task<Void, Never>?

        do {
            let viewController = FavoritesViewController(dependencies: dependencies)
            weakViewController = viewController
            viewController.loadViewIfNeeded()
            simulateAppearance(of: viewController)
            await waitUntil("ilk yükleme") { viewController.displayedBookIDs == [1] }
            observationTask = viewController.observationTask
        } // ← Buradan sonra VC'ye güçlü referans kalmıyor.

        // UIKit bazı nesneleri autorelease havuzunda kısa süre tutabilir; havuz, ana döngünün (run loop)
        // bir sonraki turunda boşalır. Bu yüzden "hemen nil" yerine "kısa süre içinde nil" bekliyoruz.
        await waitUntil("VC bellekten silinmeli; silinmiyorsa bir retain cycle var") { weakViewController == nil }

        let task = try XCTUnwrap(observationTask)
        XCTAssertTrue(task.isCancelled, "deinit dinleyici task'ı iptal etmeli")
        await waitForCompletion(of: task)
    }

    // MARK: - Yardımcılar (private: diğer test dosyalarıyla isim çakışması olmasın)

    /// Test edilen sistemi (SUT = System Under Test) sıfır gecikmeli sahte servis ve taze bir actor ile kurar.
    @MainActor
    private func makeSUT(
        favoriteIDs: Set<Book.ID> = [],
        books: Result<[Book], BookServiceError> = .success(Book.fixtures)
    ) -> (viewController: FavoritesViewController, store: FavoritesStore, service: StubBookService) {
        let store = FavoritesStore(initialFavorites: favoriteIDs)
        let service = StubBookService(books: books)
        let viewController = FavoritesViewController(
            dependencies: AppDependencies(bookService: service, favorites: store)
        )
        viewController.loadViewIfNeeded()
        return (viewController, store, service)
    }

    @MainActor
    private func simulateAppearance(of viewController: UIViewController) {
        viewController.beginAppearanceTransition(true, animated: false)
        viewController.endAppearanceTransition()
    }

    @MainActor
    private func simulateDisappearance(of viewController: UIViewController) {
        viewController.beginAppearanceTransition(false, animated: false)
        viewController.endAppearanceTransition()
    }

    /// Koşul sağlanana kadar ana actor'ü kısa aralıklarla serbest bırakarak bekler (polling).
    ///
    /// Neden gerekli? Tablo, VC'nin içindeki yapısal olmayan bir task tarafından, actor'ün akışından değer
    /// geldikçe güncelleniyor. Testin bekleyebileceği bir callback yok. `Task.sleep` ile askıya aldığımızda
    /// ana actor boşalır ve VC'nin task'ı (o da ana actor'de) çalışma fırsatı bulur.
    /// Süre sınırı cömert (3 sn); normalde koşul birkaç milisaniyede sağlanır. Test hızını değil, sonsuza dek
    /// asılı kalmamayı garanti eder.
    @MainActor
    private func waitUntil(
        _ description: String,
        timeout: Duration = .seconds(3),
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Zaman aşımı: \(description)", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Bir task'ın bitmesini, zaman sınırıyla bekler. Doğrudan `await task.value` yazsaydık ve task hiç
    /// bitmeseydi test sonsuza dek asılı kalırdı; `XCTestExpectation` bize zaman aşımı verir.
    @MainActor
    private func waitForCompletion(of task: Task<Void, Never>) async {
        let finished = expectation(description: "task bitmeli")
        Task {
            await task.value
            finished.fulfill()
        }
        await fulfillment(of: [finished], timeout: 3)
    }
}
