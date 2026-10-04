import SwiftUI

/// "CI/CD ile çalıştın mı?" sorusunun demosu. İki bölüm:
///
/// 1. **Pipeline:** Commit'ten App Store'a sekiz aşama, dikey bir hat olarak. Bir aşamaya dokununca ne yaptığı,
///    sektörde hangi araçlarla yapıldığı ve BU depoda hangi dosyada, hangi adımda durduğu açılır.
/// 2. **Mülakatta nasıl anlatırsın?:** Gerçekten yaptıklarını işaretlersin; cevap taslağı yalnızca işaretlediklerini
///    iddia eder, gerisini "nasıl yapıldığını biliyorum" düzeyinde anlatır.
///
/// Veriler saf tiplerde (`PipelineStage.all`, `CICDExperience`, `CICDInterviewAnswer`); bu view sadece gösterir.
/// Kendi `NavigationStack`'ini içermez: Mülakat merkezindeki konu ekranının içinde, tam yükseklikte gösterilir.
struct CICDTopicView: View {
    private typealias ID = AccessibilityID.CICD

    /// Aynı anda yalnızca bir aşama açık (akordeon). Açık aşama yoksa `nil`.
    @State private var expandedStageID: String?
    /// Kullanıcı Ayarlar'da "Hareketi Azalt"ı açtıysa açılıp kapanmayı canlandırmıyoruz.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Kontrol listesinde işaretli deneyimler. Bu depoda gerçekten çalışan parçalarla başlar.
    @State private var experiences: Set<CICDExperience> = CICDExperience.projectDefaults

    private var answer: CICDInterviewAnswer { CICDInterviewAnswer(selected: experiences) }

    var body: some View {
        List {
            introSection
            pipelineSection
            checklistSection
            answerSection
        }
        .accessibilityIdentifier(ID.list)
    }

    // MARK: - Bölümler

    private var introSection: some View {
        Section {
            Text("""
            CI (Continuous Integration) her değişikliği temiz bir makinede derleyip test eder. CD (Continuous Delivery) \
            geçen build'i dağıtılabilir bir pakete çevirip test kullanıcılarına ulaştırır. Mağazaya çıkış bir insan \
            kararıysa Continuous Delivery, o da otomatikse Continuous Deployment denir.
            """)
            .font(.callout)
            HStack(spacing: 16) {
                legendItem(.ci, text: "her push / PR'da")
                legendItem(.cd, text: "sürüm etiketinde")
            }
            .font(.caption)
        }
    }

    private var pipelineSection: some View {
        Section {
            ForEach(Array(PipelineStage.all.enumerated()), id: \.element.id) { index, stage in
                PipelineStageRow(
                    stage: stage,
                    position: index + 1,
                    isFirst: index == 0,
                    isLast: index == PipelineStage.all.count - 1,
                    isExpanded: expandedStageID == stage.id,
                    onTap: { toggle(stage) }
                )
                // Çizgilerin satırdan satıra kesintisiz akması için: ayırıcı yok, dikey iç boşluk yok.
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        } header: {
            Text("Pipeline")
        } footer: {
            Text("Bir aşamaya dokun: ne yaptığını, sektörde hangi araçlarla yapıldığını ve bu depoda nerede olduğunu gör.")
        }
    }

    private var checklistSection: some View {
        Section {
            ForEach(CICDExperience.allCases) { experience in
                experienceRow(experience)
            }
        } header: {
            Text("Mülakatta nasıl anlatırsın?")
                .textCase(nil)
        } footer: {
            Text("""
            Sadece gerçekten yaptığın ve ek sorularda ayrıntısını anlatabileceğin şeyleri işaretle. Varsayılan \
            işaretler bu projede GERÇEKTEN çalışan parçalar. Projeyi kendin çalıştırıp adımlarını açıklayamıyorsan \
            işareti kaldır. İmzalama ve TestFlight burada yalnızca şablon; onları "yaptım" diye anlatma.
            """)
        }
    }

    private var answerSection: some View {
        Section {
            Text(verbatim: answer.summary)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier(ID.answerSummary)
            Text(verbatim: answer.text)
                .font(.callout)
                // Uzun basınca metni seçip kopyalayabilirsin (not almak için).
                .textSelection(.enabled)
                .accessibilityIdentifier(ID.answerText)
        } header: {
            Text("Cevap taslağı")
        } footer: {
            Text("Ezberleme; kendi cümlelerinle, bu projeden somut örneklerle anlat. Bir ek soru gelirse ilgili aşamaya dokunup \"Bu depoda\" kısmındaki dosyayı aç.")
        }
    }

    // MARK: - Satırlar

    private func experienceRow(_ experience: CICDExperience) -> some View {
        let isSelected = experiences.contains(experience)
        return Button {
            if isSelected {
                experiences.remove(experience)
            } else {
                experiences.insert(experience)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .imageScale(.large)
                    .accessibilityHidden(true)
                Text(experience.label)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ID.experienceButton(experience.id))
        // Seçili durumu VoiceOver da duysun ("Seçili").
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func legendItem(_ phase: PipelineStage.Phase, text: String) -> some View {
        HStack(spacing: 6) {
            PipelinePhaseBadge(phase: phase)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Eylemler

    private func toggle(_ stage: PipelineStage) {
        withAnimation(reduceMotion ? nil : .snappy) {
            expandedStageID = expandedStageID == stage.id ? nil : stage.id
        }
    }
}

#Preview {
    NavigationStack {
        CICDTopicView()
            .navigationTitle("CI/CD")
    }
}
