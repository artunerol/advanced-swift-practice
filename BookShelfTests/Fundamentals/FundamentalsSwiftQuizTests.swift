import XCTest
@testable import BookShelf

/// "Olur mu, olmaz mı?" quiz'i: paketteki örnekler, dosya biçimi (parser) ve skor mantığı (`SwiftQuizSession`).
///
/// Örneklerin DOĞRU cevaplarını bu testler değil, `scripts/check-swift-quiz.sh` doğrular (örnekleri gerçekten derleyerek).
/// Buradaki testler, uygulamanın o dosyaları eksiksiz okuyup doğru gösterdiğinden emin olur.
final class FundamentalsSwiftQuizTests: XCTestCase {

    // MARK: - Paketteki örnekler

    func testBundledLibraryLoadsAllSnippetsInOrder() throws {
        let library = try SwiftQuizLibrary.load(from: .main)

        XCTAssertEqual(library.snippets.count, 16)
        XCTAssertEqual(library.snippets.map(\.number), Array(1...16), "Numaralar 01'den başlayıp boşluksuz artmalı")
        XCTAssertEqual(Set(library.snippets.map(\.id)).count, library.snippets.count, "Kimlikler benzersiz olmalı")
        XCTAssertTrue(library.prelude.contains("protocol Shelf<Item>"), "Ortak tanımlar (prelude) da yüklenmeli")
    }

    func testEveryBundledSnippetHasTitleExplanationAndCode() throws {
        for snippet in try SwiftQuizLibrary.load(from: .main).snippets {
            XCTAssertFalse(snippet.title.isEmpty, snippet.id)
            XCTAssertFalse(snippet.explanation.isEmpty, snippet.id)
            XCTAssertFalse(snippet.explanation.contains(where: \.isEmpty), snippet.id)
            XCTAssertFalse(snippet.code.isEmpty, snippet.id)
            XCTAssertFalse(snippet.code.contains("// EXPECT:"), "Başlık satırları koda karışmamalı: \(snippet.id)")
            if let message = snippet.outcome.compilerMessage {
                XCTAssertGreaterThan(message.count, "error: ".count, snippet.id)
            }
        }
    }

    func testBundledQuizMixesCompilingAndFailingSnippets() throws {
        let outcomes = try SwiftQuizLibrary.load(from: .main).snippets.map(\.outcome)
        let compiling = outcomes.filter(\.compiles).count

        // Hep "Olur" ya da hep "Olmaz" olan bir quiz ezberle geçilirdi.
        XCTAssertGreaterThanOrEqual(compiling, 5)
        XCTAssertGreaterThanOrEqual(outcomes.count - compiling, 5)
        XCTAssertTrue(outcomes.contains { if case .compilesWithWarning = $0 { true } else { false } })
    }

    func testCachedLibraryMatchesAFreshLoad() throws {
        let cached = try SwiftQuizLibrary.bundled.get()
        let fresh = try SwiftQuizLibrary.load(from: .main)
        XCTAssertEqual(cached.snippets, fresh.snippets)
    }

    // MARK: - Parser

    func testParserReadsHeadersAndCode() throws {
        let snippet = try SwiftQuizParser.parse(fileName: "quiz-07-sample", contents: """
        // TITLE: Örnek soru
        // EXPECT: compiles
        // EXPLAIN: Birinci paragraf.
        // EXPLAIN: İkinci paragraf.

        let x: any ReadingItem = Novel(title: "A")

        """)

        XCTAssertEqual(snippet.id, "quiz-07-sample")
        XCTAssertEqual(snippet.number, 7)
        XCTAssertEqual(snippet.title, "Örnek soru")
        XCTAssertEqual(snippet.outcome, .compiles)
        XCTAssertEqual(snippet.explanation, ["Birinci paragraf.", "İkinci paragraf."])
        XCTAssertNil(snippet.compilerFlags)
        XCTAssertEqual(snippet.code, "let x: any ReadingItem = Novel(title: \"A\")", "Boş satırlar kırpılmalı")
    }

    func testParserReadsWarningsErrorsAndFlags() throws {
        let warning = try SwiftQuizParser.parse(fileName: "quiz-01-a", contents: """
        // TITLE: T
        // FLAGS: -enable-upcoming-feature ExistentialAny
        // EXPECT: warning: must be written 'any P'
        // EXPLAIN: E
        let x = 1
        """)
        XCTAssertEqual(warning.outcome, .compilesWithWarning("must be written 'any P'"))
        XCTAssertEqual(warning.outcome.compilerMessage, "warning: must be written 'any P'")
        XCTAssertEqual(warning.compilerFlags, "-enable-upcoming-feature ExistentialAny")

        let error = try SwiftQuizParser.parse(fileName: "quiz-02-b", contents: """
        // TITLE: T
        // EXPECT: error: extensions must not contain stored properties
        // EXPLAIN: E
        extension Novel { var rating = 0 }
        """)
        XCTAssertEqual(error.outcome, .fails("extensions must not contain stored properties"))
        XCTAssertEqual(error.outcome.compilerMessage, "error: extensions must not contain stored properties")
    }

    func testOrdinaryCommentsStayInTheCode() throws {
        // "// Not:" bir başlık değil (anahtar büyük harf değil); kodun parçası olarak kalmalı.
        let snippet = try SwiftQuizParser.parse(fileName: "quiz-03-c", contents: """
        // TITLE: T
        // EXPECT: compiles
        // EXPLAIN: E
        // Not: bu satır koda ait
        let x = 1
        """)
        XCTAssertEqual(snippet.code, "// Not: bu satır koda ait\nlet x = 1")
    }

