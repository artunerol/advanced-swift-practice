import XCTest
@testable import BookShelf

/// `associatedtype`'lı `Shelf` protocol'ü ve generic `ReadingShelf` struct'ı.
final class FundamentalsShelfTests: XCTestCase {
    private let novels = ReadingSamples.shelfNovels

    func testAddAppendsNewItemsAndRejectsDuplicatesByID() {
        var shelf = ReadingShelf<Novel>()
        XCTAssertTrue(shelf.isEmpty)

        XCTAssertTrue(shelf.add(novels[0]))
        XCTAssertTrue(shelf.add(novels[1]))
        XCTAssertFalse(shelf.add(novels[0]), "Aynı id ikinci kez eklenmemeli")

        XCTAssertEqual(shelf.items.map(\.id), [101, 102])
    }

    func testInitializerAlsoDeduplicates() {
        let shelf = ReadingShelf(items: [novels[0], novels[0], novels[2]])
        XCTAssertEqual(shelf.items.map(\.id), [101, 103])
    }

    func testTotalMinutesUsesEveryItem() {
        let shelf = ReadingShelf(items: novels)
        // 192, 240 ve 420 sayfa → 288 + 360 + 630 dakika
        XCTAssertEqual(shelf.totalMinutes, 1278)
        XCTAssertEqual(ReadingShelf(items: Array(novels.prefix(2))).totalMinutes, 648)
    }

    func testSortedItemsAreAvailableWhenItemIsComparable() {
        let shelf = ReadingShelf(items: novels)   // Ekleme sırası: Aylak Adam, Yaban, Sinekli Bakkal
        XCTAssertEqual(shelf.sortedItems.map(\.title), ["Aylak Adam", "Sinekli Bakkal", "Yaban"])
        XCTAssertEqual(shelf.items.map(\.title), ["Aylak Adam", "Yaban", "Sinekli Bakkal"], "items ekleme sırasını korur")
    }

    func testShelfIsAValueType() {
        let original = ReadingShelf(items: [novels[0]])
        var copy = original

        copy.add(novels[1])

        XCTAssertEqual(original.items.count, 1)
        XCTAssertEqual(copy.items.count, 2)
    }

    func testShelfWorksWithCoreBookType() {
        var shelf = ReadingShelf<Book>()
        shelf.add(.fixture(id: 1, pageCount: 100))
        shelf.add(.fixture(id: 2, pageCount: 60))
        shelf.add(.fixture(id: 1, pageCount: 999))   // aynı id → reddedilir

        XCTAssertEqual(shelf.items.map(\.id), [1, 2])
        XCTAssertEqual(shelf.totalMinutes, 240)
    }

    func testConstrainedExistentialKnowsTheItemType() {
        // Primary associated type sayesinde `any Shelf<Novel>` yazılabiliyor ve `add(_:)` çağrılabiliyor.
        var shelf: any Shelf<Novel> = ReadingShelf<Novel>()
        shelf.add(novels[2])

        let items: [Novel] = shelf.items   // Tip `[Novel]`; `[any ReadingItem]`'a silinmedi.
        XCTAssertEqual(items.map(\.title), ["Sinekli Bakkal"])
    }

    func testGenericFunctionOverShelfProtocol() {
        XCTAssertEqual(Self.itemCount(in: ReadingShelf(items: novels)), 3)
        XCTAssertEqual(Self.itemCount(in: ReadingShelf<Book>(items: Book.fixtures)), 3)
    }

    /// `some Shelf`: Herhangi bir raf tipiyle çalışır; her çağrıda derleyici somut tipi bilir.
    private static func itemCount(in shelf: some Shelf) -> Int {
        shelf.items.count
    }
}
