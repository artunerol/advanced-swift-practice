import SwiftUI

// GEÇİCİ İSKELET — sahibi: uikit-labs. Bu dosyayı gerçek içerikle değiştir; `static let frameVsBounds` adını koru.
extension InterviewTopic {
    static let frameVsBounds = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.frameVsBounds,
        section: .uikit,
        question: "frame ile bounds arasındaki fark nedir?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
