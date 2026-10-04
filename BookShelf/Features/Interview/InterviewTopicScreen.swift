import SwiftUI

// GEÇİCİ İSKELET (çalışır durumda) — sahibi: hub. Görünümü geliştir; kimlikleri ve davranışı koru:
// - Üstte AccessibilityID.Interview.panePicker kimlikli segmented Picker; etiketler answerPane/demoPane/codePane.
// - Varsayılan bölüm "Cevap". "Demo" seçilince topic.demo(dependencies) TAM EKRAN gösterilir
//   (demo kendi List/Form/ScrollView'unu getirebilir; onu başka bir ScrollView'a gömme).
struct InterviewTopicScreen: View {
    enum Pane: String, CaseIterable {
        case answer, demo, code
        var title: String {
            switch self {
            case .answer: AccessibilityID.Interview.answerPane
            case .demo: AccessibilityID.Interview.demoPane
            case .code: AccessibilityID.Interview.codePane
            }
        }
    }

    let topic: InterviewTopic
    let dependencies: AppDependencies
    @State private var pane: Pane = .answer

    var body: some View {
        VStack(spacing: 0) {
            Picker("Bölüm", selection: $pane) {
                ForEach(Pane.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityIdentifier(AccessibilityID.Interview.panePicker)

            switch pane {
            case .answer:
                List {
                    Section("Kısa cevap") { ForEach(topic.shortAnswer, id: \.self) { Text($0) } }
                }
                .accessibilityIdentifier(AccessibilityID.Interview.answerList)
            case .demo:
                topic.demo(dependencies)
            case .code:
                List {
                    ForEach(topic.codePointers, id: \.self) { pointer in
                        VStack(alignment: .leading) {
                            Text(pointer.symbol).font(.headline)
                            Text(pointer.file).font(.caption.monospaced())
                            Text(pointer.note).font(.caption)
                        }
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Interview.codeList)
            }
        }
        .navigationTitle(topic.question)
        .navigationBarTitleDisplayMode(.inline)
    }
}
