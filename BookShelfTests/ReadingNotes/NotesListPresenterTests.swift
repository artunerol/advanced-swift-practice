import XCTest
@testable import BookShelf

/// VIPER Presenter testleri. View, Interactor ve Router sahte (spy); presenter tamamen senkron olduğu için
/// testlerde bekleme (await, expectation) yok. VIPER'ın test edilebilirlik vaadi tam olarak bu.
final class NotesListPresenterTests: XCTestCase {
    private typealias Doubles = NotesArchitectureDoubles

    @MainActor
    private func makeSUT() -> (NotesListPresenter, Doubles.ViewSpy, Doubles.InteractorSpy, Doubles.RouterSpy) {
        let view = Doubles.ViewSpy()
        let interactor = Doubles.InteractorSpy()
        let router = Doubles.RouterSpy()
        let presenter = NotesListPresenter(interactor: interactor, router: router, formatter: Doubles.FixedFormatter())
        presenter.view = view
        return (presenter, view, interactor, router)
    }

    // MARK: - View → Presenter → Interactor / Router

    @MainActor
    func testViewDidLoadShowsLoadingAndAsksInteractorForNotes() {
        let (presenter, view, interactor, _) = makeSUT()

        presenter.viewDidLoad()

        XCTAssertEqual(view.renderedStates, [.loading])
        XCTAssertEqual(interactor.loadNotesCallCount, 1)
    }

    @MainActor
    func testTappingAddOpensEditorThroughRouterAndSavedTextGoesToInteractor() {
        let (presenter, _, interactor, router) = makeSUT()

        presenter.didTapAddNote()
        XCTAssertEqual(router.presentEditorCallCount, 1)
        XCTAssertTrue(interactor.addedTexts.isEmpty, "Editör açıldı ama henüz bir şey kaydedilmedi")

        router.simulateSave("  ham metin  ")

        // Presenter doğrulama/kırpma yapmaz; metni olduğu gibi iletir. Kural domain'de.
        XCTAssertEqual(interactor.addedTexts, ["  ham metin  "])
    }

    @MainActor
    func testDeleteRequestIsForwardedWithNoteID() {
        let (presenter, _, interactor, _) = makeSUT()
        let id = UUID()

        presenter.didRequestDeleteNote(id: id)

        XCTAssertEqual(interactor.deletedIDs, [id])
    }

    // MARK: - Interactor → Presenter → View

    @MainActor
    func testLoadedNotesAreFormattedIntoRowsAndSummary() {
        let (presenter, view, _, _) = makeSUT()
        let first = Doubles.note("Birinci", at: 200)
        let second = Doubles.note("İkinci", at: 100)

        presenter.didLoadNotes([first, second])

        XCTAssertEqual(view.renderedStates.last, .notes(
            summary: "2 not · en yeni en üstte",
            rows: [
                NoteRow(id: first.id, text: "Birinci", detail: "ayrıntı: Birinci"),
                NoteRow(id: second.id, text: "İkinci", detail: "ayrıntı: İkinci"),
            ]
        ))
    }

    @MainActor
    func testEmptyListRendersEmptyState() {
        let (presenter, view, _, _) = makeSUT()

        presenter.didLoadNotes([])

        guard case .empty(let message) = view.renderedStates.last else {
            return XCTFail("Boş durum bekleniyordu, gelen: \(String(describing: view.renderedStates.last))")
        }
        XCTAssertTrue(message.contains("Not ekle"), message)
    }

    @MainActor
    func testRejectedNoteShowsDomainMessage() {
        let (presenter, view, _, _) = makeSUT()

        presenter.didRejectNote(.empty)

        XCTAssertEqual(view.shownErrors.map(\.title), ["Not eklenemedi"])
        XCTAssertEqual(view.shownErrors.map(\.message), ["Not boş olamaz."])
    }

    @MainActor
    func testStorageFailureShowsGenericTitleWithRepositoryMessage() {
        let (presenter, view, _, _) = makeSUT()

        presenter.didFail(with: Doubles.FailingRepository.error)

        XCTAssertEqual(view.shownErrors.map(\.title), ["Bir sorun oluştu"])
        XCTAssertEqual(view.shownErrors.map(\.message), ["Notlar kaydedilemedi: disk dolu"])
    }

    // MARK: - Bellek

    /// Presenter view'ı `weak` tutar: view yok olunca presenter onu hayatta tutmaz ve çağrılar sessizce düşer.
    @MainActor
    func testPresenterHoldsViewWeakly() {
        let (presenter, _, _, _) = makeSUT()
        var view: Doubles.ViewSpy? = Doubles.ViewSpy()
        presenter.view = view
        weak let weakView = view

        view = nil

        XCTAssertNil(weakView)
        XCTAssertNil(presenter.view)
        presenter.didLoadNotes([]) // çökmemeli
    }

    /// Router'a verilen closure presenter'ı `weak` yakalar: editör açıkken modül kapanırsa presenter yaşamaz.
    @MainActor
    func testEditorCallbackDoesNotKeepPresenterAlive() {
        let interactor = Doubles.InteractorSpy()
        let router = Doubles.RouterSpy()
        var presenter: NotesListPresenter? = NotesListPresenter(
            interactor: interactor, router: router, formatter: Doubles.FixedFormatter()
        )
        weak let weakPresenter = presenter

        presenter?.didTapAddNote()
        presenter = nil

        XCTAssertNil(weakPresenter, "Router'ın sakladığı closure presenter'ı tutmamalı")
        router.simulateSave("geç kalan kayıt") // presenter yok; hiçbir şey olmamalı
        XCTAssertTrue(interactor.addedTexts.isEmpty)
    }
}
