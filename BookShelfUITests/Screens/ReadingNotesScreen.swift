import XCTest

/// "Clean Architecture, VIPER ve MVVM" demosu (`ReadingNotesDemoView`): aynı not listesi iki kez, VIPER (UIKit) ve
/// MVVM (SwiftUI) ile. Test, hangi çatının kullanıldığını bilmez; sadece erişilebilirlik ağacını görür:
/// ```
/// SegmentedControl "readingNotes.presentationPicker"   [VIPER · UIKit | MVVM · SwiftUI | Kıyas]
/// VIPER:  Table "readingNotes.viper.table" → Cell → StaticText "<not metni>"
/// MVVM:   CollectionView "readingNotes.mvvm.list" → Cell → StaticText "<not metni>"
/// ```
/// Notların kimliği UUID olduğu için satırları **görünen metinleriyle** buluruz; metni test kendisi yazdığı için bilir.
@MainActor
struct ReadingNotesScreen: Screen {
    private typealias ID = AccessibilityID.ReadingNotes

    let app: XCUIApplication

    var rootElement: XCUIElement { presentationPicker }

    var presentationPicker: XCUIElement { app.segmentedControls[ID.presentationPicker] }

    func showVIPER() {
        presentationPicker.buttons[ID.viperSegment].tap()
    }

    func showMVVM() {
        presentationPicker.buttons[ID.mvvmSegment].tap()
    }

    /// Satırı kaydırıp "Sil"e dokunur. `UIContextualAction` ve SwiftUI kaydırma düğmesinin kimliği olmadığı için
    /// düğmeyi görünen başlığıyla buluruz (iki arayüzde de aynı sabit).
    func deleteWithSwipe(_ cell: XCUIElement) {
        cell.swipeLeft()
        app.buttons[ID.deleteActionTitle].firstMatch.tap()
    }

    // MARK: - VIPER (UIKit)

    var viperTable: XCUIElement { app.tables[ID.VIPER.table] }
    var viperAddButton: XCUIElement { app.buttons[ID.VIPER.addButton] }
    var viperSummary: XCUIElement { app.staticTexts[ID.VIPER.summary] }
    var viperEmptyState: XCUIElement { app.staticTexts[ID.VIPER.emptyState] }

    var editorAlert: XCUIElement { app.alerts[ID.VIPER.editorAlert] }
    /// iOS 26'da alert içeriği ağaçta iki kez görünebilir; `.firstMatch` ilk eşleşmeyi seçer.
    var editorTextField: XCUIElement { editorAlert.textFields[ID.VIPER.editorTextField].firstMatch }
    var editorSaveButton: XCUIElement { app.buttons[ID.VIPER.editorSaveButton].firstMatch }

    var errorAlert: XCUIElement { app.alerts[ID.VIPER.errorAlert] }
    var errorOKButton: XCUIElement { app.buttons[ID.VIPER.errorOKButton].firstMatch }

    /// Tablodaki, metni tam olarak `text` olan notun hücresi.
    func viperCell(_ text: String) -> XCUIElement {
        viperTable.cells.containing(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// "Not ekle" → alert'e yaz → "Kaydet". Boş metinle çağrılırsa hiçbir şey yazmadan kaydeder.
    func addNoteInVIPER(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        viperAddButton.tap()
        XCTAssertTrue(
            editorTextField.waitForExistence(timeout: UITestTimeout.standard),
            "Not yazma penceresi açılmadı.", file: file, line: line
        )
        if !text.isEmpty {
            editorTextField.tap()
            editorTextField.typeText(text)
        }
        editorSaveButton.tap()
    }

    // MARK: - MVVM (SwiftUI)

    var mvvmList: XCUIElement { app.collectionViews[ID.MVVM.list] }
    var mvvmAddButton: XCUIElement { app.buttons[ID.MVVM.addButton] }
    var mvvmEmptyState: XCUIElement { app.staticTexts[ID.MVVM.emptyState] }

    var mvvmEditorTextField: XCUIElement { app.textFields[ID.MVVM.editorTextField].firstMatch }
    var mvvmSaveButton: XCUIElement { app.buttons[ID.MVVM.editorSaveButton].firstMatch }
    var mvvmCancelButton: XCUIElement { app.buttons[ID.MVVM.editorCancelButton].firstMatch }
    var mvvmValidationMessage: XCUIElement { app.staticTexts[ID.MVVM.editorValidationMessage] }

    func mvvmCell(_ text: String) -> XCUIElement {
        mvvmList.cells.containing(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// "Not ekle" → sayfada yaz → "Kaydet". Boş metinle çağrılırsa hiçbir şey yazmadan kaydeder.
    func addNoteInMVVM(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        mvvmAddButton.tap()
        XCTAssertTrue(
            mvvmEditorTextField.waitForExistence(timeout: UITestTimeout.standard),
            "Not ekleme sayfası açılmadı.", file: file, line: line
        )
        if !text.isEmpty {
            mvvmEditorTextField.tap()
            mvvmEditorTextField.typeText(text)
        }
        mvvmSaveButton.tap()
    }
}
