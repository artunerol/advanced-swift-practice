import SwiftUI

// GEÇİCİ İSKELET — sahibi: swift-basics. Bu dosyayı gerçek içerikle değiştir; `static let typealiasTopic` adını koru.
extension InterviewTopic {
    static let typealiasTopic = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.typealiasTopic,
        section: .swift,
        question: "typealias nedir, nerede işe yarar?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
