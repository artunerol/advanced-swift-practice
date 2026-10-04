import XCTest

/// Mülakat sekmesindeki Swift temelleri demoları: protocol quiz'i, struct vs class "Bellek" deneyi,
/// typealias ve protocol + extension (dispatch).
///
/// Her test bir demonun ASIL iddiasını doğrular: quiz cevabı açıp skoru güncelliyor mu, struct kopyaları gerçekten
/// farklı adreste mi, typealias gerçekten aynı tip mi, dispatch derleme anındaki tipe göre değişiyor mu?
final class SwiftBasicsUITests: BookShelfUITestCase {
    private typealias TopicID = AccessibilityID.Interview.TopicID

    /// Uygulamayı açar, Mülakat sekmesinde konuyu bulur, "Demo" bölümüne geçer ve demo ekranını bekler.
    @MainActor
    private func openSwiftBasicsDemo<S: Screen>(
        _ topicID: String,
        as screenType: S.Type,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> S {
        let app = launchApp(file: file, line: line)
        TabBarScreen(app: app).openInterview().waitUntilDisplayed(file: file, line: line)
            .openTopic(topicID, file: file, line: line)
            .showDemo()
        return screenType.init(app: app).waitUntilDisplayed(file: file, line: line)
    }

    // MARK: - Protocol tip olarak: quiz

    @MainActor
    func testQuizRevealsTheAnswerAndUpdatesTheScore() {
        let quiz = openSwiftBasicsDemo(TopicID.protocolAsType, as: ProtocolQuizScreen.self)

        XCTContext.runActivity(named: "Başlangıç: ilk soru, skor 0/0, sonuç kartı yok") { _ in
            assertLabel(quiz.progress, equals: "Soru 1/16")
            assertLabel(quiz.score, equals: "Skor: 0/0")
            XCTAssertFalse(quiz.verdict.exists)
        }

        XCTContext.runActivity(named: "1. soru ([any ReadingItem]) derlenir → 'Olur' doğru") { _ in
            quiz.answerCompiles()
            assertLabel(quiz.verdict, equals: "Doğru ✓")
            assertLabel(quiz.correctAnswer, equals: "Doğru cevap: Derlenir")
            assertLabel(quiz.score, equals: "Skor: 1/1")
            XCTAssertFalse(quiz.compilesButton.isEnabled, "Bir soru yalnızca bir kez cevaplanabilir")
        }

        XCTContext.runActivity(named: "2. soru (let value: Equatable) uyarıyla derlenir → 'Olmaz' yanlış") { _ in
            quiz.goToNextQuestion()
            assertLabel(quiz.progress, equals: "Soru 2/16")
            assertDisappears(quiz.verdict)

            quiz.answerFails()
            assertLabel(quiz.verdict, equals: "Yanlış ✗")
            assertLabel(quiz.correctAnswer, equals: "Doğru cevap: Derlenir, ama uyarı verir")
            // Mesaj paketteki dosyadan geliyor; scripts/check-swift-quiz.sh aynı mesajı derleyiciden doğruluyor.
            assertLabel(quiz.compilerMessage, contains: "must be written 'any Equatable'")
            assertLabel(quiz.score, equals: "Skor: 1/2")
        }
    }

    // MARK: - Struct vs class: Bellek deneyi

    @MainActor
    func testMemoryExperimentShowsCopiesAtDifferentAddressesAndSharedReferences() {
        let screen = openSwiftBasicsDemo(TopicID.structVsClass, as: StructVsClassScreen.self)
        screen.selectExperiment(AccessibilityID.Fundamentals.StructVsClass.memorySegment)

        XCTContext.runActivity(named: "struct kopyası ayrı adreste, aynı nesneye iki referans aynı adreste") { _ in
            assertLabel(screen.structCopiesVerdict, equals: "Aynı adres mi? Hayır")
            assertLabel(screen.sharedReferenceVerdict, equals: "Aynı adres mi? Evet")
            assertLabel(screen.separateObjectsVerdict, equals: "Aynı adres mi? Hayır")
        }

        XCTContext.runActivity(named: "MemoryLayout: class referansı 8, existential 40 bayt") { _ in
            assertLabel(screen.revealLayoutRow("class"), equals: "size 8 · stride 8")
            assertLabel(screen.revealLayoutRow("existential"), equals: "size 40 · stride 40")
        }
    }

    // MARK: - typealias

    @MainActor
    func testTypealiasDemoShowsThatAnAliasIsNotANewType() {
        let screen = openSwiftBasicsDemo(TopicID.typealiasTopic, as: TypealiasDemoScreen.self)

        XCTContext.runActivity(named: "Closure alias'ı: süzgeç değişince sonuç değişir") { _ in
            screen.filterPicker.buttons["< 200 sayfa"].tap()
            assertLabel(screen.filterResult, equals: "2 kitap: Kürk Mantolu Madonna, Aylak Adam")
        }

        XCTContext.runActivity(named: "Generic alias çalışma anında düz bir Dictionary") { _ in
            assertLabel(screen.reveal(screen.genericAliasType), equals: "BookMap<String> aslında: Dictionary<Int, String>")
        }

        XCTContext.runActivity(named: "Tuzak: BookID ile MemberID aynı tip, sarmalayıcı ayrı tip") { _ in
            assertLabel(screen.reveal(screen.bookIDUnderlyingType), equals: "BookID aslında: Int")
            assertLabel(screen.reveal(screen.aliasesAreSameType), equals: "BookID ile MemberID aynı tip mi? Evet")
            assertLabel(screen.reveal(screen.wrapperIsDistinctType), equals: "LibraryCardNumber ile Int aynı tip mi? Hayır")
        }
    }

    // MARK: - Protocol + extension: dispatch

    @MainActor
    func testExtensionOnlyMemberFollowsTheCompileTimeType() {
        let screen = openSwiftBasicsDemo(TopicID.protocolExtension, as: ProtocolExtensionDemoScreen.self)

        XCTContext.runActivity(named: "Magazine olarak: Magazine'in kendi shelfSection'ı") { _ in
            assertLabel(screen.extensionOnlyResult, equals: "shelfSection (yalnız extension): Süreli yayınlar")
            assertLabel(screen.requirementResult, equals: "symbolName (gereksinim): newspaper")
        }

        XCTContext.runActivity(named: "any ReadingItem olarak: extension'daki varsayılan; gereksinim değişmez") { _ in
            screen.viewpointPicker.buttons["any"].tap()
            assertLabel(screen.extensionOnlyResult, equals: "shelfSection (yalnız extension): Genel raf")
            assertLabel(screen.requirementResult, equals: "symbolName (gereksinim): newspaper")
        }
    }
}

// MARK: - Ekran nesneleri (yalnızca bu dosyadaki testler kullanıyor)

/// typealias demosu (`TypealiasDemoView`). Uzun bir `List`; alttaki satırlar için `reveal(_:)` önce kaydırır.
@MainActor
private struct TypealiasDemoScreen: Screen {
    private typealias ID = AccessibilityID.Fundamentals.Typealias

