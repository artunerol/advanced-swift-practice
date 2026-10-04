import SwiftUI

// GEÇİCİ İSKELET — sahibi: hub. Bu dosyayı gerçek içerikle değiştir; `static let objcInterop` adını koru.
extension InterviewTopic {
    static let objcInterop = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.objcInterop,
        section: .bonus,
        question: "Objective-C ile Swift birlikte nasıl çalışır?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(ISBNCheckerView()) }
    )
}
