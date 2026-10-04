import SwiftUI

// GEÇİCİ İSKELET — sahibi: architecture. Bu dosyayı gerçek içerikle değiştir; `static let architecture` adını koru.
extension InterviewTopic {
    static let architecture = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.architecture,
        section: .architecture,
        question: "Clean Architecture, VIPER ve MVVM: farkları ne, hangisini ne zaman seçersin?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
