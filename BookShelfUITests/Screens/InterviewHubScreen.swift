import XCTest

/// "Mülakat" sekmesinin giriş ekranı (`InterviewHubView`): her mülakat sorusu bir satır.
///
/// Liste uzun ve tembel (lazy) olduğu için alttaki satırlar ekrana kaydırılmadan erişilebilirlik ağacında yoktur.
/// `openTopic(_:)` bu yüzden önce satırı görünür hale getirene kadar kaydırır, sonra dokunur.
@MainActor
struct InterviewHubScreen: Screen {
    private typealias ID = AccessibilityID.Interview

    let app: XCUIApplication

    var rootElement: XCUIElement { app.collectionViews[ID.hubList] }

    func row(_ topicID: String) -> XCUIElement {
        app.buttons[ID.topicRow(topicID)]
    }

    /// Konu satırını bulup açar ve konu ekranının görünmesini bekler.
    /// - Parameter topicID: `AccessibilityID.Interview.TopicID` sabitlerinden biri.
    func openTopic(_ topicID: String, file: StaticString = #filePath, line: UInt = #line) -> InterviewTopicScreen {
        let target = row(topicID)
        XCTAssertTrue(
            rootElement.scrollUp(toReveal: target, maxSwipes: 12),
            "Mülakat merkezinde '\(topicID)' satırı bulunamadı.",
            file: file, line: line
        )
        target.tap()
        return InterviewTopicScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }
}
