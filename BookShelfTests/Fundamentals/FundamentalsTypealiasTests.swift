import UIKit
import XCTest
@testable import BookShelf

/// typealias örnekleri. Asıl ders: typealias yeni bir tip OLUŞTURMAZ; sarmalayıcı struct ise oluşturur.
///
/// "Derlenmez" kısmı (ör. `cardLabel(for: 42)`) bir testle doğrulanamaz: Derlenmeyen kod test dosyasını da
/// derletmez. Onu yorum satırında bırakıp, aynı gerçeği çalışma anında görülebilen yönüyle (tip eşitliği,
/// dinamik dönüşüm) doğruluyoruz.
final class FundamentalsTypealiasTests: XCTestCase {
    private typealias Examples = TypealiasExamples

    // MARK: - Alias = aynı tip

    func testAliasIsExactlyItsUnderlyingType() {
        XCTAssertTrue(Examples.BookID.self == Int.self)
        XCTAssertTrue(Examples.BookID.self == Examples.MemberID.self)
        XCTAssertEqual(Examples.typeName(of: Examples.BookID.self), "Int", "Çalışma anında alias'ın adı bile yok")
    }

    func testAliasesAreInterchangeableWithoutConversion() {
        let member: Examples.MemberID = 42
        let book: Examples.BookID = member        // Derlenir: ikisi de Int. İşte tuzak.
        let plain: Int = book

        XCTAssertEqual(plain, 42)
        XCTAssertEqual(Examples.bookID(mistakenlyFrom: member), 42)
    }

    // MARK: - Sarmalayıcı = ayrı tip

    func testWrapperIsADistinctTypeOfTheSameSize() {
        XCTAssertFalse(Examples.LibraryCardNumber.self == Int.self)
        XCTAssertEqual(MemoryLayout<Examples.LibraryCardNumber>.size, MemoryLayout<Int>.size, "Tek alanlı struct: ek maliyet yok")

        // Examples.cardLabel(for: 42)
        // ↑ derlenmez: "cannot convert value of type 'Int' to expected argument type 'LibraryCardNumber'"
        XCTAssertEqual(Examples.cardLabel(for: Examples.LibraryCardNumber(rawValue: 42)), "Kart #42")
    }

    func testDynamicCastShowsTheDifferenceAtRuntime() {
        let boxed: Any = 42
        XCTAssertEqual(boxed as? Examples.BookID, 42, "Bir Int, BookID'dir (aynı tip)")
        XCTAssertNil(boxed as? Examples.LibraryCardNumber, "Ama LibraryCardNumber değildir (ayrı tip)")
    }

    // MARK: - Kullanım yerleri

    func testClosureAliasFiltersBooks() throws {
        let filters = Dictionary(uniqueKeysWithValues: Examples.filters.map { ($0.id, $0.matches) })
        let books = Examples.sampleBooks

        XCTAssertEqual(Examples.titles(of: books, matching: try XCTUnwrap(filters["Tümü"])).count, books.count)
        XCTAssertEqual(
            Examples.titles(of: books, matching: try XCTUnwrap(filters["< 200 sayfa"])),
            ["Kürk Mantolu Madonna", "Aylak Adam"]
        )
        XCTAssertEqual(
            Examples.titles(of: books, matching: try XCTUnwrap(filters["1950 öncesi"])),
            ["Kürk Mantolu Madonna", "Çalıkuşu"]
        )
    }

    func testProtocolCompositionAliasWorksAsAGenericConstraint() {
        XCTAssertEqual(Examples.identifiers(of: ReadingSamples.shelfNovels), [101, 102, 103])
    }

    func testGenericAliasIsAPlainDictionary() {
        let pageCounts: Examples.BookMap<Int> = Examples.pageCounts(of: Examples.sampleBooks)
        let dictionary: [Int: Int] = pageCounts   // Dönüşüm yok: aynı tip.

        XCTAssertEqual(dictionary[2], 160)
        XCTAssertEqual(Examples.typeName(of: Examples.BookMap<String>.self), "Dictionary<Int, String>")
    }

    func testTypealiasSatisfiesTheAssociatedType() {
        XCTAssertTrue(Examples.ClassicsShelf.Item.self == Novel.self)

        var shelf = Examples.ClassicsShelf()
        XCTAssertTrue(shelf.add(ReadingSamples.shelfNovels[0]))
        XCTAssertFalse(shelf.add(ReadingSamples.shelfNovels[0]), "Aynı roman ikinci kez eklenmez")
        XCTAssertEqual(shelf.totalMinutes, 288, "Shelf extension'ındaki varsayılan da çalışıyor")
    }

    func testFavoritesSnapshotAliasIsTheDiffableSnapshotType() {
        XCTAssertTrue(
            FavoritesViewController.Snapshot.self
                == NSDiffableDataSourceSnapshot<FavoritesViewController.Section, Book>.self
        )
        XCTAssertTrue(Examples.typeName(of: FavoritesViewController.Snapshot.self).hasPrefix("NSDiffableDataSourceSnapshot<"))
    }
}
