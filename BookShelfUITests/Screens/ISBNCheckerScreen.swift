import XCTest

/// ISBN doğrulayıcı ekranı (`ISBNCheckerView`; doğrulamayı Objective-C'deki `BKISBNValidator` yapar).
@MainActor
struct ISBNCheckerScreen: Screen {
    private typealias ID = AccessibilityID.ISBNChecker

    let app: XCUIApplication

    var rootElement: XCUIElement { inputField }

    var inputField: XCUIElement { app.textFields[ID.inputField] }
    var validateButton: XCUIElement { app.buttons[ID.validateButton] }
    /// Yalnızca bir doğrulamadan sonra vardır; girdi değişince kaybolur.
    var resultLabel: XCUIElement { app.staticTexts[ID.resultLabel] }
    var hintLabel: XCUIElement { app.staticTexts[ID.hintLabel] }
    var normalizedLabel: XCUIElement { app.staticTexts[ID.normalizedLabel] }
    var lettersSampleButton: XCUIElement { app.buttons[ID.sampleLettersButton] }

    // MARK: Eylemler

    /// Metin kutusuna dokunup (klavye odağı onda olsun diye) metni yazar.
    ///
    /// `typeText` gerçek tuş vuruşları üretir: Uygulama her karakteri bir kullanıcı yazıyormuş gibi alır,
    /// `onChange` gibi tepkiler de çalışır. Klavye odağı olmayan bir öğeye `typeText` göndermek hatadır;
    /// bu yüzden önce `tap()`. (Simülatörde donanım klavyesi bağlıysa yazılım klavyesi görünmez; `typeText` yine çalışır.)
    func type(_ text: String) {
        inputField.tap()
        inputField.typeText(text)
    }

    func validate() {
        validateButton.tap()
    }

    /// Kullanıcının yaptığı gibi: yaz, sonra "Doğrula"ya dokun.
    func check(_ isbn: String) {
        type(isbn)
        validate()
    }
}
