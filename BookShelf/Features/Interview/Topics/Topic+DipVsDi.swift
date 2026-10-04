import SwiftUI

// GEÇİCİ İSKELET — sahibi: architecture. Bu dosyayı gerçek içerikle değiştir; `static let dipVsDi` adını koru.
extension InterviewTopic {
    static let dipVsDi = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.dipVsDi,
        section: .architecture,
        question: "Dependency Inversion ile Dependency Injection aynı şey mi?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
