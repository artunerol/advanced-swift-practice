import XCTest

/// Mülakat sekmesindeki CI/CD demosu: aşama ayrıntıları ve dürüst cevap taslağı.
final class CICDUITests: BookShelfUITestCase {

    @MainActor
    func testStageShowsRepoLocationAndChecklistDrivesTheAnswer() {
        let app = launchApp()
        TabBarScreen(app: app).openInterview().waitUntilDisplayed()
            .openTopic(AccessibilityID.Interview.TopicID.cicd)
            .showDemo()
        let screen = CICDScreen(app: app).waitUntilDisplayed()

        XCTContext.runActivity(named: "Derleme aşamasına dokun: bu depodaki yeri görünür") { _ in
            screen.toggleStage(AccessibilityID.CICD.StageID.build)
            assertLabel(
                screen.stageRepoLocation(AccessibilityID.CICD.StageID.build),
                contains: ".github/workflows/ci.yml → Derle (build-for-testing)"
            )
        }

        XCTContext.runActivity(named: "Varsayılan: imzalama ve TestFlight iddia edilmez") { _ in
            screen.reveal(screen.answerSummary)
            assertLabel(screen.answerSummary, equals: "Deneyim: 6 · Bilgi: 2")
        }

        XCTContext.runActivity(named: "TestFlight'ı işaretle: bilgi düzeyinden deneyime geçer") { _ in
            screen.toggleExperience(AccessibilityID.CICD.ExperienceID.testFlightUpload)
            screen.reveal(screen.answerSummary)
            assertLabel(screen.answerSummary, equals: "Deneyim: 7 · Bilgi: 1")
            assertLabel(screen.answerText, contains: "TestFlight'a yüklemeyi otomatikleştirdim")
        }
    }
}
