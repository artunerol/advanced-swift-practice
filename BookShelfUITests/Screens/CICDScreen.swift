import XCTest

/// Mülakat merkezindeki CI/CD demosu (`CICDTopicView`): dikey pipeline + "Mülakatta nasıl anlatırsın?" listesi.
///
/// Demonun tamamı tek bir `List`. Alttaki öğeler (kontrol listesi, cevap) ekrana kaydırılmadan erişilebilirlik
/// ağacında yoktur; eylemler bu yüzden önce `scrollUp(toReveal:)` ile öğeyi görünür hale getirir.
@MainActor
struct CICDScreen: Screen {
    private typealias ID = AccessibilityID.CICD

    let app: XCUIApplication

    var rootElement: XCUIElement { list }

    var list: XCUIElement { app.collectionViews[ID.list] }

    func stageButton(_ stageID: String) -> XCUIElement { app.buttons[ID.stageButton(stageID)] }
    func stageRepoLocation(_ stageID: String) -> XCUIElement { app.staticTexts[ID.stageRepoLocation(stageID)] }
    func experienceButton(_ experienceID: String) -> XCUIElement { app.buttons[ID.experienceButton(experienceID)] }
    var answerSummary: XCUIElement { app.staticTexts[ID.answerSummary] }
    var answerText: XCUIElement { app.staticTexts[ID.answerText] }

    /// Aşamaya dokunup ayrıntılarını açar (açıksa kapatır).
    func toggleStage(_ stageID: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(stageButton(stageID), file: file, line: line)
        stageButton(stageID).tap()
    }

    /// Kontrol listesinde bir deneyimi işaretler ya da işaretini kaldırır.
    func toggleExperience(_ experienceID: String, file: StaticString = #filePath, line: UInt = #line) {
        reveal(experienceButton(experienceID), file: file, line: line)
        experienceButton(experienceID).tap()
    }

    /// Öğe dokunulabilir olana kadar listeyi kaydırır; olmazsa testi çağıran satırda kırar.
    func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            list.scrollUp(toReveal: element, maxSwipes: 12),
            "CI/CD demosunda öğe bulunamadı: \(element)",
            file: file, line: line
        )
    }
}
