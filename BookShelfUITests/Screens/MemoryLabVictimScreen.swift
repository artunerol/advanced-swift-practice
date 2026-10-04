import XCTest

/// Sızıntı laboratuvarının modal olarak açtığı kurban ekranı (`LeakVictimViewController`).
///
/// Kök öğe olarak "Kapat" düğmesini kullanıyoruz: Kurban açıkken hep görünür ve bir `UIButton` olduğu için
/// erişilebilirlik ağacında kesinlikle vardır (kimlik verilmiş düz bir `UIView` her zaman listelenmeyebilir).
@MainActor
struct MemoryLabVictimScreen: Screen {
    private typealias ID = AccessibilityID.MemoryLab.Victim

    let app: XCUIApplication

    var rootElement: XCUIElement { closeButton }

    var closeButton: XCUIElement { app.buttons[ID.closeButton] }
    var triggerButton: XCUIElement { app.buttons[ID.triggerButton] }
    /// "Callback sayısı: 3"
    var callbackCountLabel: XCUIElement { app.staticTexts[ID.callbackCountLabel] }

    func trigger() {
        triggerButton.tap()
    }

    /// Kurbanı kapatır; laboratuvar ölçüme başlar.
    @discardableResult
    func close() -> MemoryLabScreen {
        closeButton.tap()
        return MemoryLabScreen(app: app)
    }
}
