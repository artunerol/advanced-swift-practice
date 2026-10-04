import SwiftUI

// GEÇİCİ İSKELET — sahibi: swift-basics. Bu dosyayı gerçek içerikle değiştir; `static let protocolAsType` adını koru.
extension InterviewTopic {
    static let protocolAsType = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.protocolAsType,
        section: .swift,
        question: "Protocol'ü tip olarak kullanmak: hangisi derlenir, hangisi derlenmez? (any, some, generic)",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(Text("GEÇİCİ: demo yazılacak.")) }
    )
}
