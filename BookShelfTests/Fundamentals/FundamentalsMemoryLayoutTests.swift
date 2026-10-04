import XCTest
@testable import BookShelf

/// "Bellek" deneyi: `MemoryLayout` boyutları ve adres karşılaştırmaları.
///
/// Boyutlar bir "kelime" (word = `MemoryLayout<Int>.size`, 64-bit'te 8 bayt) cinsinden yazıldı: Testin söylediği şey
/// "existential 5 kelimedir" gibi platformdan bağımsız bir gerçek. Adreslerin kendisi her çalıştırmada değişir;
/// testler yalnızca "aynı mı, farklı mı?" sonucunu doğrular.
final class FundamentalsMemoryLayoutTests: XCTestCase {
    private let word = MemoryLayout<Int>.size

    // MARK: - MemoryLayout

    func testStructIsStoredInlineAsTheSumOfItsFields() {
        XCTAssertEqual(MemoryLayout<BookmarkValue>.size, word, "Tek Int'lik struct = 1 kelime; ek başlık (header) yok")

        // Int + Bool: 9 bayt veri, ama dizide bir sonraki eleman 8'in katında başlamalı (hizalama).
        XCTAssertEqual(MemoryLayout<BookmarkPosition>.size, word + 1)
        XCTAssertEqual(MemoryLayout<BookmarkPosition>.alignment, word)
        XCTAssertEqual(MemoryLayout<BookmarkPosition>.stride, 2 * word)
    }

    func testClassVariableHoldsOnlyAReference() {
        XCTAssertEqual(MemoryLayout<BookmarkReference>.size, word, "Değişkende yalnızca adres durur")
        XCTAssertEqual(MemoryLayout<BookmarkReference?>.size, word, "Optional referans da 1 kelime (nil = boş adres)")
    }

    func testArrayIsASingleReferenceToItsHeapStorage() {
        // Eleman tipi ne olursa olsun Array değişkeni 1 kelime: elemanlar heap'teki depoda.
        XCTAssertEqual(MemoryLayout<[Int]>.size, word)
        XCTAssertEqual(MemoryLayout<[BookmarkPosition]>.size, word)
    }

    func testExistentialContainerSizes() {
        // 3 kelimelik değer tamponu + tip bilgisi + 1 witness table. (Sendable marker protocol'dür, tablo eklemez.)
        XCTAssertEqual(MemoryLayout<any ReadingItem>.size, 5 * word)
        // Class'a bağlı protocol: referans + witness table.
        XCTAssertEqual(MemoryLayout<any PageTracking>.size, 2 * word)
        // Hiç protocol'ü olmayan existential: 3 kelimelik tampon + tip bilgisi.
        XCTAssertEqual(MemoryLayout<Any>.size, 4 * word)
    }

    func testDemoRowsShowTheRealMemoryLayout() {
        let rows = Dictionary(uniqueKeysWithValues: MemoryLayoutDemo.rows.map { ($0.id, $0) })

        XCTAssertEqual(rows.count, MemoryLayoutDemo.rows.count, "Satır kimlikleri benzersiz olmalı")
        XCTAssertEqual(rows["struct"]?.size, word)
        XCTAssertEqual(rows["padding"]?.stride, 2 * word)
        XCTAssertEqual(rows["class"]?.size, word)
        XCTAssertEqual(rows["array"]?.size, word)
        XCTAssertEqual(rows["existential"]?.size, 5 * word)
        XCTAssertEqual(rows["classExistential"]?.size, 2 * word)
    }

    // MARK: - Adresler

    func testStructCopiesLiveAtDifferentAddresses() {
        let comparison = MemoryAddressDemo.structCopies()
        XCTAssertFalse(comparison.isSameAddress, "var copy = original bağımsız bir değer üretir")
        XCTAssertNotEqual(comparison.first, 0)
    }

    func testTwoReferencesToOneObjectShareTheAddress() {
        XCTAssertTrue(MemoryAddressDemo.sharedReference().isSameAddress)
    }

    func testSeparateObjectsWithEqualContentHaveDifferentAddresses() {
        XCTAssertFalse(MemoryAddressDemo.separateObjects().isSameAddress)
    }

    func testObjectAddressIsWhatObjectIdentifierWraps() {
        let bookmark = BookmarkReference(page: 1)
        let alias = bookmark

        XCTAssertEqual(MemoryAddressDemo.address(of: bookmark), UInt(bitPattern: ObjectIdentifier(bookmark)))
        XCTAssertEqual(MemoryAddressDemo.address(of: bookmark), MemoryAddressDemo.address(of: alias))
        XCTAssertTrue(bookmark === alias)
    }

    func testReportAndHexFormatting() {
        let report = MemoryAddressReport.measure()
        XCTAssertFalse(report.structCopies.isSameAddress)
        XCTAssertTrue(report.sharedReference.isSameAddress)
        XCTAssertFalse(report.separateObjects.isSameAddress)

        XCTAssertEqual(AddressComparison.hex(255), "0xff")
    }
}
