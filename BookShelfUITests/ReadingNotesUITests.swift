import XCTest

/// Mimari demoları: aynı "Okuma Notları" özelliği VIPER (UIKit) ve MVVM (SwiftUI) ile; ayrıca DIP vs DI demosu.
///
/// Uygulama `-ui-testing` ile açıldığı için notlar bellekte tutulur: her test boş bir depoyla başlar.
final class ReadingNotesUITests: BookShelfUITestCase {

    /// Uygulamayı açar, Mülakat sekmesinde konuyu bulur ve "Demo" bölümüne geçer.
    @MainActor
    private func openDemo<S: Screen>(
        _ topicID: String,
        as screenType: S.Type,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> S {
        let app = launchApp(file: file, line: line)
        TabBarScreen(app: app).openInterview().waitUntilDisplayed(file: file, line: line)
            .openTopic(topicID, file: file, line: line)
            .showDemo()
        return screenType.init(app: app).waitUntilDisplayed(file: file, line: line)
    }

    // MARK: - Aynı depo, iki arayüz

    @MainActor
    func testNoteAddedInVIPERAppearsInMVVMAndDeletingThereEmptiesBoth() {
        let screen = openDemo(AccessibilityID.Interview.TopicID.architecture, as: ReadingNotesScreen.self)
        let text = "VIPER'dan gelen not"

        XCTContext.runActivity(named: "VIPER: boş liste, not ekle") { _ in
            assertAppears(screen.viperEmptyState)
            screen.addNoteInVIPER(text)
            assertAppears(screen.viperCell(text))
            assertLabel(screen.viperSummary, equals: "1 not · en yeni en üstte")
        }

        XCTContext.runActivity(named: "MVVM'e geç: aynı depodan okunan not orada") { _ in
            screen.showMVVM()
            assertAppears(screen.mvvmCell(text))
        }

        XCTContext.runActivity(named: "MVVM'de kaydırıp sil; VIPER'a dönünce de liste boş") { _ in
            screen.deleteWithSwipe(screen.mvvmCell(text))
            assertDisappears(screen.mvvmCell(text))
            assertAppears(screen.mvvmEmptyState)

            screen.showVIPER()
            assertAppears(screen.viperEmptyState)
            XCTAssertFalse(screen.viperCell(text).exists)
        }
    }

    @MainActor
    func testNoteAddedInMVVMAppearsInVIPERAndSwipeDeletesIt() {
        let screen = openDemo(AccessibilityID.Interview.TopicID.architecture, as: ReadingNotesScreen.self)
        let text = "SwiftUI sayfasından not"

        XCTContext.runActivity(named: "MVVM: sayfadan not ekle") { _ in
            screen.showMVVM()
            screen.addNoteInMVVM(text)
            assertAppears(screen.mvvmCell(text))
        }

        XCTContext.runActivity(named: "VIPER: not orada; kaydırıp sil") { _ in
            screen.showVIPER()
            assertAppears(screen.viperCell(text))
            screen.deleteWithSwipe(screen.viperCell(text))
            assertDisappears(screen.viperCell(text))
            assertAppears(screen.viperEmptyState)
        }
    }

    // MARK: - İş kuralı domain'de: iki arayüz, aynı mesaj

    @MainActor
    func testEmptyNoteIsRejectedWithTheSameDomainMessageInBothArchitectures() {
        let screen = openDemo(AccessibilityID.Interview.TopicID.architecture, as: ReadingNotesScreen.self)
        let message = "Not boş olamaz."

        XCTContext.runActivity(named: "VIPER: boş kaydet → hata penceresi") { _ in
            screen.addNoteInVIPER("")
            assertAppears(screen.errorAlert)
            assertAppears(screen.errorAlert.staticTexts[message].firstMatch)
            screen.errorOKButton.tap()
            assertDisappears(screen.errorAlert)
            assertAppears(screen.viperEmptyState)
        }

        XCTContext.runActivity(named: "MVVM: boş kaydet → sayfada aynı mesaj, sayfa açık kalır") { _ in
            screen.showMVVM()
            screen.addNoteInMVVM("")
            assertLabel(screen.mvvmValidationMessage, contains: message)
            XCTAssertTrue(screen.mvvmEditorTextField.exists, "Doğrulama hatasında sayfa kapanmamalı")
            screen.mvvmCancelButton.tap()
            assertAppears(screen.mvvmEmptyState)
        }
    }

    // MARK: - DIP vs DI

    @MainActor
    func testDependencyDemoShowsInjectedRepositoryAndStrategy() {
        typealias ID = AccessibilityID.ReadingNotes.DependencyDemo
        let screen = openDemo(AccessibilityID.Interview.TopicID.dipVsDi, as: ReadingNotesDependencyScreen.self)

        XCTContext.runActivity(named: "Dolu depo: enjekte edilenler 3 sayar, sıkı bağlı 0") { _ in
            assertLabel(screen.injectedCount, equals: "3 not")
            assertLabel(screen.concreteInjectedCount, equals: "3 not")
            assertLabel(screen.tightlyCoupledCount, equals: "0 not")
        }

        XCTContext.runActivity(named: "Boş depo: enjekte edilenler değişir") { _ in
            screen.selectRepository(ID.emptyRepositorySegment)
            assertLabel(screen.injectedCount, equals: "0 not")
            assertLabel(screen.tightlyCoupledCount, equals: "0 not")
        }

        XCTContext.runActivity(named: "Strateji: Uzunluk seçilince çıktı değişir") { _ in
            screen.selectFormatter(ID.lengthFormatterSegment)
            assertLabel(screen.formatterOutput, contains: "karakter · 1 satır")
        }
    }
}
