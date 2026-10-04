import XCTest
@testable import BookShelf

/// MVVM ViewModel testleri: SwiftUI açmadan durum geçişleri. VIPER interactor testlerinin aksine expectation yok:
/// view model'in metotları `async`, test doğrudan `await` eder ve iş bittiğinde sonucu okur.
final class NotesListViewModelTests: XCTestCase {
    private typealias Doubles = NotesArchitectureDoubles

    @MainActor
    private func makeSUT(
        repository: any NotesRepository = InMemoryNotesRepository()
    ) -> NotesListViewModel {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        return NotesListViewModel(
            useCases: NotesUseCases(repository: repository, now: { date }),
            formatter: Doubles.FixedFormatter()
        )
    }

    // MARK: - Yükleme

    @MainActor
    func testStartsLoadingThenShowsRowsNewestFirst() async {
        let old = Doubles.note("eski", at: 1)
        let new = Doubles.note("yeni", at: 2)
        let viewModel = makeSUT(repository: InMemoryNotesRepository(notes: [old, new]))
        XCTAssertEqual(viewModel.state, .loading)

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded([
            NoteRow(id: new.id, text: "yeni", detail: "ayrıntı: yeni"),
            NoteRow(id: old.id, text: "eski", detail: "ayrıntı: eski"),
        ]))
    }

    @MainActor
    func testEmptyRepositoryIsLoadedWithNoRows() async {
        let viewModel = makeSUT()

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded([]))
    }

    @MainActor
    func testLoadFailureShowsRepositoryMessage() async {
        let viewModel = makeSUT(repository: Doubles.FailingRepository())

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .failed(message: "Notlar kaydedilemedi: disk dolu"))
    }

    // MARK: - Ekleme

    @MainActor
    func testSavingValidDraftAddsNoteClearsDraftAndReturnsTrue() async {
        let viewModel = makeSUT()
        await viewModel.load()
        viewModel.startNewNote()
        viewModel.draftText = "  Yeni not  "

        let saved = await viewModel.saveDraft()

        XCTAssertTrue(saved)
        XCTAssertEqual(viewModel.draftText, "")
        XCTAssertNil(viewModel.editorMessage)
        guard case .loaded(let rows) = viewModel.state else {
            return XCTFail("Liste bekleniyordu: \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.text), ["Yeni not"])
    }

    @MainActor
    func testEmptyDraftShowsDomainMessageAndKeepsEditorOpen() async {
        let repository = InMemoryNotesRepository()
        let viewModel = makeSUT(repository: repository)
        viewModel.draftText = "   "

        let saved = await viewModel.saveDraft()

        XCTAssertFalse(saved, "Editör açık kalmalı")
        XCTAssertEqual(viewModel.editorMessage, "Not boş olamaz.", "VIPER'daki alert ile aynı mesaj")
        XCTAssertEqual(viewModel.draftText, "   ", "Kullanıcının yazdığı silinmemeli")
        let stored = await repository.fetchAll()
        XCTAssertTrue(stored.isEmpty)
    }

    @MainActor
    func testTypingClearsPreviousEditorMessage() async {
        let viewModel = makeSUT()
        _ = await viewModel.saveDraft()
        XCTAssertNotNil(viewModel.editorMessage)

        viewModel.draftText = "d"

        XCTAssertNil(viewModel.editorMessage)
    }

    @MainActor
    func testCharacterCounterUsesSameTrimmingAsTheRule() {
        let viewModel = makeSUT()

        viewModel.draftText = "  merhaba  "
        XCTAssertEqual(viewModel.characterCountText, "7/280")
        XCTAssertFalse(viewModel.isDraftTooLong)

        viewModel.draftText = String(repeating: "x", count: 281)
        XCTAssertTrue(viewModel.isDraftTooLong)
    }

    // MARK: - Silme

    @MainActor
    func testDeleteRemovesRowAndNote() async {
        let keep = Doubles.note("kalsın", at: 1)
        let remove = Doubles.note("silinsin", at: 2)
        let repository = InMemoryNotesRepository(notes: [keep, remove])
        let viewModel = makeSUT(repository: repository)
        await viewModel.load()

        await viewModel.delete(NoteRow(note: remove, formatter: Doubles.FixedFormatter()))

        XCTAssertEqual(viewModel.state, .loaded([NoteRow(note: keep, formatter: Doubles.FixedFormatter())]))
        let stored = await repository.fetchAll()
        XCTAssertEqual(stored, [keep])
        XCTAssertNil(viewModel.alertMessage)
    }

    /// İyimser silme başarısız olursa satır geri gelir ve uyarı gösterilir.
    @MainActor
    func testFailedDeleteRestoresRowAndShowsAlert() async {
        let note = Doubles.note("silinemez", at: 1)
        let viewModel = makeSUT(repository: Doubles.ReadOnlyRepository(notes: [note]))
        await viewModel.load()
        let row = NoteRow(note: note, formatter: Doubles.FixedFormatter())

        await viewModel.delete(row)

        XCTAssertEqual(viewModel.state, .loaded([row]))
        XCTAssertEqual(viewModel.alertMessage, "Notlar kaydedilemedi: disk dolu")
    }

    // MARK: - İki arayüz, tek depo

    /// Demo'daki "VIPER'da ekle, MVVM'e geç" akışının birim testi: aynı depoyu kullanan iki sunum aynı veriyi görür.
    @MainActor
    func testNoteAddedThroughVIPERInteractorIsVisibleToViewModel() async {
        let repository = InMemoryNotesRepository()
        let interactor = NotesListInteractor(useCases: NotesUseCases(repository: repository))
        let output = Doubles.InteractorOutputSpy()
        interactor.output = output
        let delivered = expectation(description: "VIPER kaydetti")
        output.onEvent = { delivered.fulfill() }

        interactor.addNote(text: "VIPER'dan")
        await fulfillment(of: [delivered], timeout: 2)

        let viewModel = makeSUT(repository: repository)
        await viewModel.load()
        guard case .loaded(let rows) = viewModel.state else {
            return XCTFail("Liste bekleniyordu: \(viewModel.state)")
        }
        XCTAssertEqual(rows.map(\.text), ["VIPER'dan"])
    }
}
