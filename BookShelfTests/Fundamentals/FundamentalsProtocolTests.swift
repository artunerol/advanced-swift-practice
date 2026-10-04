import XCTest
@testable import BookShelf

/// `ReadingItem` protocol'ü: varsayılan uygulamalar, dispatch kuralları, generic ve existential toplamlar, sıralama.
final class FundamentalsProtocolTests: XCTestCase {

    // MARK: - Varsayılan uygulamalar

    func testTypesWithoutOverrideUseTheDefaultSymbol() {
        let novel = Novel(id: 1, title: "A", author: "B", pageCount: 10)
        XCTAssertEqual(novel.symbolName, "book.closed")
        XCTAssertEqual(Book.fixture().symbolName, "book.closed")
    }

    func testTypesCanOverrideARequirementWithADefault() {
        XCTAssertEqual(ProtocolDispatchDemo.magazine.symbolName, "newspaper")
        XCTAssertEqual(AudioBook(title: "A", narrator: "B", durationMinutes: 1).symbolName, "headphones")
    }

    func testPagedItemsGetEstimatedMinutesFromTheRefinedProtocol() {
        // Saatte 40 sayfa → sayfa başına 1,5 dk, aşağı yuvarlanır.
        XCTAssertEqual(Novel(id: 1, title: "A", author: "B", pageCount: 200).estimatedMinutes, 300)
        XCTAssertEqual(Novel(id: 1, title: "A", author: "B", pageCount: 3).estimatedMinutes, 4)
    }

    func testFormattedDuration() {
        XCTAssertEqual(formattedReadingDuration(minutes: 45), "45 dk")
        XCTAssertEqual(formattedReadingDuration(minutes: 120), "2 sa")
        XCTAssertEqual(formattedReadingDuration(minutes: 125), "2 sa 5 dk")
        XCTAssertEqual(formattedReadingDuration(minutes: 0), "0 dk")
        XCTAssertEqual(Magazine(title: "D", issueNumber: 1, articleCount: 6).formattedDuration, "48 dk")
    }

    // MARK: - Dispatch

    func testExtensionOnlyMemberIsStaticallyDispatched() {
        XCTAssertEqual(ProtocolDispatchDemo.viaConcreteType, "Süreli yayınlar")
        XCTAssertEqual(ProtocolDispatchDemo.viaExistential, "Genel raf", "any üzerinden extension'daki uygulama seçilir")
        XCTAssertEqual(ProtocolDispatchDemo.viaGeneric, "Genel raf", "Generic içinde de extension'daki uygulama seçilir")
    }

    func testRequirementIsDynamicallyDispatched() {
        XCTAssertEqual(ProtocolDispatchDemo.requirementViaExistential, "newspaper")

        let items: [any ReadingItem] = [AudioBook(title: "A", narrator: "B", durationMinutes: 1), Book.fixture()]
        XCTAssertEqual(items.map(\.symbolName), ["headphones", "book.closed"])
    }

    // MARK: - Generic vs existential

    func testGenericTotalOverHomogeneousArray() {
        let novels = [
            Novel(id: 1, title: "A", author: "X", pageCount: 100),   // 150 dk
            Novel(id: 2, title: "B", author: "X", pageCount: 20),    // 30 dk
        ]
        XCTAssertEqual(totalReadingMinutes(of: novels), 180)
        XCTAssertEqual(totalReadingMinutes(of: [Novel]()), 0)
    }

    func testExistentialTotalOverMixedArray() {
        // 288 (Aylak Adam) + 48 (dergi) + 840 (sesli kitap) + 240 (Kürk Mantolu Madonna)
        XCTAssertEqual(totalReadingMinutes(ofMixed: ReadingSamples.mixedItems), 1416)
        XCTAssertEqual(formattedReadingDuration(minutes: 1416), "23 sa 36 dk")
    }

    func testSomeParameterAcceptsAnExistentialThroughImplicitOpening() {
        let boxed: any ReadingItem = ProtocolDispatchDemo.magazine
        XCTAssertEqual(readingSummary(for: boxed), "Edebiyat Gündemi · Dergi · 48 dk")
    }

