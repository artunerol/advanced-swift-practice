import Foundation

extension PipelineStage {
    private typealias StageID = AccessibilityID.CICD.StageID

    private static let ciWorkflow = ".github/workflows/ci.yml"
    private static let releaseWorkflow = ".github/workflows/release.yml"
    private static let ciScript = "scripts/ci.sh"

    /// Tipik bir iOS hattının sekiz aşaması, çalışma sırasıyla: önce CI (her değişiklikte), sonra CD (sürümde).
    static let all: [PipelineStage] = [
        PipelineStage(
            id: StageID.commit,
            title: "Commit / PR",
            phase: .ci,
            summary: "Her push ve pull request hattı tetikler.",
            explanation: """
            Geliştirici dalını push'lar ve pull request açar; CI kendiliğinden başlar ve sonuç PR'da bir kontrol \
            (check) olarak görünür. Branch protection ile kontroller geçmeden birleştirme engellenir. Aynı PR'a yeni \
            bir push gelirse eski çalıştırma iptal edilir (concurrency), macOS dakikaları boşa gitmez.
            """,
            tools: ["GitHub / GitLab / Bitbucket", "Branch protection, rulesets", "Danger (PR'a otomatik yorum)", "Kod incelemesi"],
            repoLocations: [
                RepoLocation(file: ciWorkflow, anchor: "pull_request"),
                RepoLocation(file: ciWorkflow, anchor: "concurrency"),
            ],
            absenceNote: nil
        ),
        PipelineStage(
            id: StageID.lint,
            title: "Lint / Quiz",
            phase: .ci,
            summary: "Saniyeler süren statik kontroller, derlemeden önce.",
            explanation: """
            Stil ve yaygın hata kuralları (SwiftLint, SwiftFormat) gibi hızlı denetimler pahalı derlemeden ÖNCE \
            koşar: Bir sorun varsa hat birkaç saniyede kırmızı yanar (fail fast). Bu projede bu konumda quiz kontrolü \
            var: "Bu kod derlenir mi?" sorularının cevabını gerçek Swift derleyicisine sorar.
            """,
            tools: ["SwiftLint", "SwiftFormat", "Danger", "Periphery (kullanılmayan kod)"],
            repoLocations: [
                RepoLocation(file: ciWorkflow, anchor: "Swift quiz örneklerini derleyiciyle doğrula"),
                RepoLocation(file: ciScript, anchor: "cmd_quiz"),
            ],
            absenceNote: nil
        ),
        PipelineStage(
            id: StageID.build,
            title: "Derleme",
            phase: .ci,
            summary: "Uygulama ve test paketleri BİR kez derlenir.",
            explanation: """
            xcodebuild build-for-testing uygulamayı, test paketlerini ve bir .xctestrun dosyasını üretir; sonraki \
            test adımları yeniden derlemez. Derleme hatası kendi adımında görünür. Kod kapsamı ölçümü de derleme \
            anında açılır. Büyük projelerde Swift paketleri önbelleğe (cache) alınır.
            """,
            tools: ["xcodebuild", "xcbeautify", "Tuist / XcodeGen (proje üretimi)", "actions/cache (SPM önbelleği)"],
            repoLocations: [
                RepoLocation(file: ciWorkflow, anchor: "Derle (build-for-testing)"),
                RepoLocation(file: ciScript, anchor: "cmd_build"),
            ],
            absenceNote: nil
        ),
        PipelineStage(
            id: StageID.unitTests,
            title: "Birim testleri",
            phase: .ci,
            summary: "Derlemeden, simülatörde; tekrar (retry) yok.",
            explanation: """
            test-without-building -only-testing:BookShelfTests yalnızca birim testlerini koşar; sonuçlar ve kod \
            kapsamı bir .xcresult paketine yazılır. Birim testleri deterministik olmak zorunda. Bu yüzden burada \
            tekrar yok: Ara sıra kalan bir birim testi gerçek bir hatadır, tekrar onu gizler.
            """,
            tools: ["XCTest", "Swift Testing", "xccov (kapsam)", "xcresulttool"],
            repoLocations: [
                RepoLocation(file: ciWorkflow, anchor: "Birim testleri (XCTest)"),
                RepoLocation(file: ciWorkflow, anchor: "Kod kapsamı özeti"),
                RepoLocation(file: ciScript, anchor: "cmd_unit"),
            ],
            absenceNote: nil
        ),
        PipelineStage(
            id: StageID.uiTests,
            title: "UI testleri",
            phase: .ci,
            summary: "Uçtan uca akışlar; sınırlı tekrar, her durumda rapor.",
            explanation: """
            XCUITest uygulamayı ayrı bir süreç olarak açar ve kullanıcı gibi dokunur. Yavaş ve dış etkenlere açık \
            oldukları için başarısız bir test bir kez daha denenir (-retry-tests-on-failure). Sonuç paketi, hata \
            anındaki ekran görüntüleriyle birlikte testler kırılsa bile (if: always()) artifact olarak saklanır.
            """,
            tools: ["XCUITest", "Test planları (.xctestplan)", "Firebase Test Lab / BrowserStack (gerçek cihaz)", "Paralel test, sharding"],
            repoLocations: [
                RepoLocation(file: ciWorkflow, anchor: "UI testleri (XCUITest)"),
                RepoLocation(file: ciWorkflow, anchor: "Test sonuçlarını yükle (.xcresult)"),
                RepoLocation(file: ciScript, anchor: "cmd_ui"),
            ],
            absenceNote: nil
        ),
        PipelineStage(
            id: StageID.archive,
            title: "Arşiv",
            phase: .cd,
            summary: "Release derlemesi, sürüm ve build numarası.",
            explanation: """
            xcodebuild archive uygulamayı Release yapılandırmasıyla gerçek cihaz için derler ve dSYM'lerle birlikte \
            bir .xcarchive üretir. Sürüm (1.2.0) git etiketinden, build numarası CI çalıştırma numarasından gelir. \
            Bu projede arşiv İMZASIZ (CODE_SIGNING_ALLOWED=NO): Cihaza kurulamaz ama Release derlemesini kanıtlar; \
            etiket push'unda GitHub Release'e eklenir.
            """,
            tools: ["xcodebuild archive", "fastlane gym", "agvtool / fastlane increment_build_number", "GitHub Releases"],
            repoLocations: [
                RepoLocation(file: releaseWorkflow, anchor: "Arşivle (xcodebuild archive, CODE_SIGNING_ALLOWED=NO)"),
                RepoLocation(file: releaseWorkflow, anchor: "GitHub Release oluştur"),
                RepoLocation(file: ciScript, anchor: "cmd_archive"),
            ],
            absenceNote: nil
        ),
        PipelineStage(
            id: StageID.testFlight,
            title: "TestFlight",
            phase: .cd,
            summary: "İmzala, dışa aktar, App Store Connect'e yükle.",
            explanation: """
            Dağıtım sertifikası (.p12) ve App Store provisioning profile'ı geçici bir keychain'e yüklenir, arşiv \
            imzalanır, xcodebuild -exportArchive (method: app-store-connect, destination: upload) App Store Connect \
            API anahtarıyla yükler. İç test kullanıcıları build işlendikten sonra inceleme beklemeden test edebilir; \
            dış test kullanıcıları için sürümün ilk build'i Apple'ın beta incelemesinden geçer. Bu depoda bu iş bir \
            ŞABLON: Secrets tanımlı değilse atlanır ve gerçek bir hesapla hiç çalıştırılmadı.
            """,
            tools: ["fastlane match + pilot", "Xcode Cloud", "xcrun altool / Transporter", "Firebase App Distribution"],
            repoLocations: [
                RepoLocation(file: releaseWorkflow, anchor: "İmzalama secrets'ı tanımlı mı?"),
                RepoLocation(file: releaseWorkflow, anchor: "TestFlight'a yükle (şablon)"),
            ],
            absenceNote: nil
        ),
        PipelineStage(
            id: StageID.appStore,
            title: "App Store",
            phase: .cd,
            summary: "İncelemeye gönderme ve yayın: çoğunlukla insan kararı.",
            explanation: """
            TestFlight'ta denenen build seçilir; mağaza metinleri ve ekran görüntüleriyle App Review'a gönderilir. \
            Onaydan sonra hemen, belirli bir tarihte ya da otomatik güncellemeleri 7 güne yayan kademeli yayınla \
            (phased release) çıkar. Bu adım bir insan kararıyla yapılıyorsa süreç Continuous Delivery'dir; o da \
            otomatikse Continuous Deployment.
            """,
            tools: ["App Store Connect", "fastlane deliver", "App Store Connect API"],
            repoLocations: [],
            absenceNote: "Bu depoda yok: Mağazaya gönderim bilinçli olarak elle bırakıldı (ve bir Apple Developer hesabı gerektirir)."
        ),
    ]
}
