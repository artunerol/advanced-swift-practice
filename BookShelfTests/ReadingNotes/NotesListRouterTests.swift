import UIKit
import XCTest
@testable import BookShelf

/// VIPER Router testleri: `build(...)` parçaları doğru bağlıyor mu ve modül bellekten tamamen çıkabiliyor mu?
final class NotesListRouterTests: XCTestCase {

    /// `build(...)` ile kurulan modülün parçaları. Testler somut tiplere `as?` ile iner.
    private struct Module {
        let viewController: NotesListViewController
        let presenter: NotesListPresenter
        let interactor: NotesListInteractor
        let router: NotesListRouter
    }

    @MainActor
    private func buildModule(file: StaticString = #filePath, line: UInt = #line) throws -> Module {
        let built = NotesListRouter.build(repository: InMemoryNotesRepository())
        let viewController = try XCTUnwrap(built as? NotesListViewController, file: file, line: line)
        let presenter = try XCTUnwrap(viewController.presenter as? NotesListPresenter, file: file, line: line)
        let interactor = try XCTUnwrap(presenter.interactor as? NotesListInteractor, file: file, line: line)
        let router = try XCTUnwrap(presenter.router as? NotesListRouter, file: file, line: line)
        return Module(viewController: viewController, presenter: presenter, interactor: interactor, router: router)
    }

    // MARK: - Bağlama (wiring)

    @MainActor
    func testBuildWiresWeakBackReferencesToTheRightObjects() throws {
        let module = try buildModule()

        // Property injection ile atanan geri referanslar doğru nesneleri gösteriyor mu? (`===`: aynı nesne mi?)
        XCTAssertTrue(module.presenter.view === module.viewController)
        XCTAssertTrue(module.interactor.output === module.presenter)
        XCTAssertTrue(module.router.viewController === module.viewController)
    }

    // MARK: - Bellek: retain cycle yok

    /// Modülün tek dış sahibi VC. VC bırakılınca presenter, interactor ve router da serbest kalmalı.
    /// Geri referanslardan biri `weak` yerine strong olsaydı döngü kurulur ve bu `weak` değişkenler `nil` olmazdı.
    @MainActor
    func testReleasingViewControllerReleasesWholeModule() throws {
        weak var weakViewController: NotesListViewController?
        weak var weakPresenter: NotesListPresenter?
        weak var weakInteractor: NotesListInteractor?
        weak var weakRouter: NotesListRouter?

        // `autoreleasepool`: UIKit bazı nesneleri "autorelease" eder (bırakmayı havuzun boşaltılmasına erteler).
        // Havuzu burada boşaltarak, sonucu UIKit'in iç zamanlamasından bağımsız hale getiriyoruz.
        try autoreleasepool {
            let module = try buildModule()
            weakViewController = module.viewController
            weakPresenter = module.presenter
            weakInteractor = module.interactor
            weakRouter = module.router
            // View'ı yükle: tablo, düğme closure'ları, data source ve `presenter.viewDidLoad()` da devreye girsin.
            module.viewController.loadViewIfNeeded()
            XCTAssertNotNil(weakPresenter, "VC yaşarken presenter da yaşamalı")
        }

        XCTAssertNil(weakViewController, "VC serbest kalmalı")
        XCTAssertNil(weakPresenter, "Presenter serbest kalmalı (VC → presenter tek strong yol)")
        XCTAssertNil(weakInteractor, "Interactor serbest kalmalı (output weak)")
        XCTAssertNil(weakRouter, "Router serbest kalmalı (viewController weak)")
    }

    // MARK: - Editör

    @MainActor
    func testNoteEditorHasTextFieldCancelAndSave() throws {
        typealias ID = AccessibilityID.ReadingNotes.VIPER
        let alert = NotesListRouter.makeNoteEditor { _ in XCTFail("Kaydet'e basılmadan çağrılmamalı") }

        XCTAssertEqual(alert.preferredStyle, .alert)
        XCTAssertEqual(alert.view.accessibilityIdentifier, ID.editorAlert)
        XCTAssertEqual(alert.textFields?.count, 1)
        XCTAssertEqual(alert.textFields?.first?.accessibilityIdentifier, ID.editorTextField)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
        XCTAssertEqual(alert.actions.map(\.accessibilityIdentifier), [ID.editorCancelButton, ID.editorSaveButton])
        XCTAssertTrue(alert.preferredAction === alert.actions.last)
    }

    @MainActor
    func testRouterWithoutViewControllerDoesNothing() {
        let router = NotesListRouter()
        // VC yok (ör. modül kapanmış): `viewController?.present` sessizce atlanır, çökme yok.
        router.presentNoteEditor { _ in XCTFail("Çağrılmamalı") }
        XCTAssertNil(router.viewController)
    }
}
