import SwiftUI

/// "Kim kimin sahibi?" sorusunun şeması ve aynı kuralın UIKit/VIPER'daki diğer örnekleri.
///
/// Mülakatçının asıl sorduğu şey: İki nesne konuşurken hangisi delegate olur, hangisi weak tutar?
/// Cevap kalıtımda değil **sahiplik ve ömürde**: Sahip (uzun yaşayan) aşağıyı strong tutar ve delegate olur;
/// sahip olunan (kısa yaşayan) protokolü tanımlar ve yukarıyı weak tutar.
struct OwnershipDiagramView: View {
    private typealias ID = AccessibilityID.Delegation

    @State private var outcome: DelegateLifetimeExperiment.Outcome?
    @State private var isRunning = false

    var body: some View {
        List {
            Section {
                OwnershipDiagram()
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("BookRatingViewController, StarRatingControl'ü strong tutar. StarRatingControl, BookRatingViewController'ı weak delegate olarak tutar.")
                    .accessibilityIdentifier(ID.diagram)
            } header: {
                Text("Kim kimin sahibi?")
            } footer: {
                Text("Düz ok = strong (sahiplik, aşağı). Kesikli ok = weak (geri bildirim, yukarı). İki ok da strong olsaydı retain cycle olurdu.")
            }

            Section {
                Button {
                    runExperiment()
                } label: {
                    Text(isRunning ? "Çalışıyor…" : "Sahibi yok et, kontrolü yaşat")
                }
                .disabled(isRunning)
                .accessibilityIdentifier(ID.lifetimeExperimentButton)

                if let outcome {
                    Text(verbatim: outcome.summary)
                        .foregroundStyle(outcome.ownerReleased && outcome.delegateIsNil ? Color.green : Color.red)
                        .accessibilityIdentifier(ID.lifetimeResultLabel)
                    Text(verbatim: "Sonra puan değiştirildi: \(outcome.controlStillWorks ? "çökme yok, delegate?. çağrısı atlandı" : "değişmedi")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Deney")
            } footer: {
                Text("weak referans nesne ölünce kendiliğinden nil olur (zeroing). unowned olsaydı sonraki erişim çökerdi; bu yüzden ömrü garanti olmayan delegate'ler weak tutulur.")
            }

            Section("Süper sınıf mı?") {
                Text("""
                Hayır. Delegate kalıbında kalıtım yoktur: BookRatingViewController UIViewController'dan, StarRatingControl \
                UIControl'den türer. Birbirlerine yalnızca StarRatingControlDelegate protokolü üzerinden bağlıdırlar \
                (kompozisyon). "Hangisi delegate olur?" sorusunu sınıf hiyerarşisi değil, sahiplik ve ömür belirler. \
                Bu aynı zamanda mimari bir karardır: Kontrol yeniden kullanılabilir kalsın diye "ne yapılacağına" sahibi karar verir.
                """)
                .font(.callout)
            }

            Section {
                ForEach(OwnershipExample.all) { example in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(example.title).font(.subheadline.weight(.semibold))
                        Label(example.strongEdge, systemImage: "arrow.down")
                            .font(.footnote)
                        Label(example.weakEdge, systemImage: "arrow.up")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Aynı kural, başka yerlerde")
            }
        }
        .accessibilityIdentifier(ID.ownershipList)
    }

    private func runExperiment() {
        isRunning = true
        // `Task { }` view'un ana actor'ünü miras alır; deney ana actor'de çalışır, sonucu doğrudan @State'e yazabiliriz.
        Task {
            outcome = await DelegateLifetimeExperiment.run()
            isRunning = false
        }
    }
}

/// Aynı "sahip strong, geri bildirim weak" kuralının başka örnekleri.
private struct OwnershipExample: Identifiable {
    let title: String
    let strongEdge: String
    let weakEdge: String
    var id: String { title }

    static let all: [OwnershipExample] = [
        OwnershipExample(
            title: "UITableView ↔ view controller",
            strongEdge: "VC → view → tableView (strong)",
            weakEdge: "tableView.delegate / dataSource → VC (weak)"
        ),
        OwnershipExample(
            title: "Parent ↔ child view controller",
            strongEdge: "parent.children → child (strong)",
            weakEdge: "child.parent → parent (weak)"
        ),
        OwnershipExample(
            title: "VIPER: View ↔ Presenter",
            strongEdge: "View (VC) → presenter (strong)",
            weakEdge: "presenter.view → View (weak)"
        ),
        OwnershipExample(
            title: "VIPER: Presenter ↔ Interactor",
            strongEdge: "presenter → interactor (strong)",
            weakEdge: "interactor.output → presenter (weak)"
        ),
        OwnershipExample(
            title: "Modal: sunan ↔ sunulan ekran",
            strongEdge: "UIKit sunulan ekranı tutar (presentedViewController)",
            weakEdge: "sunulan.delegate → sunan (weak), ör. LeakVictimViewController"
        ),
    ]
}

/// İki kutu ve iki ok: aşağı düz (strong), yukarı kesikli (weak).
private struct OwnershipDiagram: View {
    var body: some View {
        VStack(spacing: 0) {
            NodeBox(title: "BookRatingViewController", subtitle: "Sahip · uzun ömürlü · delegate", tint: .blue)
            HStack(alignment: .center) {
                ArrowColumn(direction: .down, isWeak: false, caption: "strong\nview → subview")
                Spacer(minLength: 16)
                ArrowColumn(direction: .up, isWeak: true, caption: "weak\ndelegate")
            }
            .frame(height: 96)
            .padding(.horizontal, 24)
            NodeBox(title: "StarRatingControl", subtitle: "Sahip olunan · protokolü tanımlar", tint: .orange)
        }
    }
}

private struct NodeBox: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.subheadline.monospaced().weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint, lineWidth: 1))
    }
}

private struct ArrowColumn: View {
    let direction: VerticalArrow.Direction
    let isWeak: Bool
    let caption: String

    var body: some View {
        HStack(spacing: 8) {
            VerticalArrow(direction: direction)
                .stroke(
                    isWeak ? Color.secondary : Color.primary,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: isWeak ? [6, 5] : [])
                )
                .frame(width: 16)
            Text(caption)
                .font(.caption.monospaced())
                .foregroundStyle(isWeak ? .secondary : .primary)
        }
        .padding(.vertical, 6)
    }
}

/// Dikey bir çizgi ve ucunda ok başı. `Shape` yalnızca yolu tarif eder; rengi ve çizgi stilini çağıran verir.
private struct VerticalArrow: Shape {
    enum Direction { case up, down }
    let direction: Direction

    func path(in rect: CGRect) -> Path {
        let head: CGFloat = 6
        let tip = direction == .down ? CGPoint(x: rect.midX, y: rect.maxY) : CGPoint(x: rect.midX, y: rect.minY)
        let tail = direction == .down ? CGPoint(x: rect.midX, y: rect.minY) : CGPoint(x: rect.midX, y: rect.maxY)
        let back: CGFloat = direction == .down ? -head : head

        var path = Path()
        path.move(to: tail)
        path.addLine(to: tip)
        path.move(to: CGPoint(x: tip.x - head, y: tip.y + back))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x + head, y: tip.y + back))
        return path
    }
}

#Preview {
    NavigationStack {
        OwnershipDiagramView()
    }
}
