import Foundation

/// Quiz'in durumu: hangi sorudayız, hangi soruya ne cevap verildi, skor kaç.
///
/// Saf bir değer tipi (struct): SwiftUI'dan bağımsız olduğu için birim testlerle doğrudan sınanır. Ekran onu
/// `@State` içinde tutar; `mutating` metotlar değeri yerinde değiştirir ve SwiftUI ekranı yeniden çizer.
struct SwiftQuizSession: Sendable {
    let snippets: [SwiftQuizSnippet]
    private(set) var currentIndex = 0
    /// Soru kimliği → kullanıcının cevabı (`true` = "Olur", yani derlenir dedi).
    private(set) var answers: [SwiftQuizSnippet.ID: Bool] = [:]

    init(snippets: [SwiftQuizSnippet]) {
        self.snippets = snippets
    }

    var current: SwiftQuizSnippet? {
        snippets.indices.contains(currentIndex) ? snippets[currentIndex] : nil
    }

    // MARK: Cevaplar ve skor

    /// Kullanıcının bu soruya cevabı; cevaplanmadıysa `nil`.
    func answer(for snippet: SwiftQuizSnippet) -> Bool? {
        answers[snippet.id]
    }

    /// Cevap doğru mu? Cevaplanmadıysa `nil`.
    func isCorrect(_ snippet: SwiftQuizSnippet) -> Bool? {
        answer(for: snippet).map { $0 == snippet.outcome.compiles }
    }

    var answeredCount: Int { answers.count }

    var correctCount: Int {
        // `count(where:)` Swift 6.0 ile geldi; `filter { }.count` gibi ara bir dizi oluşturmaz.
        snippets.count(where: { isCorrect($0) == true })
    }

    var isFinished: Bool {
        !snippets.isEmpty && answeredCount == snippets.count
    }

    /// O anki soruyu cevaplar. Bir soru yalnızca BİR kez cevaplanabilir: Cevap görüldükten sonra değiştirmek
    /// skoru anlamsız kılardı. İkinci çağrı yok sayılır.
    mutating func answerCurrent(compiles: Bool) {
        guard let current, answers[current.id] == nil else { return }
        answers[current.id] = compiles
    }

    // MARK: Gezinme

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < snippets.count - 1 }

    mutating func goBack() {
        if canGoBack { currentIndex -= 1 }
    }

    mutating func goForward() {
        if canGoForward { currentIndex += 1 }
    }

    /// Cevapları siler ve ilk soruya döner.
    mutating func restart() {
        answers = [:]
        currentIndex = 0
    }
}
