import XCTest

/// Bir mülakat konusunun ekranı (`InterviewTopicScreen`): üstte Cevap / Demo / Kod seçicisi, sağ üstte ✓ düğmesi.
///
/// Demo ekranlarının kendi page object'leri vardır (ör. `StructVsClassScreen`). Akış:
/// `hub.openTopic(TopicID.structVsClass).showDemo()` → ardından `StructVsClassScreen(app: app)`.
@MainActor
struct InterviewTopicScreen: Screen {
    private typealias ID = AccessibilityID.Interview

    let app: XCUIApplication

    var rootElement: XCUIElement { panePicker }

    var panePicker: XCUIElement { app.segmentedControls[ID.panePicker] }
    var answerList: XCUIElement { app.collectionViews[ID.answerList] }
    var codeList: XCUIElement { app.collectionViews[ID.codeList] }

    /// Gezinme çubuğundaki ✓ düğmesi. `value`'su `studiedValue` ya da `notStudiedValue`.
    var studiedToggle: XCUIElement { app.buttons[ID.studiedToggle] }

    // MARK: Cevap

    var questionLabel: XCUIElement { app.staticTexts[ID.questionLabel] }

    func shortAnswerItem(_ index: Int) -> XCUIElement {
        app.staticTexts[ID.shortAnswerItem(index)]
    }

    /// Ek sorunun açılır-kapanır başlığı (`DisclosureGroup` → düğme).
    func followUp(_ index: Int) -> XCUIElement {
        app.buttons[ID.followUp(index)]
    }

    /// Başlığa dokununca görünen cevap. Kapalıyken ağaçta yoktur.
    func followUpAnswer(_ index: Int) -> XCUIElement {
        app.staticTexts[ID.followUpAnswer(index)]
    }

    // MARK: Kod

    func codePointer(_ index: Int) -> XCUIElement {
        app.descendants(matching: .any)[ID.codePointer(index)]
    }

    func copyFileNameButton(_ index: Int) -> XCUIElement {
        app.buttons[ID.copyFileNameButton(index)]
    }

    var codeHint: XCUIElement { app.staticTexts[ID.codeHint] }

    // MARK: Eylemler

    @discardableResult
    func showAnswer() -> Self {
        panePicker.buttons[ID.answerPane].tap()
        return self
    }

    @discardableResult
    func showDemo() -> Self {
        panePicker.buttons[ID.demoPane].tap()
        return self
    }

    @discardableResult
    func showCode() -> Self {
        panePicker.buttons[ID.codePane].tap()
        return self
    }

    /// Ek soruyu görünür hale getirir ve açar.
    func expandFollowUp(_ index: Int) {
        answerList.scrollUp(toReveal: followUp(index))
        followUp(index).tap()
    }

    func toggleStudied() {
        studiedToggle.tap()
    }

    /// Merkeze geri döner.
    @discardableResult
    func goBack() -> InterviewHubScreen {
        tapBackButton()
        return InterviewHubScreen(app: app)
    }
}
