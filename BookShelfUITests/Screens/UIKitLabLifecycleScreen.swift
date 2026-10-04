import XCTest

/// Yaşam döngüsü lab'ı (`LifecycleLabViewController`): üstte "Ana" ekranın düğmeleri, altta günlük.
///
/// Günlük bir `UITextView`; XCUITest'te metnin TAMAMI `value` olarak gelir. Böylece ekranda görünmeyen (kaymış)
/// satırları da kaydırmadan doğrulayabiliriz. Satır biçimi: "12. +452 ms  Ana · viewDidLoad".
@MainActor
struct UIKitLabLifecycleScreen: Screen {
    private typealias ID = AccessibilityID.UIKitLabs.Lifecycle

    let app: XCUIApplication

    var rootElement: XCUIElement { log }

    var log: XCUIElement { app.textViews[ID.log] }
    var clearButton: XCUIElement { app.buttons[ID.clearButton] }
    var presentPageSheetButton: XCUIElement { app.buttons[ID.presentPageSheetButton] }
    var presentFullScreenButton: XCUIElement { app.buttons[ID.presentFullScreenButton] }
    var pushButton: XCUIElement { app.buttons[ID.pushButton] }
    var relayoutButton: XCUIElement { app.buttons[ID.relayoutButton] }
    /// Sunulan / push edilen ekrandaki "Kapat" ya da "Geri dön" düğmesi.
    var closeButton: XCUIElement { app.buttons[ID.closeButton] }

    /// Günlükteki bir satırın aranacak parçası, ör. `entry("Ana", "viewDidLoad")` → "Ana · viewDidLoad".
    static func entry(_ screenName: String, _ event: String) -> String {
        "\(screenName) · \(event)"
    }

    /// Günlüğün o anki metni (öğe yoksa boş).
    var logText: String {
        log.exists ? (log.value as? String ?? "") : ""
    }

    // MARK: Eylemler

    func clearLog() {
        clearButton.tap()
    }

    /// Bir ekranı açar (sunar ya da push eder), açılan ekranın kapatma düğmesini ("Kapat" / "Geri dön") bekleyip
    /// ona dokunur ve ekran tamamen kapanana kadar bekler.
    func openAndClose(using openButton: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        openButton.tap()
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: UITestTimeout.standard),
            "Açılan ekranın kapatma düğmesi görünmedi.",
            file: file, line: line
        )
        closeButton.tap()
        XCTAssertTrue(
            closeButton.waitForNonExistence(timeout: UITestTimeout.standard),
            "Açılan ekran kapanmadı.",
            file: file, line: line
        )
    }
}
