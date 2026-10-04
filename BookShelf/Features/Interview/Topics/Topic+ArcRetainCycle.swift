import SwiftUI

// GEÇİCİ İSKELET — sahibi: memory-delegate. Bu dosyayı gerçek içerikle değiştir; `static let arcRetainCycle` adını koru.
extension InterviewTopic {
    static let arcRetainCycle = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.arcRetainCycle,
        section: .swift,
        question: "ARC nasıl çalışır? Retain cycle nedir, nasıl kırılır?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
