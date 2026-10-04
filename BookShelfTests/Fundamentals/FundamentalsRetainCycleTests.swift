import XCTest
@testable import BookShelf

/// ARC ve retain cycle deneyini doğrular.
///
/// Neler garanti, neler değil?
/// - `RetainCycleDemo.run` döndüğünde, döngü yoksa iki `deinit` de çalışmış olmak ZORUNDA: Yerel değişkenler
///   en geç fonksiyon dönerken bırakılır ve sayaç 0 olunca `deinit` hemen (senkron) çalışır.
/// - Üyenin kartından önce yok edilmesi de garanti: Üye yaşadığı sürece kartı güçlü tutar.
/// - Ama "tam olarak hangi satırda" yok edildikleri garanti değil (derleyici ömrü son kullanıma kadar kısaltabilir).
///   Bu yüzden testler olayların varlığını, sayılarını ve yukarıdaki iki göreli sırayı kontrol eder.
final class FundamentalsRetainCycleTests: XCTestCase {
    private let memberName = "LibraryMember(\(RetainCycleDemo.memberName))"
    private let cardName = "LibraryCard(#\(RetainCycleDemo.cardNumber))"

    func testBothObjectsAreCreatedAndLinkedInEveryScenario() {
        for strength in ReferenceStrength.allCases {
            let report = RetainCycleDemo.run(strength)

            XCTAssertEqual(report.createdObjects, [memberName, cardName], "\(strength)")
            XCTAssertTrue(report.events.contains(.linked(strength)), "\(strength)")
            XCTAssertEqual(report.events.last, .scopeEnded, "\(strength)")
        }
    }

    func testStrongReferencesInBothDirectionsLeak() {
        let report = RetainCycleDemo.run(.strong)

        XCTAssertTrue(report.deinitializedObjects.isEmpty, "Döngüde sayaç 0'a inmez, deinit çalışmaz")
        XCTAssertEqual(report.leakedObjectCount, 2)
        XCTAssertTrue(report.hasLeak)
    }

    func testWeakBackReferenceBreaksTheCycle() {
        assertNoLeak(RetainCycleDemo.run(.weak))
    }

    func testUnownedBackReferenceBreaksTheCycle() {
        assertNoLeak(RetainCycleDemo.run(.unowned))
    }

    func testWeakReferenceBecomesNilWhenTheObjectIsDeallocated() {
        let log = RetainCycleLog()
        let card = LibraryCard(number: 7, log: log)

        do {
            let member = LibraryMember(name: "Ali", log: log)
            member.card = card
            card.attach(to: member, strength: .weak)
            XCTAssertTrue(card.holder === member)
        }

        // `do` kapsamı bitti: Üyenin tek güçlü sahibi (yerel `member`) yok. `weak` referans otomatik nil oldu.
        XCTAssertNil(card.holder)
        XCTAssertTrue(log.events.contains(.deinitialized("LibraryMember(Ali)")))
        XCTAssertFalse(log.events.contains(.deinitialized(card.displayName)), "Kartı hâlâ test tutuyor")
    }

    func testEventDescriptionsAreReadableTurkish() {
        XCTAssertEqual(RetainCycleEvent.created("X").description, "X oluşturuldu")
        XCTAssertEqual(RetainCycleEvent.deinitialized("X").description, "deinit: X")
        XCTAssertEqual(
            RetainCycleEvent.linked(.weak).description,
            "Bağlandı: üye → kart (strong), kart → üye (weak)"
        )
    }

    // MARK: - Yardımcı

    private func assertNoLeak(_ report: RetainCycleReport, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(report.hasLeak, file: file, line: line)
        XCTAssertEqual(report.leakedObjectCount, 0, file: file, line: line)
        XCTAssertEqual(Set(report.deinitializedObjects), [memberName, cardName], file: file, line: line)

        guard
            let memberIndex = report.events.firstIndex(of: .deinitialized(memberName)),
            let cardIndex = report.events.firstIndex(of: .deinitialized(cardName)),
            let scopeEndIndex = report.events.firstIndex(of: .scopeEnded)
        else {
            return XCTFail("Beklenen olaylar günlükte yok: \(report.events)", file: file, line: line)
        }
        XCTAssertLessThan(memberIndex, cardIndex, "Üye kartı tuttuğu için önce üye yok edilmeli", file: file, line: line)
        XCTAssertLessThan(cardIndex, scopeEndIndex, "Nesneler fonksiyon dönmeden yok edilmiş olmalı", file: file, line: line)
    }
}
