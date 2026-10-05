import UIKit
import XCTest
@testable import BookShelf

/// **View testleri (hafif):** Presenter sahte (spy); VC'nin yalnızca "olayı ilet, durumu çiz" yaptığını doğrular.
/// Pencere gerekmez: `loadViewIfNeeded()` `viewDidLoad`'u çalıştırır, `render` doğrudan çağrılır.
/// Asıl mantık presenter ve interactor'da ve onlar UIKit'siz test ediliyor; burada yalnızca görünürlük ve iletim.
final class BookSearchViewControllerTests: XCTestCase {
    private typealias Doubles = BookSearchArchitectureDoubles

    @MainActor
    private func makeSUT() -> (BookSearchViewController, Doubles.PresenterSpy) {
        let presenter = Doubles.PresenterSpy()
        let viewController = BookSearchViewController(presenter: presenter)
        viewController.loadViewIfNeeded()
        return (viewController, presenter)
    }

    private let rows = [
        BookSearchRow(id: 6, title: "Tehlikeli Oyunlar", detail: "Oğuz Atay · 1973"),
        BookSearchRow(id: 1, title: "Tutunamayanlar", detail: "Oğuz Atay · 1972"),
    ]

    // MARK: - Kurulum

    @MainActor
    func testViewDidLoadNotifiesPresenterOnceAndUsesSelfSizingRows() {
        let (viewController, presenter) = makeSUT()

        XCTAssertEqual(presenter.events, [.viewDidLoad])
        XCTAssertEqual(viewController.tableView.rowHeight, UITableView.automaticDimension)
        XCTAssertGreaterThan(viewController.tableView.estimatedRowHeight, 0)
    }

    // MARK: - render(state)

    @MainActor
    func testResultsFillTableAndHideStatusViews() throws {
        let (viewController, _) = makeSUT()

        viewController.render(.results(rows: rows))

        XCTAssertEqual(viewController.tableView.numberOfRows(inSection: 0), 2)
        XCTAssertTrue(viewController.messageLabel.isHidden)
        XCTAssertTrue(viewController.retryButton.isHidden)
        XCTAssertFalse(viewController.loadingIndicator.isAnimating)

        let dataSource = try XCTUnwrap(viewController.tableView.dataSource)
        let cell = dataSource.tableView(viewController.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
        let content = try XCTUnwrap(cell.contentConfiguration as? UIListContentConfiguration)
        XCTAssertEqual(content.text, "Tutunamayanlar")
        XCTAssertEqual(content.secondaryText, "Oğuz Atay · 1972")
        XCTAssertEqual(content.textProperties.numberOfLines, 0, "self-sizing: satır sınırı yok")
        XCTAssertEqual(cell.accessibilityIdentifier, AccessibilityID.BookSearch.resultCell(bookID: 1))
    }

    @MainActor
    func testIdleShowsRecentSearchesOrHintWhenThereAreNone() {
        let (viewController, _) = makeSUT()

        viewController.render(.idle(recentSearches: ["huzur", "atay"]))
        XCTAssertEqual(viewController.displayedItems, [.recent(index: 0, query: "huzur"), .recent(index: 1, query: "atay")])
        XCTAssertTrue(viewController.messageLabel.isHidden)

        viewController.render(.idle(recentSearches: []))
        XCTAssertEqual(viewController.displayedItems, [])
        XCTAssertEqual(viewController.messageLabel.text, BookSearchViewController.idleHint)
        XCTAssertFalse(viewController.messageLabel.isHidden)
    }

    @MainActor
    func testLoadingShowsSpinnerAndEmptiesTable() {
        let (viewController, _) = makeSUT()
        viewController.render(.results(rows: rows))

        viewController.render(.loading)

        XCTAssertTrue(viewController.loadingIndicator.isAnimating)
        XCTAssertEqual(viewController.displayedItems, [])
        XCTAssertTrue(viewController.messageLabel.isHidden)
    }

    @MainActor
    func testEmptyAndErrorStatesShowMessageAndRetryOnlyWhenAllowed() {
        let (viewController, _) = makeSUT()

        viewController.render(.empty(message: "Sonuç yok."))
        XCTAssertEqual(viewController.messageLabel.text, "Sonuç yok.")
        XCTAssertTrue(viewController.retryButton.isHidden)

        viewController.render(.error(message: "Bağlantı yok.", canRetry: true))
        XCTAssertEqual(viewController.messageLabel.text, "Bağlantı yok.")
        XCTAssertFalse(viewController.retryButton.isHidden)

        viewController.render(.error(message: "Veri bozuk.", canRetry: false))
        XCTAssertTrue(viewController.retryButton.isHidden, "Tekrar denemek işe yaramayacaksa düğme yok")
    }

    @MainActor
    func testStatusMessageIsShown() {
        let (viewController, _) = makeSUT()
        XCTAssertTrue(viewController.statusLabel.isHidden)

        viewController.showStatus("“Huzur” favorilere eklendi.")

        XCTAssertFalse(viewController.statusLabel.isHidden)
        XCTAssertEqual(viewController.statusLabel.text, "“Huzur” favorilere eklendi.")
    }

    // MARK: - Olaylar presenter'a iletiliyor mu?

    @MainActor
    func testSearchBarAndRetryForwardToPresenter() {
        let (viewController, presenter) = makeSUT()

        viewController.searchBar(viewController.searchBar, textDidChange: "ata")
        viewController.searchBar.text = "atay"
        viewController.searchBarSearchButtonClicked(viewController.searchBar)
        viewController.retryButton.sendActions(for: .primaryActionTriggered)

        XCTAssertEqual(presenter.events, [.viewDidLoad, .textChanged("ata"), .submitted("atay"), .retryTapped])
    }

    @MainActor
    func testSelectingRowsForwardsQueryOrBookID() {
        let (viewController, presenter) = makeSUT()

        viewController.render(.idle(recentSearches: ["huzur"]))
        viewController.tableView(viewController.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(viewController.searchBar.text, "huzur", "Geçmişten seçilen sorgu kutuya yazılır")

        viewController.render(.results(rows: rows))
        viewController.tableView(viewController.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))

        XCTAssertEqual(presenter.events, [.viewDidLoad, .recentSelected("huzur"), .bookSelected(1)])
    }

    /// Sola kaydırma: "Özet" ve "Favori". VC kitabın kimliğini iletir; ne yapılacağını bilmez.
    @MainActor
    func testSwipeActionsForwardBookIDToPresenter() throws {
        let (viewController, presenter) = makeSUT()
        viewController.render(.results(rows: rows))

        let configuration = try XCTUnwrap(viewController.tableView(
            viewController.tableView,
            trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)
        ))
        XCTAssertEqual(configuration.actions.map(\.title), [
            AccessibilityID.BookSearch.insightsActionTitle,
            AccessibilityID.BookSearch.favoriteActionTitle,
        ])
        // `UIView()` burada bir **dummy**: handler imzası bir view istiyor, kimse kullanmıyor.
        for action in configuration.actions {
            action.handler(action, UIView()) { _ in }
        }

        XCTAssertEqual(presenter.events, [.viewDidLoad, .insightsRequested(6), .favoriteToggleRequested(6)])
    }

    @MainActor
    func testRecentSearchRowsHaveNoSwipeActions() {
        let (viewController, _) = makeSUT()
        viewController.render(.idle(recentSearches: ["huzur"]))

        XCTAssertNil(viewController.tableView(
            viewController.tableView,
            trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)
        ))
    }
}