    func testParserRejectsBrokenFiles() {
        let valid = "// TITLE: T\n// EXPECT: compiles\n// EXPLAIN: E\nlet x = 1"

        XCTAssertThrowsError(try SwiftQuizParser.parse(fileName: "quiz-1-short", contents: valid)) { error in
            XCTAssertEqual(error as? SwiftQuizParseError, .invalidFileName("quiz-1-short"))
        }
        XCTAssertThrowsError(try SwiftQuizParser.parse(fileName: "quiz-04-d", contents: "// TITLE: T\n// EXPECT: compiles\nlet x = 1")) { error in
            XCTAssertEqual(error as? SwiftQuizParseError, .missingHeader(key: "EXPLAIN", file: "quiz-04-d"))
        }
        XCTAssertThrowsError(try SwiftQuizParser.parse(fileName: "quiz-05-e", contents: "// TITLE: T\n// EXPECT: maybe\n// EXPLAIN: E\nlet x = 1")) { error in
            XCTAssertEqual(error as? SwiftQuizParseError, .unknownExpectation("maybe", file: "quiz-05-e"))
        }
        XCTAssertThrowsError(try SwiftQuizParser.parse(fileName: "quiz-06-f", contents: "// TITLE: T\n// EXPLAN: typo\nlet x = 1")) { error in
            XCTAssertEqual(error as? SwiftQuizParseError, .unknownHeader(key: "EXPLAN", file: "quiz-06-f"))
        }
        XCTAssertThrowsError(try SwiftQuizParser.parse(fileName: "quiz-07-g", contents: "// TITLE: T\n// EXPECT: compiles\n// EXPLAIN: E\n\n")) { error in
            XCTAssertEqual(error as? SwiftQuizParseError, .emptyCode(file: "quiz-07-g"))
        }
    }

    // MARK: - Skor ve gezinme (SwiftQuizSession)

    func testAnsweringUpdatesTheScore() {
        var session = SwiftQuizSession(snippets: Self.sampleSnippets)
        XCTAssertEqual(session.answeredCount, 0)

        session.answerCurrent(compiles: true)          // 1. soru derleniyor → doğru
        session.goForward()
        session.answerCurrent(compiles: true)          // 2. soru derlenmiyor → yanlış

        XCTAssertEqual(session.answeredCount, 2)
        XCTAssertEqual(session.correctCount, 1)
        XCTAssertEqual(session.isCorrect(Self.sampleSnippets[0]), true)
        XCTAssertEqual(session.isCorrect(Self.sampleSnippets[1]), false)
        XCTAssertNil(session.isCorrect(Self.sampleSnippets[2]), "Cevaplanmayan sorunun doğruluğu yok")
    }

    func testAQuestionCanOnlyBeAnsweredOnce() {
        var session = SwiftQuizSession(snippets: Self.sampleSnippets)

        session.answerCurrent(compiles: false)         // yanlış
        session.answerCurrent(compiles: true)          // yok sayılmalı

        XCTAssertEqual(session.answer(for: Self.sampleSnippets[0]), false)
        XCTAssertEqual(session.correctCount, 0)
        XCTAssertEqual(session.answeredCount, 1)
    }

    func testCompilingWithAWarningCountsAsCompiles() {
        var session = SwiftQuizSession(snippets: Self.sampleSnippets)
        session.goForward()
        session.goForward()                            // 3. soru: uyarıyla derlenir

        session.answerCurrent(compiles: true)

        XCTAssertEqual(session.isCorrect(Self.sampleSnippets[2]), true)
        XCTAssertEqual(SwiftQuizSnippet.Outcome.compilesWithWarning("w").summary, "Derlenir, ama uyarı verir")
    }

    func testNavigationStaysWithinBounds() {
        var session = SwiftQuizSession(snippets: Self.sampleSnippets)
        XCTAssertFalse(session.canGoBack)

        session.goBack()
        XCTAssertEqual(session.currentIndex, 0)

        for _ in 0..<10 { session.goForward() }
        XCTAssertEqual(session.currentIndex, Self.sampleSnippets.count - 1)
        XCTAssertFalse(session.canGoForward)
        XCTAssertEqual(session.current, Self.sampleSnippets.last)
    }

    func testFinishingAndRestarting() {
        var session = SwiftQuizSession(snippets: Self.sampleSnippets)
        for index in Self.sampleSnippets.indices {
            session.answerCurrent(compiles: Self.sampleSnippets[index].outcome.compiles)
            session.goForward()
        }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.correctCount, Self.sampleSnippets.count)

        session.restart()

        XCTAssertFalse(session.isFinished)
        XCTAssertEqual(session.answeredCount, 0)
        XCTAssertEqual(session.currentIndex, 0)
    }

    func testEmptySessionHasNoCurrentQuestion() {
        let session = SwiftQuizSession(snippets: [])
        XCTAssertNil(session.current)
        XCTAssertFalse(session.isFinished)
        XCTAssertFalse(session.canGoForward)
    }

    // MARK: - Yardımcı

    private static let sampleSnippets: [SwiftQuizSnippet] = [
        makeSnippet(number: 1, outcome: .compiles),
        makeSnippet(number: 2, outcome: .fails("x")),
        makeSnippet(number: 3, outcome: .compilesWithWarning("y")),
    ]

    private static func makeSnippet(number: Int, outcome: SwiftQuizSnippet.Outcome) -> SwiftQuizSnippet {
        SwiftQuizSnippet(
            id: "quiz-0\(number)-sample",
            number: number,
            title: "Soru \(number)",
            outcome: outcome,
            explanation: ["Açıklama"],
            compilerFlags: nil,
            code: "let x = \(number)"
        )
    }
}
