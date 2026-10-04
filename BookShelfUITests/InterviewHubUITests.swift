import XCTest

/// Mülakat merkezi: bölümler, konu ekranının Cevap / Kod bölümleri, "çalışıldı" işareti ve Concurrency demosu.
///
/// Konu içerikleri değişebilir; testler metinlere değil kimliklere ve yapıya bakar. İçerik örneği olarak
/// merkezin kendi bonus konusu (Swift Concurrency) kullanılır.
final class InterviewHubUITests: BookShelfUITestCase {
    private typealias ID = AccessibilityID.Interview
    private typealias TopicID = AccessibilityID.Interview.TopicID

    /// Kataloğun büyüklüğü. Uygulama modülünü import edemediğimiz için `InterviewTopic.all.count`'u buradan göremeyiz;
    /// sayıyı birim testi (`InterviewCatalogTests`) de ayrıca doğrular.
    private static let topicCount = 16

    /// Uygulamayı açar ve Mülakat sekmesine geçer.
    @MainActor
    private func openHub(file: StaticString = #filePath, line: UInt = #line) -> InterviewHubScreen {
        TabBarScreen(app: launchApp(file: file, line: line)).openInterview().waitUntilDisplayed(file: file, line: line)
    }

    // MARK: - Merkez

    @MainActor
    func testHubShowsProgressAndSectionsInOrder() {
        let hub = openHub()

        XCTContext.runActivity(named: "En üstte ilerleme: henüz hiçbir konu çalışılmadı") { _ in
            assertLabel(hub.progressLabel, equals: ID.progressText(studied: 0, total: Self.topicCount))
        }

        XCTContext.runActivity(named: "İlk bölüm ve ilk konu görünüyor") { _ in
            assertAppears(hub.sectionHeader(ID.SectionKey.swift))
            assertAppears(hub.row(TopicID.protocolExtension))
            assertValue(hub.row(TopicID.protocolExtension), equals: ID.notStudiedValue)
        }

        XCTContext.runActivity(named: "Aşağı kaydırınca son bölüm ve son konu geliyor") { _ in
            XCTAssertTrue(hub.reveal(hub.sectionHeader(ID.SectionKey.bonus)), "Bonus bölümü bulunamadı.")
            XCTAssertTrue(hub.reveal(hub.row(TopicID.objcInterop)), "Son konu bulunamadı.")
        }
    }

    // MARK: - Konu ekranı

    @MainActor
    func testTopicOpensOnAnswerPaneAndCodePaneListsPointers() {
        let topic = openHub().openTopic(TopicID.concurrency)

        XCTContext.runActivity(named: "Varsayılan bölüm: Cevap (soru + 30 saniyelik cevap)") { _ in
            assertAppears(topic.answerList)
            assertAppears(topic.questionLabel)
            assertAppears(topic.shortAnswerItem(0))
            XCTAssertTrue(topic.panePicker.buttons[ID.answerPane].isSelected, "Varsayılan bölüm 'Cevap' olmalı.")
        }

        XCTContext.runActivity(named: "Ek soru kapalı başlar; dokununca cevabı görünür") { _ in
            XCTAssertFalse(topic.followUpAnswer(0).exists, "Ek sorunun cevabı başta kapalı olmalı.")
            topic.expandFollowUp(0)
            assertAppears(topic.followUpAnswer(0))
        }

        XCTContext.runActivity(named: "Kod bölümü: yönlendirmeler ve kopyala düğmesi") { _ in
            topic.showCode()
            assertAppears(topic.codeList)
            assertAppears(topic.codePointer(0))
            // Panoya yazılanı UI testinden okumak bir izin penceresi açabilir; bu yüzden düğmenin geri bildirimini doğruluyoruz.
            topic.copyFileNameButton(0).tap()
            assertLabel(topic.copyFileNameButton(0), equals: "Kopyalandı")
        }
    }

    // MARK: - Çalışıldı işareti

    @MainActor
    func testMarkingTopicAsStudiedUpdatesHubProgress() {
        let hub = openHub()
        let topicID = TopicID.protocolExtension

        XCTContext.runActivity(named: "Konu ekranında ✓'ye dokun") { _ in
            let topic = hub.openTopic(topicID)
            assertValue(topic.studiedToggle, equals: ID.notStudiedValue)
            topic.toggleStudied()
            assertValue(topic.studiedToggle, equals: ID.studiedValue)
            topic.goBack().waitUntilDisplayed()
        }

        XCTContext.runActivity(named: "Merkez: ilerleme 1 oldu, satır 'Çalışıldı'") { _ in
            assertLabel(hub.progressLabel, equals: ID.progressText(studied: 1, total: Self.topicCount))
            assertValue(hub.row(topicID), equals: ID.studiedValue)
            assertAppears(hub.resetProgressButton)
        }

        XCTContext.runActivity(named: "Satırı sağa kaydırıp işareti kaldır: ilerleme 0'a döner") { _ in
            let action = hub.swipeToRevealStudiedAction(topicID)
            assertAppears(action)
            action.tap()
            assertLabel(hub.progressLabel, equals: ID.progressText(studied: 0, total: Self.topicCount))
            assertValue(hub.row(topicID), equals: ID.notStudiedValue)
        }
    }

    // MARK: - Concurrency demosu

    /// Demo, Laboratuvar sekmesindeki formun aynısı; bu yüzden Laboratuvar'ın page object'i (`LabScreen`) burada da çalışır.
    @MainActor
    func testConcurrencyDemoRunsLabExperimentsInsideTopicScreen() {
        let topic = openHub().openTopic(TopicID.concurrency).showDemo()
        let lab = LabScreen(app: topic.app).waitUntilDisplayed()

        lab.runCounters()

        assertLabel(lab.actorCounterResult, equals: "Actor: 1000 / 1000", timeout: UITestTimeout.longOperation)
        assertLabel(lab.lockedCounterResult, equals: "Kilitli class: 1000 / 1000")
    }
}
