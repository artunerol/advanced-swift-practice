import SwiftUI

/// "Protocol tip olarak: olur mu, olmaz mı?" quiz'i.
///
/// Her soruda bir kod parçası gösterilir; kullanıcı "Olur ✓" (derlenir) ya da "Olmaz ✗" (derlenmez) der.
/// Ardından doğru cevap, derleyicinin BİREBİR mesajı ve açıklama açılır. Örnekler paketteki `.swift.txt`
/// dosyalarından gelir (bkz. `SwiftQuizLibrary`); aynı dosyaları `scripts/check-swift-quiz.sh` gerçekten derler.
///
/// Kendi `NavigationStack`'ini içermez; konu ekranının (`InterviewTopicScreen`) içinde tam yükseklikte gösterilir.
struct SwiftQuizView: View {
    var body: some View {
        switch SwiftQuizLibrary.bundled {
        case .success(let library):
            SwiftQuizContent(library: library)
        case .failure(let error):
            ContentUnavailableView(
                "Quiz yüklenemedi",
                systemImage: "exclamationmark.triangle",
                description: Text(verbatim: String(describing: error))
            )
            .accessibilityIdentifier(AccessibilityID.Fundamentals.ProtocolQuiz.loadError)
        }
    }
}

/// Kütüphane yüklendikten sonraki asıl quiz ekranı. Ayrı bir view, çünkü `@State` başlangıç değeri
/// (`SwiftQuizSession`) yüklenen örneklere bağlı.
private struct SwiftQuizContent: View {
    private typealias ID = AccessibilityID.Fundamentals.ProtocolQuiz

    /// `ScrollViewReader` ile kaydırılacak yerlerin kimlikleri (erişilebilirlik kimliği değil, SwiftUI `.id`).
    private enum ScrollTarget: Hashable {
        case top, result
    }

    let library: SwiftQuizLibrary
    @State private var session: SwiftQuizSession
    @State private var showsPrelude = false

    init(library: SwiftQuizLibrary) {
        self.library = library
        // `@State`'in başlangıç değeri yalnızca view'un kimliği ilk oluştuğunda kullanılır; sonraki çizimlerde
        // SwiftUI sakladığı değeri verir. Bu yüzden init'te `_session = State(initialValue:)` yazmak güvenli.
        _session = State(initialValue: SwiftQuizSession(snippets: library.snippets))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let snippet = session.current {
                    question(snippet)
                        .padding()
                }
            }
            // Cevap düğmeleri her zaman ekranın altında, kodu kaydırsan da görünür ve dokunulabilir kalır.
            .safeAreaInset(edge: .bottom) { controlBar }
            .onChange(of: session.answeredCount) {
                withAnimation { proxy.scrollTo(ScrollTarget.result, anchor: .top) }
            }
            .onChange(of: session.currentIndex) {
                proxy.scrollTo(ScrollTarget.top, anchor: .top)
            }
        }
        .navigationTitle("Olur mu, olmaz mı?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Baştan") { session.restart() }
                    .accessibilityIdentifier(ID.restartButton)
            }
        }
    }

    // MARK: - Soru

    private func question(_ snippet: SwiftQuizSnippet) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(verbatim: "Soru \(session.currentIndex + 1)/\(session.snippets.count)")
                    .accessibilityIdentifier(ID.progress)
                Spacer()
                Text(verbatim: "Skor: \(session.correctCount)/\(session.answeredCount)")
                    .bold()
                    .accessibilityIdentifier(ID.score)
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .id(ScrollTarget.top)

            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.title)
                    .font(.headline)
                    .accessibilityIdentifier(ID.snippetTitle)
                Text("Bu kod derlenir mi? (Swift 6 dil modu)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let flags = snippet.compilerFlags {
                Label {
                    Text(verbatim: "Derleyici ayarı: \(flags)")
                } icon: {
                    Image(systemName: "gearshape")
                }
                .font(.footnote.monospaced())
                .accessibilityIdentifier(ID.compilerFlags)
            }

            QuizCodeBlock(code: snippet.code)
                .accessibilityIdentifier(ID.code)

            DisclosureGroup("Ortak tanımlar (her örneğin başına eklenir)", isExpanded: $showsPrelude) {
                QuizCodeBlock(code: library.prelude)
                    .padding(.top, 8)
            }
            .font(.footnote)

            if let userSaysCompiles = session.answer(for: snippet) {
                result(for: snippet, userSaysCompiles: userSaysCompiles)
                    .id(ScrollTarget.result)
            }

            NavigationLink {
                ProtocolsView()
            } label: {
                Label("Çalışan örnek: [any ReadingItem] listesi ve Shelf<Novel> rafı", systemImage: "play.rectangle")
                    .font(.footnote)
            }
            .accessibilityIdentifier(ID.liveExampleLink)
        }
    }

    private func result(for snippet: SwiftQuizSnippet, userSaysCompiles: Bool) -> some View {
        let isCorrect = userSaysCompiles == snippet.outcome.compiles
        return VStack(alignment: .leading, spacing: 10) {
            Text(isCorrect ? "Doğru ✓" : "Yanlış ✗")
                .font(.title3.bold())
                .foregroundStyle(isCorrect ? Color.green : Color.red)
                .accessibilityIdentifier(ID.verdict)

            Text(verbatim: "Doğru cevap: \(snippet.outcome.summary)")
                .font(.headline)
                .accessibilityIdentifier(ID.correctAnswer)

            if let message = snippet.outcome.compilerMessage {
                Text(message)
                    .font(.caption.monospaced())
                    .foregroundStyle(snippet.outcome.compiles ? Color.orange : Color.red)
                    .accessibilityIdentifier(ID.compilerMessage)
            }

            Text(snippet.explanation.joined(separator: "\n\n"))
                .font(.callout)
                .accessibilityIdentifier(ID.explanation)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Alt çubuk

    private var controlBar: some View {
        let isAnswered = session.current.map { session.answer(for: $0) != nil } ?? true
        return HStack(spacing: 12) {
            Button {
                session.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Önceki soru")
            .disabled(!session.canGoBack)
            .accessibilityIdentifier(ID.previousButton)

            Spacer(minLength: 0)

            Button("Olur ✓") { session.answerCurrent(compiles: true) }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isAnswered)
                .accessibilityIdentifier(ID.compilesButton)

            Button("Olmaz ✗") { session.answerCurrent(compiles: false) }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isAnswered)
                .accessibilityIdentifier(ID.failsButton)

            Spacer(minLength: 0)

            Button {
                session.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Sonraki soru")
            .disabled(!session.canGoForward)
            .accessibilityIdentifier(ID.nextButton)
        }
        .font(.body.weight(.semibold))
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// Eş aralıklı (monospaced) yazıyla kod gösterir. Uzun satırlar kelime kaydırmasıyla bozulmasın diye yatay kayar.
private struct QuizCodeBlock: View {
    let code: String

    var body: some View {
        ScrollView(.horizontal) {
            // `Text(String)` metni olduğu gibi gösterir (yerelleştirme ya da Markdown yorumu yapmaz).
            Text(code)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
                .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        SwiftQuizView()
    }
}
