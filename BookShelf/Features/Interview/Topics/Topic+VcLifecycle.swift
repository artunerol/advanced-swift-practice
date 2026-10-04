import SwiftUI

// GEÇİCİ İSKELET — sahibi: uikit-labs. Bu dosyayı gerçek içerikle değiştir; `static let vcLifecycle` adını koru.
extension InterviewTopic {
    static let vcLifecycle = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.vcLifecycle,
        section: .uikit,
        question: "UIViewController yaşam döngüsünü anlatır mısın? viewDidLayoutSubviews ne zaman çağrılır?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
