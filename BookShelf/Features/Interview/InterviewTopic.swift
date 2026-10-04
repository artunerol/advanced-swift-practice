import SwiftUI

/// Mülakat merkezindeki tek bir soru/konu: kısa cevap + canlı demo + "koda bak" yönlendirmeleri.
///
/// Her konu kendi dosyasında `extension InterviewTopic { static let ... }` olarak tanımlanır
/// (ör. `Topics/Topic+ProtocolAsType.swift`). Merkez ekran (`InterviewHubView`) sadece `InterviewTopic.all`
/// listesini gösterir; hiçbir konunun iç ayrıntısını bilmez. Yeni bir konu eklemek = yeni bir dosya + listeye bir satır.
///
/// Neden `struct`? Konu değişmez bir veri paketidir; kimliği değil içeriği önemlidir.
/// Neden `Sendable`? `static let` sabitleri Swift 6'da global değişken sayılır ve `Sendable` olmak zorundadır.
/// Bu yüzden `demo` kapanışı da `@Sendable` (ve SwiftUI view ürettiği için `@MainActor`).
struct InterviewTopic: Identifiable, Sendable {
    /// Merkezdeki bölümler. Sıra = ekrandaki sıra.
    enum Section: String, CaseIterable, Sendable {
        case swift = "Swift Temelleri"
        case uikit = "UIKit"
        case architecture = "Mimari"
        case data = "Veri ve Kalıcılık"
        case process = "Süreç"
        case bonus = "Bonus"
    }

    /// "Koda bak" yönlendirmesi: hangi dosyada, hangi tipe/fonksiyona, neye dikkat ederek bakmalı.
    struct CodePointer: Hashable, Sendable {
        /// Proje köküne göre yol, ör. "BookShelf/Features/Fundamentals/Protocols/ReadingItem.swift".
        let file: String
        /// Bakılacak tip/fonksiyon, ör. "ProtocolDispatchDemo".
        let symbol: String
        /// Bakarken neyi fark etmeli? Tek cümle.
        let note: String
    }

    /// Mülakatçının cevabın ardından sorabileceği ek soru ve kısa cevabı.
    struct FollowUp: Hashable, Sendable {
        let question: String
        let answer: String
    }

    /// Kalıcı kimlik; `AccessibilityID.Interview.TopicID` sabitlerinden biri.
    let id: String
    let section: Section
    /// Sorunun mülakattaki hali.
    let question: String
    /// 30 saniyelik cevap: 3-6 kısa madde.
    let shortAnswer: [String]
    let followUps: [FollowUp]
    /// Sık yapılan hatalar / tuzaklar.
    let pitfalls: [String]
    let codePointers: [CodePointer]
    /// Canlı demo. Kendi `NavigationStack`'ini İÇERMEMELİ (konu ekranı zaten bir yığının içinde).
    let demo: @MainActor @Sendable (AppDependencies) -> AnyView
}
