import XCTest
@testable import BookShelf

/// "Mülakatta nasıl anlatırsın?" cevap taslağı (`CICDInterviewAnswer`).
///
/// Kural: Cevap yalnızca işaretlenen deneyimleri İDDİA eder; işaretlenmeyenler sadece "bildiğim" kısmında yer alır.
final class CICDInterviewAnswerTests: XCTestCase {

    func testProjectDefaultsDoNotClaimSigningOrTestFlight() {
        // Bu depoda imzalama ve TestFlight yalnızca şablon; varsayılan seçim onları iddia etmemeli.
        XCTAssertFalse(CICDExperience.projectDefaults.contains(.ciSigning))
        XCTAssertFalse(CICDExperience.projectDefaults.contains(.testFlightUpload))
        XCTAssertTrue(CICDExperience.projectDefaults.contains(.ciPipeline))
    }

    func testUnselectedExperienceAppearsOnlyAsKnowledge() {
        let answer = CICDInterviewAnswer(selected: CICDExperience.projectDefaults)

        XCTAssertFalse(answer.text.contains(CICDExperience.testFlightUpload.claim), "İşaretlenmeyen iddia edilmemeli")
        XCTAssertTrue(answer.text.contains(CICDExperience.testFlightUpload.knowledge))
        XCTAssertTrue(answer.text.contains(CICDExperience.ciPipeline.claim))
        XCTAssertFalse(answer.text.contains(CICDExperience.ciPipeline.knowledge), "İşaretlenen bilgi listesinde tekrar etmemeli")
        XCTAssertEqual(answer.summary, "Deneyim: 6 · Bilgi: 2")
    }

    func testSelectingAnExperienceMovesItFromKnowledgeToClaims() {
        var selected = CICDExperience.projectDefaults
        selected.insert(.testFlightUpload)

        let answer = CICDInterviewAnswer(selected: selected)

        XCTAssertTrue(answer.text.contains(CICDExperience.testFlightUpload.claim))
        XCTAssertFalse(answer.text.contains(CICDExperience.testFlightUpload.knowledge))
        XCTAssertEqual(answer.knowledgeOnly, [.ciSigning])
        XCTAssertEqual(answer.summary, "Deneyim: 7 · Bilgi: 1")
    }

    func testEmptySelectionOpensHonestlyAndClaimsNothing() {
        let answer = CICDInterviewAnswer(selected: [])

        XCTAssertEqual(answer.paragraphs.first, CICDInterviewAnswer.noExperienceOpening)
        XCTAssertTrue(answer.claims.isEmpty)
        for experience in CICDExperience.allCases {
            XCTAssertFalse(answer.text.contains(experience.claim), "\(experience) iddia edilmemeli")
            XCTAssertTrue(answer.text.contains(experience.knowledge), "\(experience) bilgi olarak anlatılmalı")
        }
    }

    func testFullSelectionHasNoKnowledgeSection() {
        let answer = CICDInterviewAnswer(selected: Set(CICDExperience.allCases))

        // İlk paragraf: giriş cümlesi + her deneyim için bir madde.
        XCTAssertEqual(answer.paragraphs.first?.hasPrefix(CICDInterviewAnswer.experienceOpening), true)
        XCTAssertEqual(answer.paragraphs.first?.components(separatedBy: "\n").count, 1 + CICDExperience.allCases.count)
        XCTAssertFalse(answer.text.contains(CICDInterviewAnswer.knowledgeHeader))
        XCTAssertEqual(answer.paragraphs.last, CICDInterviewAnswer.closing)
        XCTAssertEqual(answer.summary, "Deneyim: 8 · Bilgi: 0")
    }

    func testClaimsKeepChecklistOrderRegardlessOfSelectionOrder() {
        // Set sırasızdır; cevap yine de kontrol listesindeki sırayla okunmalı (her açılışta aynı metin).
        let answer = CICDInterviewAnswer(selected: [.testFlightUpload, .ciPipeline, .uiRetries])
        XCTAssertEqual(answer.claims, [.ciPipeline, .uiRetries, .testFlightUpload])
    }

    func testExperienceIDsAreUniqueAndMatchSharedConstants() {
        let ids = CICDExperience.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Kimlikler benzersiz olmalı")
        XCTAssertEqual(CICDExperience.testFlightUpload.id, AccessibilityID.CICD.ExperienceID.testFlightUpload)
    }
}
