import SwiftUI

// GEÇİCİ İSKELET — sahibi: ci. Bu dosyayı gerçek içerikle değiştir; `static let cicd` adını koru.
extension InterviewTopic {
    static let cicd = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.cicd,
        section: .process,
        question: "CI/CD ile çalıştın mı? Hangi araçları kullandın?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
