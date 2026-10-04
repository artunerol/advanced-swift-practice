import SwiftUI

// GEÇİCİ İSKELET — sahibi: uikit-labs. Bu dosyayı gerçek içerikle değiştir; `static let tableVsCollection` adını koru.
extension InterviewTopic {
    static let tableVsCollection = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.tableVsCollection,
        section: .uikit,
        question: "UITableView mı UICollectionView mı? Hangisi ne zaman?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
