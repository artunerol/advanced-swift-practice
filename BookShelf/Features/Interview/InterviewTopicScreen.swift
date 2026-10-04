import SwiftUI

/// Bir mülakat konusunun ekranı. Üstte üç bölümlü seçici:
/// - **Cevap**: 30 saniyelik cevap, ek sorular, tuzaklar (`TopicAnswerPane`).
/// - **Demo**: Konunun canlı demosu, tam ekran (`topic.demo(dependencies)`).
/// - **Kod**: "Projede nerede?" yönlendirmeleri (`TopicCodePane`).
///
/// Gezinme çubuğundaki ✓ düğmesi konuyu "çalışıldı" olarak işaretler; merkezdeki ilerleme anında güncellenir
/// (ikisi de aynı `@AppStorage` anahtarını okur).
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

    private typealias ID = AccessibilityID.Interview

    let topic: InterviewTopic
    let dependencies: AppDependencies

    @State private var pane: Pane = .answer
    @AppStorage(StudiedTopics.storageKey, store: StudiedTopics.store)
    private var studied = StudiedTopics()

    private var isStudied: Bool { studied.contains(topic.id) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Bölüm", selection: $pane) {
                ForEach(Pane.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityIdentifier(ID.panePicker)

            // `switch`: Hiyerarşide AYNI ANDA yalnızca seçili bölüm bulunur.
            // - Bölüm değişince eskisi tamamen kaldırılır. Demo bir UIKit controller'ı sarıyorsa
            //   (`UIViewControllerRepresentable`) controller'ın `viewWillDisappear` → `viewDidDisappear` → `deinit`
            //   sırası gerçekten çalışır; Demo'ya dönülünce controller sıfırdan kurulur (`viewDidLoad` yeniden).
            //   Yani demonun durumu (ör. yazdığın metin) bölüm değişince sıfırlanır. Bu bilinçli bir tercih.
            // - Alternatif (üç bölümü `ZStack`'te tutup görünmeyenleri gizlemek) durumu korurdu; ama gizli bölümlerin
            //   öğeleri erişilebilirlik ağacında kalabilir ve UI testleri ile VoiceOver görünmeyen öğeleri bulurdu.
            switch pane {
            case .answer:
                TopicAnswerPane(topic: topic)
            case .demo:
                // Demo kendi List/Form/ScrollView'unu getirebilir; onu başka bir ScrollView'a GÖMMÜYORUZ.
                // İç içe kaydırma alanında bir UITableView ya da List yüksekliğini bilemez ve sıfıra çöker.
                // `maxHeight: .infinity`: Kaydırmayan bir demo da (ör. tek bir VStack) kalan alanı doldurur.
                topic.demo(dependencies)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .code:
                TopicCodePane(pointers: topic.codePointers)
            }
        }
        // Seçicinin arkası, altındaki gruplu listelerle (List/Form) aynı renkte olsun; iki ayrı şerit gibi görünmesin.
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(topic.question)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                studiedButton
            }
        }
    }

    private var studiedButton: some View {
        Button {
            studied.toggle(topic.id)
        } label: {
            Label(
                isStudied ? "Çalışıldı" : "Çalışıldı olarak işaretle",
                systemImage: isStudied ? "checkmark.circle.fill" : "checkmark.circle"
            )
        }
        .tint(isStudied ? .green : nil)
        .sensoryFeedback(.success, trigger: isStudied) { _, nowStudied in nowStudied }
        .accessibilityIdentifier(ID.studiedToggle)
        .accessibilityValue(isStudied ? ID.studiedValue : ID.notStudiedValue)
    }
}

#Preview {
    NavigationStack {
        InterviewTopicScreen(topic: .concurrency, dependencies: .preview)
    }
}
