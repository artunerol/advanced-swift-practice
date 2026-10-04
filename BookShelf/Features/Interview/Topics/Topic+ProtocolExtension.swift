import SwiftUI

// GEÇİCİ İSKELET — sahibi: swift-basics. Bu dosyayı gerçek içerikle değiştir; `static let protocolExtension` adını koru.
extension InterviewTopic {
    static let protocolExtension = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.protocolExtension,
        section: .swift,
        question: "Protocol ve extension birlikte nasıl kullanılır? Varsayılan uygulama nedir?",
        shortAnswer: ["GEÇİCİ: kısa cevap yazılacak."],
        followUps: [],
        pitfalls: [],
        codePointers: [],
        demo: { _ in AnyView(ProtocolsView()) }
    )
}
