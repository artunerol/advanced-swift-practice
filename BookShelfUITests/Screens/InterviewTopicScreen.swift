import XCTest

/// Bir mülakat konusunun ekranı (`InterviewTopicScreen`): üstte Cevap / Demo / Kod seçicisi.
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
}
