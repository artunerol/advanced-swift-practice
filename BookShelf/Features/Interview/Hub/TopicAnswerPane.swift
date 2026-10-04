import SwiftUI

/// Konu ekranının "Cevap" bölümü: soru → 30 saniyelik cevap → ek sorular → tuzaklar.
///
/// Sıra bilinçli: Mülakatta önce kısa cevabı verirsin, mülakatçı bir maddeyi açmanı ister (ek sorular),
/// bazen de bilerek tuzağa çeker (tuzaklar).
struct TopicAnswerPane: View {
    private typealias ID = AccessibilityID.Interview

    let topic: InterviewTopic

    var body: some View {
        List {
            Section {
                Text(topic.question)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier(ID.questionLabel)
                    .accessibilityAddTraits(.isHeader)
            }

            shortAnswerSection

            if !topic.followUps.isEmpty {
                followUpsSection
            }

            if !topic.pitfalls.isEmpty {
                pitfallsSection
            }
        }
        .accessibilityIdentifier(ID.answerList)
    }

    // MARK: - Bölümler

    private var shortAnswerSection: some View {
        Section {
            // `enumerated()` → (offset, element). Kimlik olarak `offset` kullanıyoruz: Aynı metin iki kez geçse bile
            // satırlar ayrışır ve madde numarası da zaten bu sıradan gelir.
            ForEach(Array(topic.shortAnswer.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.tint)
                        // Numara görsel bir yardım; VoiceOver maddeleri zaten sırayla okur.
                        .accessibilityHidden(true)
                    Text(interviewMarkdown: item)
                        .accessibilityIdentifier(ID.shortAnswerItem(index))
                }
            }
        } header: {
            Text("30 saniyelik cevap")
        } footer: {
            Text("Maddeleri ezberleme; sırayla, kendi cümlelerinle anlat. Sonra Demo'da göster, Kod'da nerede olduğunu söyle.")
        }
    }

    private var followUpsSection: some View {
        Section {
            ForEach(Array(topic.followUps.enumerated()), id: \.offset) { index, followUp in
                // `DisclosureGroup`: Cevap kapalı başlar. Önce kendin cevaplamayı dene, sonra aç ve karşılaştır.
                DisclosureGroup {
                    Text(interviewMarkdown: followUp.answer)
                        .accessibilityIdentifier(ID.followUpAnswer(index))
                } label: {
                    // Kimlik etikette, `DisclosureGroup`'un kendisinde DEĞİL: Dıştaki bir `.accessibilityIdentifier`
                    // içerideki öğelere de uygulanır ve açılan cevabın kendi kimliğini ezerdi.
                    Text(interviewMarkdown: followUp.question)
                        .font(.body.weight(.semibold))
                        .accessibilityIdentifier(ID.followUp(index))
                }
            }
        } header: {
            Text("Ek sorular")
        } footer: {
            Text("Önce sesli cevapla, sonra aç.")
        }
    }

    private var pitfallsSection: some View {
        Section("Tuzaklar") {
            ForEach(Array(topic.pitfalls.enumerated()), id: \.offset) { index, pitfall in
                Label {
                    Text(interviewMarkdown: pitfall)
                        .accessibilityIdentifier(ID.pitfall(index))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TopicAnswerPane(topic: .concurrency)
    }
}
