import SwiftUI

// GEÇİCİ İSKELET — sahibi: swift-basics. Bu dosyayı gerçek içerikle değiştir; `static let structVsClass` adını koru.
extension InterviewTopic {
    static let structVsClass = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.structVsClass,
        section: .swift,
        question: "Struct ile class arasındaki fark nedir? Stack ve heap ile ilişkisi ne?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(StructVsClassView()) }
    )
}
