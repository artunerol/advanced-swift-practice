import XCTest
@testable import BookShelf

/// CI/CD demosunun verisi (`PipelineStage.all`) ve mülakat konusu (`InterviewTopic.cicd`).
///
/// En değerli testler "eskime" testleri: Demo ve konu, depodaki gerçek dosyalara ve adım adlarına işaret ediyor
/// (ör. ci.yml'deki "Derle (build-for-testing)"). Biri bir adımın adını değiştirir ya da dosyayı taşırsa demo
/// sessizce yanlış bilgi göstermeye başlar. Bu testler o anda kırılır.
///
/// Kaynak dosyalara nasıl ulaşıyoruz? `#filePath` bu test dosyasının DERLEME anındaki tam yoludur. Simülatör,
/// Mac'in dosya sistemini okuyabildiği için oradan proje köküne çıkıp ci.yml'yi okuyabiliriz. Testler derlendikleri
/// makinede koştuğu sürece (lokalde ve bizim CI'ımızda öyle) bu çalışır. Başka bir makinede koşulursa
/// (ör. .xctestrun'ı başka makineye taşıyıp) kaynak ağacı orada yoktur; o zaman bu testler atlanır (XCTSkip).
final class CICDPipelineTests: XCTestCase {
    private typealias StageID = AccessibilityID.CICD.StageID

    // MARK: - Pipeline verisi

    func testStagesRunFromCommitToAppStoreInPipelineOrder() {
        XCTAssertEqual(
            PipelineStage.all.map(\.id),
            [
                StageID.commit, StageID.lint, StageID.build, StageID.unitTests,
                StageID.uiTests, StageID.archive, StageID.testFlight, StageID.appStore,
            ]
        )
    }

    func testCIStagesComeBeforeCDStages() {
        let phases = PipelineStage.all.map(\.phase)
        guard let firstCD = phases.firstIndex(of: .cd) else {
            return XCTFail("En az bir CD aşaması olmalı")
        }
        XCTAssertTrue(phases[..<firstCD].allSatisfy { $0 == .ci }, "CD'den önce yalnızca CI aşamaları olmalı")
        XCTAssertTrue(phases[firstCD...].allSatisfy { $0 == .cd }, "İlk CD aşamasından sonra CI aşaması gelmemeli")
    }

    func testEveryStageExplainsItselfAndNamesIndustryTools() {
        for stage in PipelineStage.all {
            XCTAssertFalse(stage.summary.isEmpty, stage.id)
            XCTAssertFalse(stage.explanation.isEmpty, stage.id)
            XCTAssertGreaterThanOrEqual(stage.tools.count, 3, "\(stage.id): en az üç araç")
            // Depoda yeri olmayan aşama, nedenini söylemeli.
            if stage.repoLocations.isEmpty {
                XCTAssertNotNil(stage.absenceNote, "\(stage.id): depoda yoksa nedeni yazılmalı")
            }
        }
    }

    func testRepoTextListsEveryLocationOrExplainsAbsence() {
        let build = PipelineStage.all.first { $0.id == StageID.build }
        XCTAssertEqual(
            build?.repoText,
            ".github/workflows/ci.yml → Derle (build-for-testing)\nscripts/ci.sh → cmd_build"
        )
        let appStore = PipelineStage.all.first { $0.id == StageID.appStore }
        XCTAssertEqual(appStore?.repoText, appStore?.absenceNote)
    }

    /// Eskime testi: Her "Bu depoda" satırı var olan bir dosyayı ve o dosyada BİREBİR geçen bir adı gösteriyor mu?
    func testRepoLocationsPointToRealFilesAndStepNames() throws {
        let root = try Self.repositoryRoot()
        for stage in PipelineStage.all {
            for location in stage.repoLocations {
                let contents = try Self.contents(of: location.file, in: root)
                XCTAssertTrue(
                    contents.contains(location.anchor),
                    "\(stage.id): '\(location.anchor)' metni \(location.file) içinde yok. Adım adı değişmiş olabilir."
                )
            }
        }
    }

    // MARK: - Mülakat konusu

    func testTopicFollowsInterviewHubContentRules() {
        let topic = InterviewTopic.cicd
        XCTAssertEqual(topic.id, AccessibilityID.Interview.TopicID.cicd)
        XCTAssertEqual(topic.section, .process)
        XCTAssertTrue((3...6).contains(topic.shortAnswer.count), "Kısa cevap 3-6 madde")
        XCTAssertTrue((3...5).contains(topic.followUps.count), "Ek sorular 3-5")
        XCTAssertTrue((2...4).contains(topic.pitfalls.count), "Tuzaklar 2-4")
        XCTAssertTrue((3...6).contains(topic.codePointers.count), "Koda bak 3-6")
    }

    /// Eskime testi: "Koda bak" yönlendirmeleri var olan dosyalara ve o dosyada geçen sembollere mi işaret ediyor?
    func testCodePointersPointToRealFilesAndSymbols() throws {
        let root = try Self.repositoryRoot()
        for pointer in InterviewTopic.cicd.codePointers {
            let contents = try Self.contents(of: pointer.file, in: root)
            XCTAssertTrue(
                contents.contains(pointer.symbol),
                "'\(pointer.symbol)' \(pointer.file) içinde bulunamadı."
            )
        }
    }

    // MARK: - Yardımcılar

    /// Proje kökü: BookShelfTests/CICD/<bu dosya> → üç seviye yukarı.
    private static func repositoryRoot(filePath: StaticString = #filePath) throws -> URL {
        let root = URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()   // CICD/
            .deletingLastPathComponent()   // BookShelfTests/
            .deletingLastPathComponent()   // proje kökü
        let project = root.appendingPathComponent("BookShelf.xcodeproj").path
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: project),
            "Kaynak ağacı bu makinede yok (\(root.path)); depo dosyalarını okuyan testler atlandı."
        )
        return root
    }

    private static func contents(of relativePath: String, in root: URL) throws -> String {
        let url = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Dosya yok: \(relativePath)")
            return ""
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
