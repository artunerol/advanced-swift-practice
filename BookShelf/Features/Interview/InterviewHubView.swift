import SwiftUI

/// "Mülakat" sekmesi: sık sorulan mülakat soruları, bölüm bölüm.
///
/// Her satır bir `InterviewTopic`: dokununca konu ekranı açılır (Cevap / Demo / Kod).
/// Ekran hiçbir konunun ayrıntısını bilmez; yalnızca `InterviewTopic.all` listesini gösterir.
///
/// Durum:
/// - `studied` (`@AppStorage`): Hangi konuların "çalışıldı" olduğu. `UserDefaults`'ta saklanır; uygulama kapansa da kalır.
///   Ayrıntı ve UI testlerinde neden her açılışta sıfırlandığı: `StudiedTopics`.
/// - `query` (`@State`): Arama metni. Geçici; ekrana ait.
struct InterviewHubView: View {
    private typealias ID = AccessibilityID.Interview

    let dependencies: AppDependencies

    @AppStorage(StudiedTopics.storageKey, store: StudiedTopics.store)
    private var studied = StudiedTopics()
    @State private var query = ""
    @State private var isConfirmingReset = false

    /// Aramaya uyan konular. `body` her çizildiğinde yeniden hesaplanır; 16 konu için bu ucuz.
    private var visibleTopics: [InterviewTopic] {
        InterviewTopic.filtered(InterviewTopic.all, matching: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    progressSection
                }
                ForEach(InterviewTopic.grouped(visibleTopics)) { group in
                    Section {
                        ForEach(group.topics) { topic in
                            row(for: topic)
                        }
                    } header: {
                        sectionHeader(group.section)
                    }
                }
            }
            .accessibilityIdentifier(ID.hubList)
            .navigationTitle(AccessibilityID.Tab.interview)
            // `.navigationBarDrawer`: Arama kutusu gezinme çubuğunun altında durur, liste kaydırılınca gizlenir.
            .searchable(text: $query, placement: .navigationBarDrawer, prompt: "Soru ya da kavram ara")
            .overlay {
                if visibleTopics.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }

    // MARK: - İlerleme

    private var progressSection: some View {
        let total = InterviewTopic.all.count
        let done = studied.count(in: InterviewTopic.all)
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(ID.progressText(studied: done, total: total))
                    .font(.headline)
                    .accessibilityIdentifier(ID.progressLabel)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    // Metin aynı bilgiyi zaten veriyor; VoiceOver iki kez okumasın.
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)

            if done > 0 {
                Button("İlerlemeyi sıfırla", systemImage: "arrow.counterclockwise", role: .destructive) {
                    isConfirmingReset = true
                }
                .accessibilityIdentifier(ID.resetProgressButton)
                .confirmationDialog("Tüm işaretler kaldırılsın mı?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                    Button("Sıfırla", role: .destructive) {
                        studied = StudiedTopics()
                    }
                }
            }
        } footer: {
            Text("Bir konuyu bitirince konu ekranındaki ✓ düğmesine dokun ya da satırı sağa kaydır.")
        }
    }

    // MARK: - Satırlar

    private func row(for topic: InterviewTopic) -> some View {
        let isStudied = studied.contains(topic.id)
        return NavigationLink {
            InterviewTopicScreen(topic: topic, dependencies: dependencies)
        } label: {
            InterviewTopicRow(topic: topic, isStudied: isStudied)
        }
        .accessibilityIdentifier(ID.topicRow(topic.id))
        .accessibilityValue(isStudied ? ID.studiedValue : ID.notStudiedValue)
        // Satırı sağa kaydırınca soldan çıkan hızlı eylem. Asıl yol konu ekranındaki ✓ düğmesi; bu bir kısayol.
        .swipeActions(edge: .leading) {
            Button {
                studied.toggle(topic.id)
            } label: {
                Label(
                    isStudied ? "İşareti kaldır" : "Çalışıldı",
                    systemImage: isStudied ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(isStudied ? .gray : .green)
            .accessibilityIdentifier(ID.swipeStudiedAction)
        }
    }

    private func sectionHeader(_ section: InterviewTopic.Section) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.rawValue)
                .accessibilityIdentifier(ID.sectionHeader(section.accessibilityKey))
            Text(section.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Liste başlıkları bazı stillerde BÜYÜK HARFE çevrilir; açıklama cümlesi olduğu gibi kalsın.
                .textCase(nil)
        }
    }
}

#Preview {
    InterviewHubView(dependencies: .preview)
}
