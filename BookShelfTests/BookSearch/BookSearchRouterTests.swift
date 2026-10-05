import SwiftUI
import UIKit
import XCTest
@testable import BookShelf

/// **Router testleri:** `build(...)` parçaları doğru bağlıyor mu, modül bellekten tamamen çıkabiliyor mu ve navigasyon
/// gerçekten bir push mu? Pencere (window) gerekmez: navigasyon yığını, ekranda olmasa da `viewControllers`'ı günceller.
final class BookSearchRouterTests: XCTestCase {

    private struct Module {
        let viewController: BookSearchViewController
        let presenter: BookSearchPresenter
        let interactor: BookSearchInteractor
        let router: BookSearchRouter
    }

    @MainActor
    private func buildModule(file: StaticString = #filePath, line: UInt = #line) throws -> Module {
        let built = BookSearchRouter.build(
            dependencies: AppDependencies(bookService: StubBookService()),
            recentSearchesStore: InMemoryRecentSearchesStore(),
            configuration: BookSearchConfiguration(debounce: .zero)
        )
        let viewController = try XCTUnwrap(built as? BookSearchViewController, file: file, line: line)
        let presenter = try XCTUnwrap(viewController.presenter as? BookSearchPresenter, file: file, line: line)
        let interactor = try XCTUnwrap(presenter.interactor as? BookSearchInteractor, file: file, line: line)
        let router = try XCTUnwrap(presenter.router as? BookSearchRouter, file: file, line: line)
        return Module(viewController: viewController, presenter: presenter, interactor: interactor, router: router)
    }

    // MARK: - Bağlama (wiring)

    @MainActor
    func testBuildWiresWeakBackReferencesToTheRightObjects() throws {
        let module = try buildModule()

        // Property injection ile atanan geri referanslar doğru nesneleri gösteriyor mu? (`===`: aynı nesne mi?)
        XCTAssertTrue(module.presenter.view === module.viewController)
        XCTAssertTrue(module.interactor.output === module.presenter)
        XCTAssertTrue(module.router.viewController === module.viewController)
    }

    // MARK: - Bellek: retain cycle yok

    /// Modülün tek dış sahibi VC. VC bırakılınca presenter, interactor ve router da serbest kalmalı.
    @MainActor
    func testReleasingViewControllerReleasesWholeModule() throws {
        weak var weakViewController: BookSearchViewController?
        weak var weakPresenter: BookSearchPresenter?
        weak var weakInteractor: BookSearchInteractor?
        weak var weakRouter: BookSearchRouter?

        try autoreleasepool {
            let module = try buildModule()
            weakViewController = module.viewController
            weakPresenter = module.presenter
            weakInteractor = module.interactor
            weakRouter = module.router
            // View'ı yükle: arama kutusu delegate'i, düğme closure'ları, data source ve `presenter.viewDidLoad()`
            // (o da interactor'da bir Task açar) devreye girsin.
            module.viewController.loadViewIfNeeded()
            module.presenter.didChangeSearchText("atay") // uçuşta bir arama Task'ı da olsun
            XCTAssertNotNil(module.interactor.searchTask)
        }

        XCTAssertNil(weakViewController, "VC serbest kalmalı")
        XCTAssertNil(weakPresenter, "Presenter serbest kalmalı (VC → presenter tek strong yol)")
        XCTAssertNil(weakInteractor, "Interactor serbest kalmalı (output weak, Task'lar [weak self])")
        XCTAssertNil(weakRouter, "Router serbest kalmalı (viewController weak)")
    }

    // MARK: - Navigasyon

    /// Gerçek navigasyon: `UIHostingController(BookDetailView)` yığına push edilir.
    @MainActor
    func testShowBookDetailPushesHostedSwiftUIDetail() throws {
        let module = try buildModule()
        let navigationController = UINavigationController(rootViewController: module.viewController)
        let book = Book.fixture(id: 4, title: "İnce Memed")

        module.router.showBookDetail(book)

        XCTAssertEqual(navigationController.viewControllers.count, 2)
        let detail = try XCTUnwrap(navigationController.topViewController as? UIHostingController<BookDetailView>)
        XCTAssertEqual(detail.title, "İnce Memed")
    }

    /// VC bir yığında değilse (ya da modül kapanmışsa) push sessizce atlanır; çökme yok.
    @MainActor
    func testShowBookDetailWithoutNavigationControllerDoesNothing() throws {
        let module = try buildModule()
        module.router.showBookDetail(.fixture())
        XCTAssertNil(module.viewController.navigationController)

        let orphan = BookSearchRouter(dependencies: AppDependencies(bookService: StubBookService()))
        orphan.showBookDetail(.fixture())
        orphan.showInsights(BookInsightsSummary(title: "x", lines: []))
        XCTAssertNil(orphan.viewController)
    }

    /// Navigasyon çubuğu gizli olduğu için detay, alt araç çubuğunda "Sonuçlara dön" taşır; dokununca pop eder.
    @MainActor
    func testDetailCarriesBackToResultsToolbarItemThatPops() throws {
        let module = try buildModule()
        let navigationController = UINavigationController(rootViewController: module.viewController)
        module.router.showBookDetail(.fixture())
        let detail = try XCTUnwrap(navigationController.topViewController)

        let back = try XCTUnwrap(detail.toolbarItems?.first)
        XCTAssertEqual(back.accessibilityIdentifier, AccessibilityID.BookSearch.backToResultsButton)
        XCTAssertEqual(back.title, "Sonuçlara dön")

        let action = try XCTUnwrap(back.primaryAction)
        action.performWithSender(nil, target: nil)

        XCTAssertTrue(navigationController.topViewController === module.viewController)
    }

    @MainActor
    func testInsightsAlertShowsSummaryWithSingleOKButton() {
        typealias ID = AccessibilityID.BookSearch
        let summary = BookInsightsSummary(title: "Huzur", lines: ["3 yorum · ortalama 4,0 / 5", "Yazar bilgisi"])

        let alert = BookSearchRouter.makeInsightsAlert(for: summary)

        XCTAssertEqual(alert.preferredStyle, .alert)
        XCTAssertEqual(alert.title, "Huzur")
        XCTAssertEqual(alert.message, "3 yorum · ortalama 4,0 / 5\nYazar bilgisi")
        XCTAssertEqual(alert.view.accessibilityIdentifier, ID.insightsAlert)
        XCTAssertEqual(alert.actions.map(\.accessibilityIdentifier), [ID.insightsOKButton])
    }
}
