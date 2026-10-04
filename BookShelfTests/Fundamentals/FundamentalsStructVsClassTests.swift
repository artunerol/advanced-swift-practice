import XCTest
@testable import BookShelf

/// Değer semantiği (struct) ile referans semantiği (class) arasındaki farkı ve copy-on-write'ı doğrular.
///
/// Test edilen tiplerin hiçbiri bir actor'e bağlı değil (nonisolated), bu yüzden testlerin `@MainActor`
/// ya da `async` olmasına gerek yok. Tamamen senkron ve deterministik.
final class FundamentalsStructVsClassTests: XCTestCase {

    // MARK: - Değer vs referans semantiği

    func testStructCopyIsIndependent() {
        let original = BookmarkValue(page: 10)
        var copy = original

        copy.advance(by: 10)

        XCTAssertEqual(original.page, 10, "Struct kopyasını değiştirmek orijinali etkilememeli")
        XCTAssertEqual(copy.page, 20)
        XCTAssertNotEqual(original, copy)
    }

    func testClassCopySharesTheSameInstance() {
        let original = BookmarkReference(page: 10)
        let copy = original

        copy.advance(by: 10)

        XCTAssertEqual(original.page, 20, "İki değişken aynı nesneyi gösterdiği için orijinal de değişmeli")
        XCTAssertTrue(original === copy)
    }

    func testEqualContentIsNotTheSameIdentity() {
        // İki ayrı class örneği: içerik aynı, kimlik farklı.
        let first = BookmarkReference(page: 5)
        let second = BookmarkReference(page: 5)
        XCTAssertEqual(first.page, second.page)
        XCTAssertFalse(first === second)

        // Struct'larda yalnızca içerik eşitliği vardır.
        XCTAssertEqual(BookmarkValue(page: 5), BookmarkValue(page: 5))
    }

    func testCopySemanticsDemoStartsEqualAndIdentical() {
        let demo = CopySemanticsDemo()

        XCTAssertEqual(demo.structOriginal.page, CopySemanticsDemo.startPage)
        XCTAssertEqual(demo.structCopy.page, CopySemanticsDemo.startPage)
        XCTAssertTrue(demo.structsAreEqual)
        XCTAssertTrue(demo.classesAreIdentical)
    }

    func testAdvancingCopiesChangesOnlyTheStructCopyButBothClassVariables() {
        var demo = CopySemanticsDemo(startPage: 10)

        demo.advanceCopies(by: 10)

        XCTAssertEqual(demo.structOriginal.page, 10)
        XCTAssertEqual(demo.structCopy.page, 20)
        XCTAssertFalse(demo.structsAreEqual)

        XCTAssertEqual(demo.classOriginal.page, 20)
        XCTAssertEqual(demo.classCopy.page, 20)
        XCTAssertTrue(demo.classesAreIdentical)
    }

    func testCopyingTheDemoStructStillSharesItsClassProperties() {
        // Class taşıyan bir struct'ın kopyası, class alanlarını PAYLAŞIR (struct'ın değer semantiği sığdır).
        let demo = CopySemanticsDemo(startPage: 1)
        var clone = demo

        clone.advanceCopies(by: 5)

        XCTAssertEqual(demo.structCopy.page, 1, "Struct alanı kopyalandı; orijinal demo etkilenmez")
        XCTAssertEqual(demo.classCopy.page, 6, "Class alanı paylaşılıyor; orijinal demo da etkilenir")
        XCTAssertTrue(demo.classOriginal === clone.classOriginal)
    }

    func testLetClassReferenceStillAllowsMutatingTheObject() {
        XCTAssertEqual(CopySemanticsDemo.pageAfterAdvancingThroughLet(startPage: 3, by: 4), 7)
    }

    // MARK: - Copy-on-write

    func testArrayHasValueSemantics() {
        let original = [1, 2, 3]
        var copy = original

        copy.append(4)

        XCTAssertEqual(original, [1, 2, 3])
        XCTAssertEqual(copy, [1, 2, 3, 4])
    }

    func testPageHistorySharesStorageUntilMutation() {
        var original = PageHistory(pages: [10])
        let copy = original
        XCTAssertTrue(original.sharesStorage(with: copy), "Kopyalamak depoyu kopyalamamalı")

        original.record(20)

        XCTAssertFalse(original.sharesStorage(with: copy), "Paylaşılan depo değiştirilmeden önce kopyalanmalı")
        XCTAssertEqual(original.pages, [10, 20])
        XCTAssertEqual(copy.pages, [10], "Kopya etkilenmemeli (değer semantiği)")
    }

    func testPageHistoryMutatesInPlaceWhenStorageIsUnique() {
        var history = PageHistory(pages: [1])
        let storageBefore = history.storageIdentifier

        history.record(2)

        XCTAssertEqual(history.storageIdentifier, storageBefore, "Depoyu tek başına tutan değer yerinde değişmeli")
        XCTAssertEqual(history.pages, [1, 2])
    }

    func testPageHistoryEqualityComparesContentNotStorage() {
        var first = PageHistory(pages: [1])
        first.record(2)
        let second = PageHistory(pages: [1, 2])

        XCTAssertFalse(first.sharesStorage(with: second))
        XCTAssertEqual(first, second)
    }

    func testCopyOnWriteDemo() {
        var demo = CopyOnWriteDemo()
        XCTAssertTrue(demo.sharesStorage)

        demo.recordNextPageOnCopy()

        XCTAssertFalse(demo.sharesStorage)
        XCTAssertEqual(demo.original.pages, [10])
        XCTAssertEqual(demo.copy.pages, [10, 20])
    }
}
