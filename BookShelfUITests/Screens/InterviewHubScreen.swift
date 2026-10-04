import XCTest

/// "Mülakat" sekmesinin giriş ekranı (`InterviewHubView`): en üstte ilerleme, altında bölüm bölüm konu satırları.
///
/// Liste uzun ve tembel (lazy) olduğu için alttaki satırlar ekrana kaydırılmadan erişilebilirlik ağacında yoktur.
/// `openTopic(_:)` bu yüzden önce satırı görünür hale getirene kadar kaydırır, sonra dokunur.
@MainActor
struct InterviewHubScreen: Screen {
    private typealias ID = AccessibilityID.Interview

    let app: XCUIApplication

    var rootElement: XCUIElement { app.collectionViews[ID.hubList] }

    /// "5 / 16 konu çalışıldı". Listenin en üstünde; liste aşağı kaydırıldıysa ağaçta olmayabilir.
    var progressLabel: XCUIElement { app.staticTexts[ID.progressLabel] }
    /// Yalnızca en az bir konu çalışıldıysa görünür.
    var resetProgressButton: XCUIElement { app.buttons[ID.resetProgressButton] }

    /// Bölüm başlığının metni. `sectionKey`: `AccessibilityID.Interview.SectionKey` sabitlerinden biri.
    func sectionHeader(_ sectionKey: String) -> XCUIElement {
        app.staticTexts[ID.sectionHeader(sectionKey)]
    }

    /// Konu satırı. `value`'su `studiedValue` ya da `notStudiedValue`.
    func row(_ topicID: String) -> XCUIElement {
        app.buttons[ID.topicRow(topicID)]
    }

    /// `element` görünür ve dokunulabilir olana kadar listeyi yukarı kaydırır.
    @discardableResult
    func reveal(_ element: XCUIElement, maxSwipes: Int = 12) -> Bool {
        rootElement.scrollUp(toReveal: element, maxSwipes: maxSwipes)
    }

    /// Konu satırını bulup açar ve konu ekranının görünmesini bekler.
    /// - Parameter topicID: `AccessibilityID.Interview.TopicID` sabitlerinden biri.
    func openTopic(_ topicID: String, file: StaticString = #filePath, line: UInt = #line) -> InterviewTopicScreen {
        let target = row(topicID)
        XCTAssertTrue(
            reveal(target),
            "Mülakat merkezinde '\(topicID)' satırı bulunamadı.",
            file: file, line: line
        )
        target.tap()
        return InterviewTopicScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }

    /// Satırı sağa kaydırır ve soldan çıkan "Çalışıldı" / "İşareti kaldır" eylem düğmesini döndürür.
    /// Dokunmak (ve sonucu doğrulamak) testin işi.
    func swipeToRevealStudiedAction(_ topicID: String) -> XCUIElement {
        let target = row(topicID)
        reveal(target)
        target.swipeRight()
        return app.buttons[ID.swipeStudiedAction]
    }
}
