import SwiftUI

// GEÇİCİ İSKELET — sahibi: memory-delegate. Bu dosyayı gerçek içerikle değiştir; `static let delegate` adını koru.
extension InterviewTopic {
    static let delegate = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.delegate,
        section: .uikit,
        question: "Delegate pattern'de kim delegate olur, kim weak tutar? Bunu neye göre seçeriz?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
