import UIKit
import XCTest
@testable import BookShelf

/// Aynı veri, üç view: Sayılar tutuyor mu, yerleşimler doğru türde mi, mod değişince doğru view mı görünüyor?
final class TableVsCollectionTests: XCTestCase {
    private typealias ID = AccessibilityID.UIKitLabs.TableVsCollection
    private typealias GridItem = TableVsCollectionViewController.GridItem

    /// 6 kitap: öne çıkanlar sınırını (4) aşacak kadar.
    private static let sixBooks = (1...6).map { Book.fixture(id: $0, title: "Kitap \($0)") }

    @MainActor
    func testEveryViewShowsEveryBook() {
        let controller = makeController(books: Self.sixBooks)

        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 6)
        XCTAssertEqual(controller.listCollectionView.numberOfItems(inSection: 0), 6)
        XCTAssertEqual(controller.gridCollectionView.numberOfSections, 2)
        XCTAssertEqual(controller.gridCollectionView.numberOfItems(inSection: 0), TableVsCollectionViewController.featuredCount)
        XCTAssertEqual(controller.gridCollectionView.numberOfItems(inSection: 1), 6)
    }

    /// Aynı kitap iki bölümde, ama snapshot'taki kimlikler yine de benzersiz (bölüm kimliğin parçası).
    @MainActor
    func testGridItemIdentifiersStayUniqueWhenABookAppearsTwice() {
        let controller = makeController(books: Self.sixBooks)

        let identifiers = controller.gridDataSource.snapshot().itemIdentifiers

        XCTAssertEqual(identifiers.count, 10)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertTrue(identifiers.contains(GridItem(section: .featured, bookID: 1)))
        XCTAssertTrue(identifiers.contains(GridItem(section: .all, bookID: 1)))
    }

    @MainActor
    func testLayoutsAreCompositionalAndFeaturedSectionScrollsSideways() {
        let controller = makeController(books: Book.fixtures)

        XCTAssertTrue(controller.listCollectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
        XCTAssertTrue(controller.gridCollectionView.collectionViewLayout is UICollectionViewCompositionalLayout)
        XCTAssertEqual(TableVsCollectionLayouts.featuredSection().orthogonalScrollingBehavior, .groupPaging)
        XCTAssertEqual(TableVsCollectionLayouts.gridSection(columnCount: 2).orthogonalScrollingBehavior, .none)
    }

    @MainActor
    func testSelectingAModeShowsOnlyThatView() {
        let controller = makeController(books: Book.fixtures)
        XCTAssertEqual(controller.mode, .table)
        XCTAssertFalse(controller.tableView.isHidden)

        controller.select(.list)

        XCTAssertTrue(controller.tableView.isHidden)
        XCTAssertFalse(controller.listCollectionView.isHidden)
        XCTAssertTrue(controller.gridCollectionView.isHidden)
        XCTAssertEqual(controller.modeControl.selectedSegmentIndex, 1)
        XCTAssertEqual(controller.captionLabel.text, TableVsCollectionViewController.Mode.list.caption)
    }

    /// Kullanıcının segmented control'e dokunmasını `sendActions(for: .valueChanged)` ile taklit ediyoruz.
    @MainActor
    func testSegmentedControlSwitchesModes() {
        let controller = makeController(books: Book.fixtures)
        XCTAssertEqual(
            (0..<controller.modeControl.numberOfSegments).map { controller.modeControl.titleForSegment(at: $0) },
            [ID.tableSegment, ID.listSegment, ID.gridSegment]
        )

        controller.modeControl.selectedSegmentIndex = 2
        controller.modeControl.sendActions(for: .valueChanged)

        XCTAssertEqual(controller.mode, .grid)
        XCTAssertFalse(controller.gridCollectionView.isHidden)
    }

    @MainActor
    func testCellsCarryBookContentAndIdentifiers() throws {
        let controller = makeController(books: Book.fixtures)
        let firstItem = IndexPath(item: 0, section: 0)

        let tableDataSource = try XCTUnwrap(controller.tableView.dataSource)
        let tableCell = tableDataSource.tableView(controller.tableView, cellForRowAt: firstItem)
        let tableContent = try XCTUnwrap(tableCell.contentConfiguration as? UIListContentConfiguration)
        XCTAssertEqual(tableContent.text, "Birinci Kitap")
        XCTAssertEqual(tableCell.accessibilityIdentifier, ID.tableCell(1))

        let listDataSource = try XCTUnwrap(controller.listCollectionView.dataSource)
        let listCell = listDataSource.collectionView(controller.listCollectionView, cellForItemAt: firstItem)
        XCTAssertTrue(listCell is UICollectionViewListCell)
        XCTAssertEqual(listCell.accessibilityIdentifier, ID.listCell(1))

        let gridDataSource = try XCTUnwrap(controller.gridCollectionView.dataSource)
        let featuredCell = try XCTUnwrap(
            gridDataSource.collectionView(controller.gridCollectionView, cellForItemAt: firstItem) as? BookTileCell
        )
        XCTAssertEqual(featuredCell.titleLabel.text, "Birinci Kitap")
        XCTAssertEqual(featuredCell.accessibilityIdentifier, ID.featuredCell(1))
    }

    // MARK: - Yardımcılar (private)

    @MainActor
    private func makeController(books: [Book]) -> TableVsCollectionViewController {
        let controller = TableVsCollectionViewController(books: books)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        controller.view.layoutIfNeeded()
        return controller
    }
}
