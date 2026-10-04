import XCTest
@testable import BookShelf

/// "Protocol + extension" demosunun mantığı: dispatch bakış açıları, varsayılanlar ve koşullu extension'lar.
final class FundamentalsProtocolExtensionTests: XCTestCase {

    // MARK: - Dispatch

    func testRequirementGivesTheSameAnswerFromEveryViewpoint() {
        for viewpoint in DispatchViewpoint.allCases {
            XCTAssertEqual(ProtocolDispatchDemo.observe(from: viewpoint).requirement, "newspaper", "\(viewpoint)")
        }
    }

    func testExtensionOnlyMemberDependsOnTheCompileTimeType() {
        XCTAssertEqual(ProtocolDispatchDemo.observe(from: .concrete).extensionOnly, "Süreli yayınlar")
        XCTAssertEqual(ProtocolDispatchDemo.observe(from: .existential).extensionOnly, "Genel raf")
        XCTAssertEqual(ProtocolDispatchDemo.observe(from: .generic).extensionOnly, "Genel raf")
    }

    func testViewpointLabelsAndDeclarationsAreDistinct() {
        let viewpoints = DispatchViewpoint.allCases
        XCTAssertEqual(Set(viewpoints.map(\.label)).count, viewpoints.count)
        XCTAssertEqual(Set(viewpoints.map(\.declaration)).count, viewpoints.count)
    }

    // MARK: - Varsayılanlar

    func testConformanceSummariesShowDefaultsAndOverrides() throws {
        let summaries = Dictionary(uniqueKeysWithValues: ProtocolDefaultsDemo.summaries.map { ($0.id, $0) })
        XCTAssertEqual(ProtocolDefaultsDemo.summaries.map(\.id), ["Novel", "Magazine", "AudioBook", "Book"])

        // Varsayılanı kullananlar
        XCTAssertEqual(try XCTUnwrap(summaries["Novel"]).symbolName, "book.closed")
        XCTAssertEqual(try XCTUnwrap(summaries["Book"]).symbolName, "book.closed")
        // Gereksinimi özelleştirenler
        XCTAssertEqual(try XCTUnwrap(summaries["Magazine"]).symbolName, "newspaper")
        XCTAssertEqual(try XCTUnwrap(summaries["AudioBook"]).symbolName, "headphones")

        // estimatedMinutes: PagedReadingItem varsayılanı (sayfa × 1,5) ya da tipin kendi hesabı
        XCTAssertEqual(try XCTUnwrap(summaries["Novel"]).minutes, 288)      // 192 sayfa
        XCTAssertEqual(try XCTUnwrap(summaries["Book"]).minutes, 240)       // 160 sayfa, retroactive conformance
        XCTAssertEqual(try XCTUnwrap(summaries["Magazine"]).minutes, 48)    // 6 makale × 8
        XCTAssertEqual(try XCTUnwrap(summaries["AudioBook"]).minutes, 840)
    }

    // MARK: - Koşullu extension

    func testTotalPageCountExistsForPagedSequences() {
        XCTAssertEqual(ReadingSamples.shelfNovels.totalPageCount, 192 + 240 + 420)
        XCTAssertEqual(Book.fixtures.totalPageCount, 3 * 200, "Book da PagedReadingItem (retroactive)")
        XCTAssertEqual([Novel]().totalPageCount, 0)
        XCTAssertEqual(ConstrainedExtensionDemo.novelPages, 852)
        // [Magazine]().totalPageCount ve [any ReadingItem]().totalPageCount derlenmez: koşul sağlanmıyor.
    }

    func testSortedItemsComesFromTheComparableConstrainedExtension() {
        XCTAssertEqual(ConstrainedExtensionDemo.firstNovelOnSortedShelf, "Aylak Adam")
    }
}