    let app: XCUIApplication

    var rootElement: XCUIElement { list }

    var list: XCUIElement { app.collectionViews[ID.list] }
    var filterPicker: XCUIElement { app.segmentedControls[ID.filterPicker] }
    var filterResult: XCUIElement { app.staticTexts[ID.filterResult] }
    var genericAliasType: XCUIElement { app.staticTexts[ID.genericAliasType] }
    var bookIDUnderlyingType: XCUIElement { app.staticTexts[ID.bookIDUnderlyingType] }
    var aliasesAreSameType: XCUIElement { app.staticTexts[ID.aliasesAreSameType] }
    var wrapperIsDistinctType: XCUIElement { app.staticTexts[ID.wrapperIsDistinctType] }

    func reveal(_ element: XCUIElement) -> XCUIElement {
        list.scrollUp(toReveal: element)
        return element
    }
}

/// Protocol + extension demosu (`ProtocolExtensionDemoView`), varsayılan bölüm "Dispatch".
@MainActor
private struct ProtocolExtensionDemoScreen: Screen {
    private typealias ID = AccessibilityID.Fundamentals.ProtocolExtension

    let app: XCUIApplication

    var rootElement: XCUIElement { viewpointPicker }

    /// Değişkenin derleme anındaki tipi; düğmeler görünen etiketleriyle seçilir: "Magazine", "any", "some".
    var viewpointPicker: XCUIElement { app.segmentedControls[ID.viewpointPicker] }
    var requirementResult: XCUIElement { app.staticTexts[ID.requirementResult] }
    var extensionOnlyResult: XCUIElement { app.staticTexts[ID.extensionOnlyResult] }
}
