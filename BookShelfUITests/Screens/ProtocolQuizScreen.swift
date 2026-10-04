import XCTest

/// "Olur mu, olmaz mı?" quiz'i (`SwiftQuizView`). "Protocol tip olarak" konusunun demosu.
///
/// Cevap ve gezinme düğmeleri ekranın altındaki sabit çubukta (`safeAreaInset`); kod ne kadar uzun olursa olsun
/// görünür ve dokunulabilir kalırlar. Sonuç kartı (`verdict`, `correctAnswer`...) yalnızca cevaptan sonra vardır.
/// Quiz bir `ScrollView` + `VStack` olduğu için (tembel değil) ekranın altındaki metinler de ağaçta bulunur.
@MainActor
struct ProtocolQuizScreen: Screen {
    private typealias ID = AccessibilityID.Fundamentals.ProtocolQuiz

    let app: XCUIApplication

    var rootElement: XCUIElement { compilesButton }

    /// "Skor: 1/2" (doğru / cevaplanan)
    var score: XCUIElement { app.staticTexts[ID.score] }
    /// "Soru 2/16"
    var progress: XCUIElement { app.staticTexts[ID.progress] }
    var snippetTitle: XCUIElement { app.staticTexts[ID.snippetTitle] }
    var code: XCUIElement { app.staticTexts[ID.code] }

    var compilesButton: XCUIElement { app.buttons[ID.compilesButton] }
    var failsButton: XCUIElement { app.buttons[ID.failsButton] }
    var previousButton: XCUIElement { app.buttons[ID.previousButton] }
    var nextButton: XCUIElement { app.buttons[ID.nextButton] }

    // MARK: Cevaptan sonra görünenler

    /// "Doğru ✓" | "Yanlış ✗"
    var verdict: XCUIElement { app.staticTexts[ID.verdict] }
    /// "Doğru cevap: Derlenir" | "Doğru cevap: Derlenir, ama uyarı verir" | "Doğru cevap: Derlenmez"
    var correctAnswer: XCUIElement { app.staticTexts[ID.correctAnswer] }
    /// Derleyicinin birebir mesajı ("error: ..." / "warning: ...").
    var compilerMessage: XCUIElement { app.staticTexts[ID.compilerMessage] }

    // MARK: Eylemler

    /// "Olur ✓": Bu kod derlenir.
    func answerCompiles() {
        compilesButton.tap()
    }

    /// "Olmaz ✗": Bu kod derlenmez.
    func answerFails() {
        failsButton.tap()
    }

    func goToNextQuestion() {
        nextButton.tap()
    }
}
