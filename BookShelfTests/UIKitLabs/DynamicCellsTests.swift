import UIKit
import XCTest
@testable import BookShelf

/// Self-sizing hücreler: Yükseklik gerçekten içerikten mi hesaplanıyor, aç/kapa doğru çalışıyor mu?
///
/// Hücre yüksekliğini tablo olmadan ölçüyoruz: `contentView.systemLayoutSizeFitting(...)` Auto Layout'a
/// "genişlik şu kadarken en küçük yükseklik ne?" diye sorar. Tablonun self-sizing sırasında yaptığı da budur.
final class DynamicCellsTests: XCTestCase {
    private typealias ID = AccessibilityID.UIKitLabs.DynamicCells

    private static let shortSummary = "Kısa özet."
    private static let longSummary = String(
        repeating: "Uzun bir özet cümlesi; hücre bu metni sığdırmak için birkaç satıra yayılmalı. ",
        count: 6
    )

    // MARK: - Satır modeli

    @MainActor
    func testRowsGroupBooksByAuthorInFirstAppearanceOrder() {
        // Book.fixtures: 1 → Yazar A, 2 → Yazar B, 3 → Yazar A
        let rows = DynamicCellsViewController.makeRows(from: Book.fixtures)

        XCTAssertEqual(rows, [
            .author(name: "Yazar A", bookCount: 2, index: 0),
            .book(Book.fixtures[0]),
            .book(Book.fixtures[2]),
            .author(name: "Yazar B", bookCount: 1, index: 1),
            .book(Book.fixtures[1]),
        ])
    }

    // MARK: - Hücre ölçümü

    @MainActor
    func testLongSummaryCellIsTallerThanShortSummaryCell() {
        let shortCell = makeCell(summary: Self.shortSummary, expanded: true)
        let longCell = makeCell(summary: Self.longSummary, expanded: true)

        XCTAssertGreaterThan(fittingHeight(of: longCell), fittingHeight(of: shortCell) + 40)
    }

    @MainActor
    func testExpandingShowsAllLinesAndDetailsAndGrowsHeight() {
        let cell = makeCell(summary: Self.longSummary, expanded: false)
        XCTAssertEqual(cell.summaryLabel.numberOfLines, BookSummaryCell.collapsedSummaryLineCount)
        XCTAssertTrue(cell.detailsLabel.isHidden)
        XCTAssertEqual(cell.accessibilityValue, ID.collapsedValue)
        let collapsedHeight = fittingHeight(of: cell)

        cell.setExpanded(true)

        XCTAssertEqual(cell.summaryLabel.numberOfLines, 0, "0 = satır sınırı yok")
        XCTAssertFalse(cell.detailsLabel.isHidden)
        XCTAssertEqual(cell.accessibilityValue, ID.expandedValue)
        XCTAssertGreaterThan(fittingHeight(of: cell), collapsedHeight)
    }

    @MainActor
    func testPrepareForReuseCollapsesTheCell() {
        let cell = makeCell(summary: Self.longSummary, expanded: true)

        cell.prepareForReuse()

        XCTAssertFalse(cell.isExpanded)
        XCTAssertEqual(cell.summaryLabel.numberOfLines, BookSummaryCell.collapsedSummaryLineCount)
    }

    // MARK: - Tablo (klasik data source)

    @MainActor
    func testTableIsConfiguredForSelfSizing() {
        let controller = makeController()

        XCTAssertEqual(controller.tableView.rowHeight, UITableView.automaticDimension)
        XCTAssertGreaterThan(controller.tableView.estimatedRowHeight, 0)
        XCTAssertTrue(controller.tableView.dataSource === controller)
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), controller.rows.count)
    }

    @MainActor
    func testDataSourceDequeuesTheRightCellTypeForEachRow() throws {
        let controller = makeController()

        let authorCell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        let bookCell = try XCTUnwrap(
            controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 1, section: 0)) as? BookSummaryCell
        )

        XCTAssertTrue(authorCell is AuthorHeaderCell)
        XCTAssertEqual(authorCell.reuseIdentifier, AuthorHeaderCell.reuseIdentifier)
        XCTAssertEqual(bookCell.reuseIdentifier, BookSummaryCell.reuseIdentifier)
        XCTAssertEqual(bookCell.titleLabel.text, "Birinci Kitap")
        XCTAssertEqual(bookCell.accessibilityIdentifier, ID.bookCell(1))
    }

    @MainActor
    func testSelectingBookRowTogglesExpansionStateKeptInController() throws {
        let controller = makeController()
        let bookRow = IndexPath(row: 1, section: 0)   // Birinci Kitap

        controller.tableView(controller.tableView, didSelectRowAt: bookRow)
        XCTAssertEqual(controller.expandedBookIDs, [1])
        // Yeniden yapılandırılan (ör. kaydırınca geri gelen) hücre de durumu VC'den almalı.
        let reconfigured = try XCTUnwrap(
            controller.tableView(controller.tableView, cellForRowAt: bookRow) as? BookSummaryCell
        )
        XCTAssertTrue(reconfigured.isExpanded)

        controller.tableView(controller.tableView, didSelectRowAt: bookRow)
        XCTAssertTrue(controller.expandedBookIDs.isEmpty)
    }

    @MainActor
    func testAuthorRowsAreNotSelectable() {
        let controller = makeController()

        XCTAssertNil(controller.tableView(controller.tableView, willSelectRowAt: IndexPath(row: 0, section: 0)))
        XCTAssertEqual(
            controller.tableView(controller.tableView, willSelectRowAt: IndexPath(row: 1, section: 0)),
            IndexPath(row: 1, section: 0)
        )
    }

    // MARK: - Yardımcılar (private)

    @MainActor
    private func makeController() -> DynamicCellsViewController {
        let controller = DynamicCellsViewController(books: Book.fixtures)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        controller.view.layoutIfNeeded()
        return controller
    }

    @MainActor
    private func makeCell(summary: String, expanded: Bool) -> BookSummaryCell {
        let cell = BookSummaryCell(style: .default, reuseIdentifier: BookSummaryCell.reuseIdentifier)
        cell.configure(with: .fixture(summary: summary), isExpanded: expanded)
        return cell
    }

    /// Verilen genişlikte hücrenin içeriğine göre alması gereken en küçük yükseklik.
    @MainActor
    private func fittingHeight(of cell: UITableViewCell, width: CGFloat = 375) -> CGFloat {
        cell.frame = CGRect(x: 0, y: 0, width: width, height: 44)
        cell.layoutIfNeeded()
        return cell.contentView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }
}
