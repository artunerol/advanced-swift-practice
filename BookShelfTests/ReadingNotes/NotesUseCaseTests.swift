import XCTest
@testable import BookShelf

/// Domain katmanının (use case'lerin) testleri. UIKit yok, SwiftUI yok, Core Data yok: sadece iş kuralları.
/// Depo olarak gerçek ama basit `InMemoryNotesRepository` (fake) kullanılır; testler milisaniyeler sürer.
final class NotesUseCaseTests: XCTestCase {
    private typealias Doubles = NotesArchitectureDoubles

    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - AddNoteUseCase: doğrulama

    func testValidateTrimsLeadingAndTrailingWhitespaceButKeepsInnerNewlines() throws {
        let useCase = AddNoteUseCase(repository: InMemoryNotesRepository())

        let text = try useCase.validate("  \n İlk satır\nİkinci satır \n\t")

        XCTAssertEqual(text, "İlk satır\nİkinci satır")
    }

    func testValidateRejectsEmptyAndWhitespaceOnlyText() {
        let useCase = AddNoteUseCase(repository: InMemoryNotesRepository())

        for input in ["", "   ", "\n\n", " \t \n "] {
            // Typed throws: `error` doğrudan `NoteValidationError`; `as?` gerekmez.
            XCTAssertThrowsError(try useCase.validate(input), "\"\(input)\"") { error in
                XCTAssertEqual(error as? NoteValidationError, .empty)
            }
        }
    }

    func testValidateAcceptsExactlyMaxLengthAndRejectsOneMore() throws {
        let useCase = AddNoteUseCase(repository: InMemoryNotesRepository())
        let limit = AddNoteUseCase.maxLength

        XCTAssertEqual(try useCase.validate(String(repeating: "a", count: limit)).count, limit)
        XCTAssertThrowsError(try useCase.validate(String(repeating: "a", count: limit + 1))) { error in
            XCTAssertEqual(error as? NoteValidationError, .tooLong(count: limit + 1, limit: limit))
        }
    }

    /// Sınır, kırpılmış metne uygulanır: 280 karakter + etrafında boşluklar geçerlidir.
    func testLengthLimitIsCheckedAfterTrimming() throws {
        let useCase = AddNoteUseCase(repository: InMemoryNotesRepository())
        let text = "   " + String(repeating: "b", count: AddNoteUseCase.maxLength) + "   "

        XCTAssertNoThrow(try useCase.validate(text))
    }

    /// `String.count` kullanıcının gördüğü karakterleri (grapheme cluster) sayar:
    /// ten rengi değiştiricili emoji 1 karakterdir.
    func testLengthCountsUserPerceivedCharacters() throws {
        let useCase = AddNoteUseCase(repository: InMemoryNotesRepository())
        let emoji = "👍🏽"
        XCTAssertEqual(emoji.unicodeScalars.count, 2)
        XCTAssertEqual(emoji.utf16.count, 4)

        let text = String(repeating: emoji, count: AddNoteUseCase.maxLength)

        XCTAssertNoThrow(try useCase.validate(text), "280 emoji = 280 karakter, sınırın içinde")
    }

    func testValidationErrorsHaveTurkishMessages() {
        XCTAssertEqual(NoteValidationError.empty.localizedDescription, "Not boş olamaz.")
        XCTAssertEqual(
            NoteValidationError.tooLong(count: 300, limit: 280).localizedDescription,
            "Not en fazla 280 karakter olabilir (şu an 300)."
        )
    }

    // MARK: - AddNoteUseCase: kaydetme

    func testExecuteSavesTrimmedNoteWithInjectedDateAndBook() async throws {
        let repository = InMemoryNotesRepository()
        let date = fixedDate
        let useCase = AddNoteUseCase(repository: repository, now: { date })

        let note = try await useCase.execute(text: "  Güzel bir cümle.  ", bookID: 3)

        XCTAssertEqual(note.text, "Güzel bir cümle.")
        XCTAssertEqual(note.createdAt, fixedDate)
        XCTAssertEqual(note.bookID, 3)
        let stored = await repository.fetchAll()
        XCTAssertEqual(stored, [note])
    }

    func testExecuteDoesNotTouchRepositoryWhenValidationFails() async {
        let repository = InMemoryNotesRepository()
        let useCase = AddNoteUseCase(repository: repository)

        do {
            try await useCase.execute(text: "   ")
            XCTFail("Boş not kaydedilmemeli")
        } catch {
            XCTAssertEqual(error as? NoteValidationError, .empty)
        }
        let stored = await repository.fetchAll()
        XCTAssertTrue(stored.isEmpty)
    }

    func testExecuteForwardsRepositoryError() async {
        let useCase = AddNoteUseCase(repository: Doubles.FailingRepository())

        do {
            try await useCase.execute(text: "Geçerli metin")
            XCTFail("Depo hatası iletilmeli")
        } catch {
            XCTAssertEqual(error as? NotesRepositoryError, Doubles.FailingRepository.error)
        }
    }

    // MARK: - Fetch / Delete

    func testFetchReturnsNewestFirstEvenIfRepositoryDoesNot() async throws {
        let old = Doubles.note("eski", at: 100)
        let new = Doubles.note("yeni", at: 300)
        let middle = Doubles.note("orta", at: 200)
        // Depo bilerek karışık sırada döndürüyor (salt okunur sahte depo, verdiğimiz sırayı korur).
        let repository = Doubles.ReadOnlyRepository(notes: [old, new, middle])

        let notes = try await FetchNotesUseCase(repository: repository).execute()

        XCTAssertEqual(notes.map(\.text), ["yeni", "orta", "eski"])
    }

    func testDeleteRemovesOnlyThatNoteAndIsIdempotent() async throws {
        let keep = Doubles.note("kalsın", at: 1)
        let remove = Doubles.note("silinsin", at: 2)
        let repository = InMemoryNotesRepository(notes: [keep, remove])
        let useCase = DeleteNoteUseCase(repository: repository)

        try await useCase.execute(id: remove.id)
        try await useCase.execute(id: remove.id) // ikinci kez: hata yok

        let stored = await repository.fetchAll()
        XCTAssertEqual(stored, [keep])
    }

    func testUseCaseBundleSharesOneRepository() async throws {
        let date = fixedDate
        let useCases = NotesUseCases(repository: InMemoryNotesRepository(), now: { date })

        let note = try await useCases.add.execute(text: "Paylaşılan depo")
        let afterAdd = try await useCases.fetch.execute()
        try await useCases.delete.execute(id: note.id)
        let afterDelete = try await useCases.fetch.execute()

        XCTAssertEqual(afterAdd, [note])
        XCTAssertTrue(afterDelete.isEmpty)
    }
}
