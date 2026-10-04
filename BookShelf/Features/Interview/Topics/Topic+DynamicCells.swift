import SwiftUI

// GEÇİCİ İSKELET — sahibi: uikit-labs. Bu dosyayı gerçek içerikle değiştir; `static let dynamicCells` adını koru.
extension InterviewTopic {
    static let dynamicCells = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.dynamicCells,
        section: .uikit,
        question: "UITableView'da dinamik yükseklikli (self-sizing) hücre nasıl yapılır?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
