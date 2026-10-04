import SwiftUI

/// Dikey pipeline'ın tek satırı: solda numaralı düğüm ve onu komşu satırlara bağlayan çizgi, sağda başlık ve özet.
/// Açıkken altında "Ne yapar?", "Araçlar" ve "Bu depoda" ayrıntıları görünür.
///
/// Düğme yalnızca başlık bölümünü kapsar; ayrıntılar düğmenin DIŞINDA. Neden? Bir `Button` içindeki metinler
/// erişilebilirlikte tek bir öğeye (düğmenin etiketine) birleşir. Ayrıntılar dışarıda olunca her biri kendi
/// kimliğiyle ayrı bir metin olarak kalır: VoiceOver onları tek tek okur, UI testi tek tek bulur.
struct PipelineStageRow: View {
    let stage: PipelineStage
    /// 1'den başlayan sıra numarası (düğümde yazar).
    let position: Int
    let isFirst: Bool
    let isLast: Bool
    let isExpanded: Bool
    let onTap: () -> Void

    private typealias ID = AccessibilityID.CICD

    /// Düğüm çapı ve düğümün merkezinin satırın üstünden uzaklığı (dikey boşluk + yarıçap).
    /// Bağlantı çizgisinin üst parçası tam bu yükseklikte biter; böylece çizgi düğümün ortasına "girer".
    private static let nodeSize: CGFloat = 28
    private static let verticalPadding: CGFloat = 10
    private static let nodeCenterY: CGFloat = verticalPadding + nodeSize / 2

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onTap) {
                header
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(ID.stageButton(stage.id))
            .accessibilityValue(isExpanded ? "Açık" : "Kapalı")
            .accessibilityHint("Ayrıntıları gösterir ya da gizler.")

            if isExpanded {
                details
                    // Ayrıntılar düğümün sağındaki sütunda dursun: düğüm genişliği + aradaki boşluk.
                    .padding(.leading, Self.nodeSize + 12)
            }
        }
        .padding(.vertical, Self.verticalPadding)
        // Çizgi arka planda: arka plan, satırın (açıkken ayrıntılar dahil) TAM yüksekliğini alır.
        // List'te satır ayırıcıları ve dikey boşluklar kapalı olduğu için komşu satırların çizgileri birleşir.
        .background(alignment: .topLeading) { connector }
    }

    // MARK: - Parçalar

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            node
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stage.title)
                        .font(.headline)
                    PipelinePhaseBadge(phase: stage.phase)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                Text(stage.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        // Boşluklar dahil bütün başlık dokunulabilir olsun (varsayılan: sadece çizilen pikseller).
        .contentShape(Rectangle())
    }

    private var node: some View {
        Text(verbatim: "\(position)")
            .font(.footnote.weight(.bold).monospacedDigit())
            .foregroundStyle(.white)
            .frame(width: Self.nodeSize, height: Self.nodeSize)
            .background(Circle().fill(stage.phase.color))
            .overlay {
                // Açık aşamayı renk dışında bir işaretle de belli et (renk körlüğü).
                if isExpanded {
                    Circle()
                        .strokeBorder(.primary, lineWidth: 2)
                        .padding(-3)
                }
            }
            .accessibilityHidden(true)
    }

    private var connector: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(width: 2, height: Self.nodeCenterY)
                .opacity(isFirst ? 0 : 1)
            Rectangle()
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .foregroundStyle(.tertiary)
        .frame(width: Self.nodeSize)
        .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailBlock("Ne yapar?") {
                Text(stage.explanation)
                    .accessibilityIdentifier(ID.stageExplanation(stage.id))
            }
            detailBlock("Sektörde kullanılan araçlar") {
                Text(stage.tools.joined(separator: " · "))
                    .accessibilityIdentifier(ID.stageTools(stage.id))
            }
            detailBlock("Bu depoda") {
                Text(verbatim: stage.repoText)
                    .font(.caption.monospaced())
                    .foregroundStyle(stage.repoLocations.isEmpty ? .secondary : .primary)
                    .accessibilityIdentifier(ID.stageRepoLocation(stage.id))
            }
        }
        .font(.callout)
    }

    private func detailBlock(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }
}

/// "CI" / "CD" rozeti.
struct PipelinePhaseBadge: View {
    let phase: PipelineStage.Phase

    var body: some View {
        Text(verbatim: phase.rawValue)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(phase.color)
            .background(phase.color.opacity(0.15), in: Capsule())
    }
}

extension PipelineStage.Phase {
    /// Sistem renkleri açık ve koyu modda kendiliğinden uyum sağlar.
    var color: Color {
        switch self {
        case .ci: .blue
        case .cd: .green
        }
    }
}
