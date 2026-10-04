import XCTest
@testable import BookShelf

/// Objective-C'de yazılmış `BKISBNValidator`'ı **Swift'ten** test eder.
///
/// Test hedefi ObjC sınıflarını `@testable import BookShelf` üzerinden görür: uygulama modülünün köprü başlığı
/// (bridging header) modülle birlikte içe aktarılır. Böylece ObjC kodunu da XCTest ile Swift'te test edebiliriz.
final class ObjCISBNValidatorTests: XCTestCase {
    // MARK: - Uygulamadaki gerçek veri (books.json)

    /// Kitap 1-7'nin ISBN'leri geçerli olmalı. Veriyi gerçek servisten (sıfır gecikmeyle) okuyoruz ki
    /// `books.json` ile doğrulayıcı birbirinden habersizce bozulursa test yakalasın.
    func testBundledBooksOneThroughSevenHaveValidISBNs() async throws {
        let books = try await LocalBookService(latency: .zero).fetchBooks()
        let validBooks = books.filter { $0.id != 8 }
        XCTAssertEqual(validBooks.map(\.id), Array(1...7))

        for book in validBooks {
            XCTAssertTrue(ISBNValidator.isValidISBN13(book.isbn), "\(book.title) (\(book.isbn)) geçerli olmalı")
            XCTAssertNoThrow(try ISBNValidator.validateISBN13(book.isbn), book.title)
        }
    }

    /// Kitap 8'in ("Huzur") ISBN'i bilerek hatalı: son hane 6 ama 5 olmalı.
    func testBundledBookEightHasChecksumMismatch() async throws {
        let books = try await LocalBookService(latency: .zero).fetchBooks()
        let huzur = try XCTUnwrap(books.first { $0.id == 8 })

        XCTAssertFalse(ISBNValidator.isValidISBN13(huzur.isbn))
        XCTAssertThrowsError(try ISBNValidator.validateISBN13(huzur.isbn)) { error in
            XCTAssertEqual((error as? BKISBNValidatorError)?.code, .checksumMismatch)
        }
        XCTAssertEqual(ISBNValidator.checkDigit(forFirst12Digits: "978605000008"), "5")
    }

    func testKnownValidISBNsPass() {
        let isbns = [
            "978-605-000-001-6", "978-605-000-002-3", "978-605-000-003-0", "978-605-000-004-7",
            "978-605-000-005-4", "978-605-000-006-1", "978-605-000-007-8",
        ]
        for isbn in isbns {
            XCTAssertTrue(ISBNValidator.isValidISBN13(isbn), isbn)
        }
    }

    // MARK: - Normalleştirme

    func testNormalizedISBNRemovesHyphensAndWhitespace() {
        XCTAssertEqual(ISBNValidator.normalizedISBN("978-605-000-001-6"), "9786050000016")
        XCTAssertEqual(ISBNValidator.normalizedISBN(" 978 605 000 001 6 "), "9786050000016")
        XCTAssertEqual(ISBNValidator.normalizedISBN("978-605\t000\n001-6"), "9786050000016")
    }

    func testNormalizedISBNKeepsOtherCharacters() {
        // Normalleştirme karar vermez, sadece temizler; harfler olduğu gibi kalır.
        XCTAssertEqual(ISBNValidator.normalizedISBN("978-ABC"), "978ABC")
    }

    func testValidationAcceptsSpacesInsteadOfHyphens() {
        XCTAssertTrue(ISBNValidator.isValidISBN13("978 605 000 001 6"))
        XCTAssertTrue(ISBNValidator.isValidISBN13("9786050000016"))
    }

    // MARK: - Hata kodları (NSError** -> throws)

    func testEmptyInputThrowsEmpty() {
        for input in ["", "   ", "- -"] {
            XCTAssertEqual(validationErrorCode(for: input), .empty, "'\(input)'")
        }
    }

    func testLettersThrowInvalidCharacters() {
        XCTAssertEqual(validationErrorCode(for: "978-605-ABC-001-6"), .invalidCharacters)
        XCTAssertEqual(validationErrorCode(for: "978605000001X"), .invalidCharacters)
    }

