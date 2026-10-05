import XCTest

/// Kitap Arama VIPER modülünün uçtan uca testi: gerçek servis (`LocalBookService`, `-ui-testing` ile gecikmesiz),
/// gerçek use case'ler, gerçek navigasyon. Birim testlerinin parçaları ayrı ayrı doğruladığı akışın birleşik hali.
///
/// `-ui-testing`: servis gecikmesi 0, debounce 0 (`BookSearchConfiguration.uiTesting`), son aramalar her açılışta
/// sıfırlanan ayrı bir UserDefaults alanında. Testler birbirinden bağımsız ve sabit `sleep` yok; her adım bir koşulu bekler.
final class BookSearchUITests: BookShelfUITestCase {
    private typealias ID = AccessibilityID.BookSearch

    /// Uygulamayı açar, Mülakat sekmesinde konuyu bulur ve "Demo" bölümüne geçer.
    @MainActor
    private func openDemo(
        extraArguments: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> BookSearchScreen {
        let app = launchApp(extraArguments: extraArguments, file: file, line: line)
        TabBarScreen(app: app).openInterview().waitUntilDisplayed(file: file, line: line)
            .openTopic(AccessibilityID.Interview.TopicID.viperService, file: file, line: line)
            .showDemo()
        return BookSearchScreen(app: app).waitUntilDisplayed(file: file, line: line)
    }

    @MainActor
    func testTypingAtayShowsBothBooksAndTappingOneOpensItsDetail() {
        let screen = openDemo()

        XCTContext.runActivity(named: "Kutu boş: ipucu görünür (henüz geçmiş yok)") { _ in
            assertLabel(screen.messageLabel, contains: "en az 2 harf")
        }

        XCTContext.runActivity(named: "\"atay\" yaz: Oğuz Atay'ın iki kitabı listelenir") { _ in
            screen.type("atay")
            assertAppears(screen.resultCell(bookID: 1))
            assertAppears(screen.resultCell(bookID: 6))
            XCTAssertEqual(screen.resultCells.count, 2, "Yalnızca Tutunamayanlar ve Tehlikeli Oyunlar")
            XCTAssertTrue(screen.resultCell(bookID: 1).staticTexts["Tutunamayanlar"].exists)
            XCTAssertTrue(screen.resultCell(bookID: 6).staticTexts["Tehlikeli Oyunlar"].exists)
        }

        XCTContext.runActivity(named: "Satıra dokun: router detay ekranını push eder") { _ in
            let detail = screen.openBook(id: 1)
            assertLabel(detail.title, equals: "Tutunamayanlar")
            assertLabel(detail.author, equals: "Oğuz Atay")
        }

        XCTContext.runActivity(named: "\"Sonuçlara dön\": sonuçlar yerinde duruyor") { _ in
            screen.backToResults()
            assertAppears(screen.resultCell(bookID: 6))
        }
    }

    @MainActor
    func testSwipeInsightsShowsSummaryAndSearchIsRemembered() {
        let screen = openDemo()

        XCTContext.runActivity(named: "Ara ve sola kaydırıp \"Özet\"e dokun") { _ in
            screen.search("tutunamayanlar")
            assertAppears(screen.resultCell(bookID: 1))
            screen.swipeAction(ID.insightsActionTitle, onBook: 1)
        }

        XCTContext.runActivity(named: "Özet: 3 yorum, ortalama ve yazarın başka kitabı") { _ in
            assertAppears(screen.insightsAlert)
            // Yorumlar (4, 5, 3) ve yazar profili paralel yüklendi; LocalBookService deterministik.
            assertAppears(screen.insightsAlert.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "3 yorum · ortalama 4,0 / 5")
            ).firstMatch)
            screen.insightsOKButton.tap()
            assertDisappears(screen.insightsAlert)
        }

        XCTContext.runActivity(named: "Kutuyu temizle: başarılı arama geçmişte en üstte") { _ in
            screen.clear()
            assertAppears(screen.recentCell(0))
            XCTAssertTrue(screen.recentCell(0).staticTexts["tutunamayanlar"].exists)
        }
    }

    /// `-simulate-network-error`: servis her istekte hata fırlatır. Hata mesajı ve "Tekrar dene" görünür.
    ///
    /// Bu test "Tekrar dene"nin aramayı YENİDEN yaptığını kanıtlamaz: Servis her istekte hata verdiği için dokunuştan
    /// önceki ve sonraki ekran aynıdır (düğmenin işlevi boşaltılınca da geçtiği bir mutasyonla görüldü). Bir UI testi
    /// yalnızca gözlenebilen bir farkı doğrulayabilir. Düğmenin zinciri birim testlerinde:
    /// View → Presenter `BookSearchViewControllerTests.testSearchBarAndRetryForwardToPresenter`,
    /// Presenter → Interactor `BookSearchPresenterTests.testSelectingRecentSearchAndRetrySearchImmediately`.
    @MainActor
    func testNetworkErrorShowsMessageAndRetryButton() {
        let screen = openDemo(extraArguments: [LaunchArgument.simulateNetworkError])
        let message = "Bağlantı kurulamadı. Lütfen tekrar deneyin."

        XCTContext.runActivity(named: "Arama hata verir: mesaj ve 'Tekrar dene'") { _ in
            screen.search("atay")
            assertLabel(screen.messageLabel, equals: message)
            assertAppears(screen.retryButton)
            XCTAssertTrue(screen.retryButton.isHittable, "'Tekrar dene' görünür ve dokunulabilir olmalı")
            XCTAssertFalse(screen.resultCell(bookID: 1).exists)
        }

        XCTContext.runActivity(named: "'Tekrar dene'ye dokun: servis hâlâ hata veriyor, ekran hata durumunda kalır") { _ in
            screen.retryButton.tap()
            assertAppears(screen.retryButton)
            assertLabel(screen.messageLabel, equals: message)
            XCTAssertFalse(screen.resultCell(bookID: 1).exists)
        }
    }
}
