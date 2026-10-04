import XCTest
@testable import BookShelf

/// `ISBNCheckOutcome.evaluate(_:)`: ObjC hatasını ekran modeline çeviren mantık, SwiftUI olmadan test ediliyor.
final class ISBNCheckOutcomeTests: XCTestCase {
    func testValidInputProducesValidOutcomeWithNormalizedISBN() {
        let outcome = ISBNCheckOutcome.evaluate("978-605-000-001-6")
        XCTAssertEqual(outcome, .valid(normalized: "9786050000016"))
        XCTAssertTrue(outcome.isValid)
        XCTAssertEqual(outcome.message, "Geçerli ISBN-13 ✓")
    }

    func testChecksumMismatchShowsCorrectCheckDigit() {
        let outcome = ISBNCheckOutcome.evaluate("978-605-000-008-6")
        XCTAssertEqual(
            outcome,
            .invalid(code: .checksumMismatch, message: "Kontrol hanesi (son hane) hatalı.", hint: "Doğru kontrol hanesi: 5")
        )
        XCTAssertFalse(outcome.isValid)
    }

    func testLettersProduceInvalidCharactersOutcome() {
        guard case .invalid(let code, let message, _) = ISBNCheckOutcome.evaluate("978-605-ABC-001-6") else {
            return XCTFail("Geçersiz olmalıydı")
        }
        XCTAssertEqual(code, .invalidCharacters)
        XCTAssertEqual(message, "ISBN yalnızca rakam, tire ve boşluk içerebilir.")
    }

    func testEmptyInputProducesEmptyOutcomeWithHint() {
        guard case .invalid(let code, let message, let hint) = ISBNCheckOutcome.evaluate("") else {
            return XCTFail("Geçersiz olmalıydı")
        }
        XCTAssertEqual(code, .empty)
        XCTAssertEqual(message, "ISBN boş olamaz.")
        XCTAssertNotNil(hint)
    }

    func testWrongLengthHasNoHint() {
        XCTAssertEqual(
            ISBNCheckOutcome.evaluate("978-605-000-001"),
            .invalid(code: .invalidLength, message: "ISBN-13 tam 13 haneden oluşmalı (girilen: 12 hane).", hint: nil)
        )
    }
}
