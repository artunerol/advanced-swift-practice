import UIKit
import XCTest
@testable import BookShelf

/// VIPER View (view controller) testleri. Presenter sahte; VC'nin sadece "olayı ilet, durumu çiz" yaptığını doğrular.
/// Pencere (window) gerekmez: `loadViewIfNeeded()` `viewDidLoad`'u çalıştırır, `render` doğrudan çağrılır.
final class NotesListViewControllerTests: XCTestCase {
    private typealias Doubles = NotesArchitectureDoubles

    @MainActor
    private func makeSUT() -> (NotesListViewController, Doubles.PresenterSpy) {
        let presenter = Doubles.PresenterSpy()
        let viewController = NotesListViewController(presenter: presenter)
        viewController.loadViewIfNeeded()
        return (viewController, presenter)
    }

    private let rows = [
        NoteRow(id: UUID(), text: "Kısa not", detail: "a"),
        NoteRow(id: UUID(), text: "Çok satırlı\nbir not\nüç satır", detail: "b"),
    ]

    @MainActor
    func testViewDidLoadNotifiesPresenterOnceAndUsesSelfSizingRows() {
        let (viewController, presenter) = makeSUT()

        XCTAssertEqual(presenter.viewDidLoadCallCount, 1)
        XCTAssertEqual(viewController.tableView.rowHeight, UITableView.automaticDimension)
        XCTAssertGreaterThan(viewController.tableView.estimatedRowHeight, 0)
    }

    @MainActor
    func testRenderingNotesFillsTableAndHidesEmptyState() {
        let (viewController, _) = makeSUT()

        viewController.render(.notes(summary: "2 not · en yeni en üstte", rows: rows))

        XCTAssertEqual(viewController.tableView.numberOfRows(inSection: 0), 2)
        XCTAssertEqual(viewController.summaryLabel.text, "2 not · en yeni en üstte")
        XCTAssertNil(viewController.tableView.backgroundView)
        XCTAssertFalse(viewController.loadingIndicator.isAnimating)
    }

    @MainActor
    func testRenderingEmptyStateShowsMessageBehindTable() {
        let (viewController, _) = makeSUT()

        viewController.render(.empty(message: "Henüz not yok."))

        XCTAssertEqual(viewController.tableView.numberOfRows(inSection: 0), 0)
        XCTAssertTrue(viewController.tableView.backgroundView === viewController.emptyStateLabel)
        XCTAssertEqual(viewController.emptyStateLabel.text, "Henüz not yok.")
    }

    @MainActor
    func testMultilineRowAllowsUnlimitedLines() throws {
        let (viewController, _) = makeSUT()
        viewController.render(.notes(summary: "", rows: rows))

        let dataSource = try XCTUnwrap(viewController.tableView.dataSource)
        let cell = dataSource.tableView(viewController.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
        let content = try XCTUnwrap(cell.contentConfiguration as? UIListContentConfiguration)

        XCTAssertEqual(content.text, "Çok satırlı\nbir not\nüç satır")
        XCTAssertEqual(content.textProperties.numberOfLines, 0, "0 = sınırsız satır; hücre metin kadar uzar")
    }

    @MainActor
    func testAddButtonForwardsTapToPresenter() {
        let (viewController, presenter) = makeSUT()

        viewController.addButton.sendActions(for: .primaryActionTriggered)

        XCTAssertEqual(presenter.addTapCount, 1)
    }

    @MainActor
    func testSwipeDeleteForwardsNoteIDToPresenter() throws {
        let (viewController, presenter) = makeSUT()
        viewController.render(.notes(summary: "", rows: rows))

        let configuration = try XCTUnwrap(viewController.tableView(
            viewController.tableView,
            trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 1, section: 0)
        ))
        let action = try XCTUnwrap(configuration.actions.first)
        XCTAssertEqual(action.title, AccessibilityID.ReadingNotes.deleteActionTitle)
        XCTAssertEqual(action.style, .destructive)

        action.handler(action, UIView()) { _ in }

        // VC satırı kendisi silmez; sadece presenter'a iletir. Satır, yeni durum gelince kalkar.
        XCTAssertEqual(presenter.deleteRequests, [rows[1].id])
        XCTAssertEqual(viewController.tableView.numberOfRows(inSection: 0), 2)
    }
}
