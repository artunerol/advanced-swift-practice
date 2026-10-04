import XCTest
@testable import BookShelf

/// VIPER Interactor testleri: gerçek use case'ler + bellekte çalışan depo (fake) + sahte çıkış (spy).
///
/// Interactor sonucu bir `Task` içinde, **sonra** bildirir; testin bekleyebileceği bir dönüş değeri yok.
/// Klasik çözüm `XCTestExpectation`: spy her olayda `fulfill()` çağırır, test `fulfillment(of:timeout:)` ile bekler.
/// Zaman aşımı bir üst sınırdır; her şey yolundaysa olay milisaniyeler içinde gelir.
final class NotesListInteractorTests: XCTestCase {
    private typealias Doubles = NotesArchitectureDoubles

    @MainActor
    private func makeSUT(
        repository: any NotesRepository = InMemoryNotesRepository()
    ) -> (NotesListInteractor, Doubles.InteractorOutputSpy) {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let interactor = NotesListInteractor(useCases: NotesUseCases(repository: repository, now: { date }))
        let output = Doubles.InteractorOutputSpy()
        interactor.output = output
        return (interactor, output)
    }

    /// `action`'ı çalıştırır ve çıkışa `count` olay gelene kadar bekler.
    @MainActor
    private func perform(
        _ action: () -> Void,
        expecting count: Int = 1,
        on output: Doubles.InteractorOutputSpy
    ) async {
        let delivered = expectation(description: "\(count) çıkış olayı")
        delivered.expectedFulfillmentCount = count
        output.onEvent = { delivered.fulfill() }
        action()
        await fulfillment(of: [delivered], timeout: 2)
    }

    @MainActor
    func testLoadNotesDeliversNotesNewestFirst() async {
        let old = Doubles.note("eski", at: 1)
        let new = Doubles.note("yeni", at: 2)
        let (interactor, output) = makeSUT(repository: InMemoryNotesRepository(notes: [old, new]))

        await perform({ interactor.loadNotes() }, on: output)

        XCTAssertEqual(output.events, [.loaded([new, old])])
    }

    @MainActor
    func testAddNoteSavesThenDeliversRefreshedList() async throws {
        let repository = InMemoryNotesRepository()
        let (interactor, output) = makeSUT(repository: repository)

        await perform({ interactor.addNote(text: "  Yeni not  ") }, on: output)

        guard case .loaded(let notes) = try XCTUnwrap(output.events.first) else {
            return XCTFail("Liste bekleniyordu: \(output.events)")
        }
        XCTAssertEqual(notes.map(\.text), ["Yeni not"])
        let stored = await repository.fetchAll()
        XCTAssertEqual(stored, notes)
    }

    @MainActor
    func testInvalidNoteIsRejectedAndNothingIsSaved() async {
        let repository = InMemoryNotesRepository()
        let (interactor, output) = makeSUT(repository: repository)

        await perform({ interactor.addNote(text: " \n ") }, on: output)

        XCTAssertEqual(output.events, [.rejected(.empty)])
        let stored = await repository.fetchAll()
        XCTAssertTrue(stored.isEmpty)
    }

    @MainActor
    func testDeleteNoteRemovesItAndDeliversRefreshedList() async {
        let keep = Doubles.note("kalsın", at: 1)
        let remove = Doubles.note("silinsin", at: 2)
        let (interactor, output) = makeSUT(repository: InMemoryNotesRepository(notes: [keep, remove]))

        await perform({ interactor.deleteNote(id: remove.id) }, on: output)

        XCTAssertEqual(output.events, [.loaded([keep])])
    }

    @MainActor
    func testRepositoryFailuresAreReportedAsFailures() async {
        let (interactor, output) = makeSUT(repository: Doubles.FailingRepository())
        let message = Doubles.FailingRepository.error.localizedDescription

        await perform({ interactor.loadNotes() }, on: output)
        await perform({ interactor.addNote(text: "geçerli") }, on: output)
        await perform({ interactor.deleteNote(id: UUID()) }, on: output)

        XCTAssertEqual(output.events, [.failed(message), .failed(message), .failed(message)])
    }

    /// Interactor çıkışını `weak` tutar: presenter yoksa sonuç sessizce düşer ve interactor onu hayatta tutmaz.
    @MainActor
    func testInteractorHoldsOutputWeakly() {
        let (interactor, _) = makeSUT()
        var output: Doubles.InteractorOutputSpy? = Doubles.InteractorOutputSpy()
        interactor.output = output
        weak let weakOutput = output

        output = nil

        XCTAssertNil(weakOutput)
        XCTAssertNil(interactor.output)
    }
}
