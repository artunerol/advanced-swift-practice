import Foundation

// Sahibi: Mülakat merkezi (InterviewHubView + konu ekranı). Konu kimlikleri burada sabitlenir ki
// uygulama ile UI testleri aynı değerleri kullansın.
extension AccessibilityID {
    enum Interview {
        /// Merkezdeki konu listesi (SwiftUI `List` → XCUITest'te `collectionViews`).
        static let hubList = "interview.hub.list"
        /// Listedeki bir konunun satırı (NavigationLink → XCUITest'te `buttons`).
        static func topicRow(_ topicID: String) -> String { "interview.row.\(topicID)" }

        /// Konu ekranının üstündeki bölüm seçici (Cevap / Demo / Kod).
        static let panePicker = "interview.topic.panePicker"
        /// Bölüm etiketleri (kimlik değil, seçicideki görünen metin).
        static let answerPane = "Cevap"
        static let demoPane = "Demo"
        static let codePane = "Kod"

        /// "Cevap" bölümündeki liste ve "Kod" bölümündeki liste.
        static let answerList = "interview.topic.answerList"
        static let codeList = "interview.topic.codeList"

        /// Konu kimlikleri. `InterviewTopic.id` bu değerlerden birini kullanır.
        enum TopicID {
            // Swift temelleri
            static let protocolExtension = "protocolExtension"
            static let protocolAsType = "protocolAsType"
            static let structVsClass = "structVsClass"
            static let typealiasTopic = "typealias"
            static let arcRetainCycle = "arcRetainCycle"
            // UIKit
            static let vcLifecycle = "vcLifecycle"
            static let dynamicCells = "dynamicCells"
            static let frameVsBounds = "frameVsBounds"
            static let tableVsCollection = "tableVsCollection"
            static let delegate = "delegate"
            // Mimari
            static let architecture = "architecture"
            static let dipVsDi = "dipVsDi"
            // Veri
            static let persistence = "persistence"
            // Süreç
            static let cicd = "cicd"
            // Bonus
            static let concurrency = "concurrency"
            static let objcInterop = "objcInterop"
        }
    }
}