    func testOpaqueReturnTypeHidesButKeepsTheConcreteType() {
        let featured = ReadingSamples.featuredItem()
        // Çağıran yalnızca "bir ReadingItem" görür, ama çalışma anındaki tip gerçekten Novel.
        XCTAssertEqual(featured.title, "Aylak Adam")
        XCTAssertTrue(featured is Novel)
    }

    // MARK: - Sıralama

    func testSortByTitleUsesTurkishAlphabet() {
        let titles = ReadingSortOrder.title.sorted(ReadingSamples.mixedItems).map(\.title)
        XCTAssertEqual(titles, ["Aylak Adam", "Çalıkuşu", "Edebiyat Gündemi", "Kürk Mantolu Madonna"])
    }

    func testTurkishCollationPlacesDottedAndCedillaLettersCorrectly() {
        // Türk alfabesinde Ç ayrı bir harftir ve C'den SONRA gelir; I (noktasız) da İ'den (noktalı) önce gelir.
        // İngilizce kurallarda Ç ≈ C ve İ ≈ I sayılır, bu yüzden aşağıdaki iki çift ters sıralanırdı.
        XCTAssertEqual(TurkishCollation.compare("Cuma", "Çam"), .orderedAscending)
        XCTAssertEqual(TurkishCollation.compare("Irmak", "İnce"), .orderedAscending)
        // Yerel ayarsız `compare` Unicode kod noktalarına bakar ve Ç'yi (U+00C7) D'den sonraya koyardı.
        XCTAssertEqual(TurkishCollation.compare("Çınar", "Dut"), .orderedAscending)
    }

    func testSortByDurationIsAscendingWithTitleTieBreak() {
        let titles = ReadingSortOrder.duration.sorted(ReadingSamples.mixedItems).map(\.title)
        XCTAssertEqual(titles, ["Edebiyat Gündemi", "Kürk Mantolu Madonna", "Aylak Adam", "Çalıkuşu"])

        let tied: [any ReadingItem] = [
            Magazine(title: "B", issueNumber: 1, articleCount: 1),
            Magazine(title: "A", issueNumber: 2, articleCount: 1),
        ]
        XCTAssertEqual(ReadingSortOrder.duration.sorted(tied).map(\.title), ["A", "B"])
    }

    func testNovelComparableSortsByTitleThenAuthor() {
        let novels = [
            Novel(id: 1, title: "Yaban", author: "X", pageCount: 1),
            Novel(id: 2, title: "Aylak Adam", author: "Z", pageCount: 1),
            Novel(id: 3, title: "Aylak Adam", author: "Y", pageCount: 1),
        ]
        XCTAssertEqual(novels.sorted().map(\.id), [3, 2, 1])
        XCTAssertEqual(novels.min()?.id, 3)
    }

    // MARK: - Standart protocol'ler

    func testCustomStringConvertibleIsUsedByStringInterpolation() {
        let novel = Novel(id: 1, title: "Yaban", author: "Yakup Kadri Karaosmanoğlu", pageCount: 240)
        XCTAssertEqual("\(novel)", "Yaban (Yakup Kadri Karaosmanoğlu, 240 sayfa)")
    }

    func testClassEquatableIsAboutContentWhileIdentityIsSeparate() {
        let first = AudioBook(title: "Çalıkuşu", narrator: "N", durationMinutes: 840)
        let second = AudioBook(title: "Çalıkuşu", narrator: "N", durationMinutes: 840)

        XCTAssertEqual(first, second, "Elle yazılmış == içeriğe bakar")
        XCTAssertFalse(first === second, "Ama iki ayrı nesne")
    }

    // MARK: - Book (retroactive conformance)

    func testBookConformsToReadingItem() {
        let book = Book.fixture(title: "Kürk Mantolu Madonna", pageCount: 160)
        let item: any ReadingItem = book

        XCTAssertEqual(item.title, "Kürk Mantolu Madonna")
        XCTAssertEqual(item.kindName, "Kitap")
        XCTAssertEqual(item.estimatedMinutes, 240)
        XCTAssertEqual(item.formattedDuration, "4 sa")
        XCTAssertTrue(item is any PagedReadingItem)
    }
}
