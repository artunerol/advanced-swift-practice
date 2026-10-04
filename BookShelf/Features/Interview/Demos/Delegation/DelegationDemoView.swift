import SwiftUI

/// "Delegate" konusunun demosu: üç bölüm.
/// - **Canlı:** UIKit `BookRatingViewController` + `StarRatingControl`: delegate, closure ve target-action yan yana.
/// - **Sahiplik:** "Kim kimin sahibi?" şeması ve sahip ölünce `weak` delegate'in `nil` olduğunu gösteren deney.
/// - **Hangisi?:** Delegate / closure / target-action / NotificationCenter / AsyncStream seçimi.
///
/// Kendi `NavigationStack`'ini içermez; konu ekranının (`InterviewTopicScreen`) yığınında gösterilir.
struct DelegationDemoView: View {
    enum Pane: CaseIterable, Identifiable {
        case live, ownership, choice
        var id: Self { self }

        var title: String {
            switch self {
            case .live: AccessibilityID.Delegation.liveSegment
            case .ownership: AccessibilityID.Delegation.ownershipSegment
            case .choice: AccessibilityID.Delegation.choiceSegment
            }
        }
    }

    @State private var pane: Pane = .live

    var body: some View {
        VStack(spacing: 0) {
            Picker("Bölüm", selection: $pane) {
                ForEach(Pane.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityIdentifier(AccessibilityID.Delegation.panePicker)

            switch pane {
            case .live: BookRatingDemoView()
            case .ownership: OwnershipDiagramView()
            case .choice: CommunicationChoiceView()
            }
        }
    }
}

/// UIKit sahibini (ve onun kontrolünü) SwiftUI'a yerleştiren köprü.
struct BookRatingDemoView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> BookRatingViewController {
        BookRatingViewController()
    }

    func updateUIViewController(_ viewController: BookRatingViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DelegationDemoView()
            .navigationBarTitleDisplayMode(.inline)
    }
}
