import Foundation

// Sahibi: Mülakat merkezi (InterviewHubView + konu ekranı). Konu kimlikleri burada sabitlenir ki
// uygulama ile UI testleri aynı değerleri kullansın.
extension AccessibilityID {
    enum Interview {
        // MARK: Merkez (konu listesi)

        /// Merkezdeki konu listesi (SwiftUI `List` → XCUITest'te `collectionViews`).
        static let hubList = "interview.hub.list"
        /// Listedeki bir konunun satırı (NavigationLink → XCUITest'te `buttons`).
        /// Satırın `value`'su `studiedValue` ya da `notStudiedValue` olur.
        static func topicRow(_ topicID: String) -> String { "interview.row.\(topicID)" }
        /// Bölüm başlığı. `sectionKey`: `SectionKey` sabitlerinden biri.
        static func sectionHeader(_ sectionKey: String) -> String { "interview.section.\(sectionKey)" }
        /// Listenin en üstündeki ilerleme metni, ör. "5 / 16 konu çalışıldı".
        static let progressLabel = "interview.hub.progress"
        /// Satır sağa kaydırılınca soldan çıkan "Çalışıldı" / "İşareti kaldır" eylemi.
        static let swipeStudiedAction = "interview.hub.swipeStudiedAction"
        /// İlerlemeyi sıfırlama düğmesi (yalnızca en az bir konu çalışıldıysa görünür).
        static let resetProgressButton = "interview.hub.resetProgress"

        /// İlerleme metninin biçimi. Uygulama ve UI testi aynı metni bu fonksiyondan üretir.
        static func progressText(studied: Int, total: Int) -> String {
            "\(studied) / \(total) konu çalışıldı"
        }

        /// "Çalışıldı" durumunun erişilebilirlik değeri (`accessibilityValue`). Satırda ve konu ekranındaki
        /// düğmede aynı değer kullanılır; VoiceOver da bu metni okur.
        static let studiedValue = "Çalışıldı"
        static let notStudiedValue = "Çalışılmadı"

        /// Bölüm anahtarları. Bölüm adları (ör. "Swift Temelleri") ekranda görünen metindir ve değişebilir;
        /// testler bölümü bu sabit anahtarla bulur.
        enum SectionKey {
            static let swift = "swift"
            static let uikit = "uikit"
            static let architecture = "architecture"
            static let data = "data"
            static let process = "process"
            static let bonus = "bonus"
        }

        // MARK: Konu ekranı

        /// Konu ekranının üstündeki bölüm seçici (Cevap / Demo / Kod).
        static let panePicker = "interview.topic.panePicker"
        /// Bölüm etiketleri (kimlik değil, seçicideki görünen metin).
        static let answerPane = "Cevap"
        static let demoPane = "Demo"
        static let codePane = "Kod"

        /// Gezinme çubuğundaki "çalışıldı" düğmesi. `value`'su `studiedValue` ya da `notStudiedValue` olur.
        static let studiedToggle = "interview.topic.studiedToggle"

        /// "Cevap" bölümündeki liste ve "Kod" bölümündeki liste.
        static let answerList = "interview.topic.answerList"
        static let codeList = "interview.topic.codeList"

        /// "Cevap" bölümünün en üstündeki sorunun tam metni.
        static let questionLabel = "interview.topic.question"
        /// Kısa cevabın `index`. maddesi (0'dan başlar).
        static func shortAnswerItem(_ index: Int) -> String { "interview.topic.shortAnswer.\(index)" }
        /// `index`. ek sorunun açılır-kapanır başlığı ve açılınca görünen cevabı.
        static func followUp(_ index: Int) -> String { "interview.topic.followUp.\(index)" }
        static func followUpAnswer(_ index: Int) -> String { "interview.topic.followUpAnswer.\(index)" }
        /// `index`. tuzak maddesi.
        static func pitfall(_ index: Int) -> String { "interview.topic.pitfall.\(index)" }

        /// "Kod" bölümündeki `index`. yönlendirme (sembol + dosya yolu + not) ve dosya adını kopyalama düğmesi.
        static func codePointer(_ index: Int) -> String { "interview.topic.codePointer.\(index)" }
        static func copyFileNameButton(_ index: Int) -> String { "interview.topic.copyFileName.\(index)" }
        /// "Kod" bölümünün altındaki "Xcode'da nasıl açarım?" ipucu.
        static let codeHint = "interview.topic.codeHint"

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
