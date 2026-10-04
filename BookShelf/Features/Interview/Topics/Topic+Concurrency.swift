import SwiftUI

// GEÇİCİ İSKELET — sahibi: hub. Bu dosyayı gerçek içerikle değiştir; `static let concurrency` adını koru.
extension InterviewTopic {
    static let concurrency = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.concurrency,
        section: .bonus,
        question: "Swift Concurrency: async/await, actor ve Sendable",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
