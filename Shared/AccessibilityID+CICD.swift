import Foundation

// Sahibi: CI/CD konusu. Mülakat merkezindeki "CI/CD ile çalıştın mı?" sorusunun demosu (`CICDTopicView`).
extension AccessibilityID {
    enum CICD {
        /// Demonun tamamı tek bir SwiftUI `List` (XCUITest'te `collectionViews`).
        static let list = "cicd.demo.list"

        // MARK: Pipeline aşamaları
        // Her aşama bir düğme; dokununca altında ayrıntılar açılır, tekrar dokununca kapanır.

        /// Aşamanın düğmesi (başlık + CI/CD rozeti + tek satırlık özet).
        static func stageButton(_ stageID: String) -> String { "cicd.stage.\(stageID)" }
        /// Açık aşamanın "Ne yapar?" metni.
        static func stageExplanation(_ stageID: String) -> String { "cicd.stage.\(stageID).explanation" }
        /// Açık aşamanın "Sektörde kullanılan araçlar" metni.
        static func stageTools(_ stageID: String) -> String { "cicd.stage.\(stageID).tools" }
        /// Açık aşamanın "Bu depoda" metni. Biçim: "<dosya> → <adım adı>" (birden çoksa satır satır)
        /// ya da depoda yoksa açıklama.
        static func stageRepoLocation(_ stageID: String) -> String { "cicd.stage.\(stageID).repo" }

        /// Aşama kimlikleri. Uygulama (`PipelineStage.id`) ve UI testleri aynı değerleri kullanır.
        enum StageID {
            static let commit = "commit"
            static let lint = "lint"
            static let build = "build"
            static let unitTests = "unitTests"
            static let uiTests = "uiTests"
            static let archive = "archive"
            static let testFlight = "testFlight"
            static let appStore = "appStore"
        }

        // MARK: "Mülakatta nasıl anlatırsın?"

        /// Deneyim kontrol listesindeki bir satır (düğme; seçiliyken onay işareti).
        static func experienceButton(_ experienceID: String) -> String { "cicd.experience.\(experienceID)" }
        /// Seçimlere göre sayaç. Biçim: "Deneyim: 6 · Bilgi: 2"
        static let answerSummary = "cicd.answer.summary"
        /// Seçimlerden üretilen cevap taslağı (tek, çok paragraflı metin).
        static let answerText = "cicd.answer.text"

        /// Deneyim kimlikleri. Uygulama (`CICDExperience.id`) ve UI testleri aynı değerleri kullanır.
        enum ExperienceID {
            static let ciPipeline = "ciPipeline"
            static let buildOnceTestTwice = "buildOnceTestTwice"
            static let xcresultArtifacts = "xcresultArtifacts"
            static let uiRetries = "uiRetries"
            static let versioning = "versioning"
            static let releaseArchive = "releaseArchive"
            static let ciSigning = "ciSigning"
            static let testFlightUpload = "testFlightUpload"
        }
    }
}
