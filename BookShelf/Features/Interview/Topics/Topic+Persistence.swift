import SwiftUI

// GEÇİCİ İSKELET — sahibi: persistence. Bu dosyayı gerçek içerikle değiştir; `static let persistence` adını koru.
extension InterviewTopic {
    static let persistence = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.persistence,
        section: .data,
        question: "iOS'ta veri saklama yolları nelerdir? (UserDefaults, Keychain, dosya, Core Data, SwiftData)",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