    /// Arapça-Hint rakamları Unicode'da "rakam"dır ama ISBN için geçersizdir.
    /// (`decimalDigitCharacterSet` kullansaydık bu test başarısız olurdu.)
    func testNonASCIIDigitsThrowInvalidCharacters() {
        XCTAssertEqual(validationErrorCode(for: "٩٧٨٦٠٥٠٠٠٠٠١٦"), .invalidCharacters)
    }

    func testWrongLengthThrowsInvalidLength() {
        XCTAssertEqual(validationErrorCode(for: "978-605-000-001"), .invalidLength)   // 12 hane
        XCTAssertEqual(validationErrorCode(for: "97860500000160"), .invalidLength)    // 14 hane
    }

    /// Denetim sırası sözleşmenin parçası: karakter kontrolü uzunluktan ÖNCE gelir.
    func testInvalidCharactersAreReportedBeforeLength() {
        XCTAssertEqual(validationErrorCode(for: "12A"), .invalidCharacters)
    }

    /// Swift'e aktarılan tipli hatanın, altta yatan `NSError` ile aynı domain/code'u taşıdığını doğrular.
    func testErrorCarriesDomainCodeAndTurkishMessage() {
        do {
            try ISBNValidator.validateISBN13("978-605-000-008-6")
            XCTFail("Hata fırlatılmalıydı")
        } catch let error as BKISBNValidatorError {
            XCTAssertEqual(error.code, .checksumMismatch)
            XCTAssertEqual(BKISBNValidatorError.errorDomain, BKISBNValidatorErrorDomain)
            XCTAssertEqual(error.localizedDescription, "Kontrol hanesi (son hane) hatalı.")

            // Aynı hata `NSError` olarak da görülebilir (köprüleme iki yönlü).
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "BKISBNValidatorErrorDomain")
            XCTAssertEqual(nsError.code, BKISBNValidatorError.Code.checksumMismatch.rawValue)
            XCTAssertEqual(nsError.code, 4)
        } catch {
            XCTFail("Beklenmeyen hata tipi: \(error)")
        }
    }

    func testInvalidLengthMessageMentionsDigitCount() {
        XCTAssertThrowsError(try ISBNValidator.validateISBN13("978-605-000-001")) { error in
            XCTAssertEqual(error.localizedDescription, "ISBN-13 tam 13 haneden oluşmalı (girilen: 12 hane).")
        }
    }

    /// `NS_ERROR_ENUM` sayesinde `catch` içinde doğrudan hata koduyla desen eşleştirme (pattern matching) yapılabilir.
    func testCatchPatternMatchesImportedErrorCode() {
        var caughtChecksumMismatch = false
        do {
            try ISBNValidator.validateISBN13("978-605-000-008-6")
        } catch BKISBNValidatorError.checksumMismatch {
            caughtChecksumMismatch = true
        } catch {
            XCTFail("Yanlış hata: \(error)")
        }
        XCTAssertTrue(caughtChecksumMismatch)
    }

    // MARK: - checkDigit(forFirst12Digits:)

    func testCheckDigitForValidPayload() {
        XCTAssertEqual(ISBNValidator.checkDigit(forFirst12Digits: "978605000001"), "6")
        // Toplam 80 -> (10 - 0) % 10 = 0. Sondaki `% 10` olmasaydı sonuç "10" olurdu.
        XCTAssertEqual(ISBNValidator.checkDigit(forFirst12Digits: "978605000003"), "0")
    }

    func testCheckDigitReturnsNilUnlessExactlyTwelveDigits() {
        let invalidPayloads = [
            "",               // boş
            "97860500000",    // 11 hane
            "9786050000016",  // 13 hane
            "97860500000A",   // 12 karakter ama harf var
            "978-605-000-0",  // tire temizlenmez
        ]
        for payload in invalidPayloads {
            XCTAssertNil(ISBNValidator.checkDigit(forFirst12Digits: payload), "'\(payload)'")
        }
    }

    // MARK: - Yardımcı

    /// Doğrulamanın fırlattığı hata kodunu döndürür; hata yoksa ya da tipi farklıysa `nil`.
    private func validationErrorCode(for input: String) -> BKISBNValidatorError.Code? {
        do {
            try ISBNValidator.validateISBN13(input)
            return nil
        } catch let error as BKISBNValidatorError {
            return error.code
        } catch {
            return nil
        }
    }
}
