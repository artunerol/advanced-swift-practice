import Foundation

/// Bir iOS teslimat hattının (pipeline) tek aşaması: ne yapar, sektörde hangi araçlarla yapılır,
/// bu depoda nerede durur.
///
/// Sadece veri: Ekran (`CICDTopicView`) bu değerleri gösterir, birim testleri ise `repoLocations`'ın
/// gerçekten var olan dosyalara ve adımlara işaret ettiğini doğrular. Böylece biri ci.yml'de bir adımın adını
/// değiştirirse demo sessizce eskimez, test kırılır.
///
/// İçerik (sekiz aşama) `PipelineStage+Catalog.swift` dosyasında.
struct PipelineStage: Identifiable, Hashable, Sendable {
    /// Aşama CI'ın mı (her değişiklikte doğrulama) yoksa CD'nin mi (dağıtılabilir paket ve dağıtım) parçası?
    enum Phase: String, Sendable {
        case ci = "CI"
        case cd = "CD"
    }

    /// Bu depodaki karşılığı: hangi dosyada, hangi adım/iş/komut.
    struct RepoLocation: Hashable, Sendable {
        /// Proje köküne göre yol, ör. ".github/workflows/ci.yml".
        let file: String
        /// Dosyada BİREBİR geçen ad: workflow adımının `name:` değeri, bir iş adı ya da ci.sh'teki fonksiyon.
        /// Birim testi bu metni dosyada arar.
        let anchor: String

        /// Ekranda gösterilen biçim: ".github/workflows/ci.yml → Derle (build-for-testing)"
        var displayText: String { "\(file) → \(anchor)" }
    }

    /// `AccessibilityID.CICD.StageID` sabitlerinden biri.
    let id: String
    let title: String
    let phase: Phase
    /// Satırda her zaman görünen tek cümlelik özet.
    let summary: String
    /// Aşama açılınca görünen "Ne yapar?" açıklaması.
    let explanation: String
    /// Sektörde bu aşama için kullanılan araçlar.
    let tools: [String]
    /// Bu depodaki yerleri. Boşsa `absenceNote` neden olmadığını anlatır.
    let repoLocations: [RepoLocation]
    let absenceNote: String?

    /// "Bu depoda" bölümünde gösterilen metin.
    var repoText: String {
        if repoLocations.isEmpty {
            return absenceNote ?? "Bu depoda yok."
        }
        return repoLocations.map(\.displayText).joined(separator: "\n")
    }
}
