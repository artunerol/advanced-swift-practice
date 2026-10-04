import Foundation

/// "Mülakatta nasıl anlatırsın?" kontrol listesindeki bir CI/CD deneyimi.
///
/// Her deneyimin iki cümlesi var:
/// - `claim`: Gerçekten yaptıysan söyleyeceğin cümle ("... yapıyorum").
/// - `knowledge`: Yapmadıysan dürüstçe söyleyebileceğin "nasıl yapıldığını biliyorum" cümlesi.
///
/// Mülakatta en kötü cevap, yapmadığın bir şeyi yapmış gibi anlatmaktır: İlk ek soru (ör. "keychain'i nasıl
/// kurdun?") bunu ortaya çıkarır. Bu yüzden cevap (`CICDInterviewAnswer`) yalnızca işaretlenenleri iddia eder;
/// işaretlenmeyenler "bildiğim" kısmında kalır.
enum CICDExperience: CaseIterable, Identifiable, Sendable {
    case ciPipeline
    case buildOnceTestTwice
    case xcresultArtifacts
    case uiRetries
    case versioning
    case releaseArchive
    case ciSigning
    case testFlightUpload

    private typealias ExperienceID = AccessibilityID.CICD.ExperienceID

    /// Bu depoda GERÇEKTEN çalışan parçalar: Kontrol listesi bunlarla işaretli başlar.
    /// İmzalama ve TestFlight burada yalnızca şablon olduğu için dahil DEĞİL.
    static let projectDefaults: Set<CICDExperience> = [
        .ciPipeline, .buildOnceTestTwice, .xcresultArtifacts, .uiRetries, .versioning, .releaseArchive,
    ]

    var id: String {
        switch self {
        case .ciPipeline: ExperienceID.ciPipeline
        case .buildOnceTestTwice: ExperienceID.buildOnceTestTwice
        case .xcresultArtifacts: ExperienceID.xcresultArtifacts
        case .uiRetries: ExperienceID.uiRetries
        case .versioning: ExperienceID.versioning
        case .releaseArchive: ExperienceID.releaseArchive
        case .ciSigning: ExperienceID.ciSigning
        case .testFlightUpload: ExperienceID.testFlightUpload
        }
    }

    /// Kontrol listesindeki kısa etiket.
    var label: String {
        switch self {
        case .ciPipeline: "Her PR'da otomatik derleme ve test"
        case .buildOnceTestTwice: "build-for-testing + test-without-building"
        case .xcresultArtifacts: ".xcresult'ı artifact olarak saklayıp inceleme"
        case .uiRetries: "Flaky UI testleri: kök neden + sınırlı tekrar"
        case .versioning: "Build numarasını CI'dan otomatik verme"
        case .releaseArchive: "Etikette Release arşivi ve GitHub Release"
        case .ciSigning: "CI'da code signing (keychain + profil ya da match)"
        case .testFlightUpload: "TestFlight'a otomatik yükleme"
        }
    }

    /// Gerçekten yaptıysan söyleyeceğin cümle.
    var claim: String {
        switch self {
        case .ciPipeline:
            "Kendi iOS projemde her pull request'te ve main'e her push'ta GitHub Actions'ın macOS makinesinde derleme ve testler otomatik koşuyor; sonuç PR'da bir kontrol olarak görünüyor."
        case .buildOnceTestTwice:
            "Derlemeyi build-for-testing ile bir kez yapıp birim ve UI testlerini test-without-building ile ayrı adımlarda koşturuyorum; derleme hatası ile test hatası ayrı görünüyor."
        case .xcresultArtifacts:
            "Test sonuç paketlerini (.xcresult) testler kırılsa bile artifact olarak saklıyorum; kırılan bir testi indirip Xcode'da ekran görüntüleriyle inceliyorum."
        case .uiRetries:
            "Flaky UI testlerinde önce kök nedeni düzeltiyorum: sabit bekleme yerine waitForExistence, metin yerine erişilebilirlik kimlikleri, test modunda animasyonları kapatmak. Kalanlar için yalnızca UI testlerinde tek bir tekrar açık."
        case .versioning:
            "Build numarasını CI çalıştırma numarasından, sürümü git etiketinden veriyorum; projeye elle numara commit'lemiyorum."
        case .releaseArchive:
            "Etiket push'unda Release arşivi üreten ayrı bir workflow kullanıyorum. Arşiv şimdilik imzasız: Release derlemesini ve sürüm numaralarını kanıtlıyor ama dağıtılamıyor."
        case .ciSigning:
            "CI'da imzalamayı kurdum: Sertifikayı ve provisioning profile'ı CI'da geçici bir keychain'e (ya da fastlane match ile) yükledim; sırlar yalnızca secrets'ta duruyor."
        case .testFlightUpload:
            "TestFlight'a yüklemeyi otomatikleştirdim; kimlik doğrulama Apple ID ve parolayla değil, App Store Connect API anahtarıyla."
        }
    }

    /// Yapmadıysan dürüstçe söyleyebileceğin cümle: "Nasıl yapıldığını biliyorum."
    var knowledge: String {
        switch self {
        case .ciPipeline:
            "CI: Her PR'da temiz bir makinede derleme ve test; branch protection ile kırmızı kontrol varken birleştirme engellenir."
        case .buildOnceTestTwice:
            "build-for-testing / test-without-building: Bir kez derleyip testleri yeniden derlemeden, ayrı adımlarda ya da ayrı makinelerde koşturmak."
        case .xcresultArtifacts:
            ".xcresult: Her durumda (if: always()) artifact olarak saklanır; Xcode'da ya da xcresulttool ile okunur."
        case .uiRetries:
            "Flaky testler: Önce kök neden (waitForExistence, erişilebilirlik kimlikleri, deterministik veri); tekrar (retry) yalnızca UI testlerinde ve sınırlı."
        case .versioning:
            "Sürümleme: CFBundleVersion her yüklemede artmalı; CI çalıştırma numarasından CURRENT_PROJECT_VERSION ile verilebilir."
        case .releaseArchive:
            "Arşiv: Release yapılandırması ve generic/platform=iOS hedefi; dSYM'ler çökme raporları için saklanır."
        case .ciSigning:
            "CI'da imzalama: .p12 sertifika ve provisioning profile secrets'tan geçici bir keychain'e yüklenir ya da fastlane match kullanılır; Xcode Cloud bunu kendisi yönetir."
        case .testFlightUpload:
            "TestFlight: xcodebuild -exportArchive (method app-store-connect, destination upload) ve App Store Connect API anahtarı; alternatifi fastlane pilot."
        }
    }
}

/// Seçilen deneyimlerden üretilen cevap taslağı. Saf bir değer: aynı seçim her zaman aynı metni verir
/// (birim testleriyle doğrulanır).
struct CICDInterviewAnswer: Equatable, Sendable {
    /// İddia edilenler (işaretli), kontrol listesindeki sırayla.
    let claims: [CICDExperience]
    /// Yalnızca bilgi düzeyinde anlatılanlar (işaretsiz).
    let knowledgeOnly: [CICDExperience]

    init(selected: Set<CICDExperience>) {
        claims = CICDExperience.allCases.filter { selected.contains($0) }
        knowledgeOnly = CICDExperience.allCases.filter { !selected.contains($0) }
    }

    static let experienceOpening = "Evet. Somut olarak yaptıklarım şunlar:"
    static let noExperienceOpening = "Bir ekipte CI/CD'yi kendim kurup yönetmedim; ama bir iOS hattının nasıl çalıştığını ve neden öyle kurulduğunu anlatabilirim."
    static let knowledgeHeader = "Kendim yapmadığım ama nasıl yapıldığını bildiğim kısımlar:"
    static let closing = "Araç seçerken kodun nerede durduğuna, macOS makine maliyetine ve imzalama ihtiyacına bakarım: GitHub Actions, Xcode Cloud ya da Bitrise; tekrarlanan işler için fastlane."

    /// Ekrandaki sayaç, ör. "Deneyim: 6 · Bilgi: 2".
    var summary: String { "Deneyim: \(claims.count) · Bilgi: \(knowledgeOnly.count)" }

    var paragraphs: [String] {
        var result: [String] = []
        if claims.isEmpty {
            result.append(Self.noExperienceOpening)
        } else {
            result.append(([Self.experienceOpening] + claims.map { "• \($0.claim)" }).joined(separator: "\n"))
        }
        if !knowledgeOnly.isEmpty {
            let bullets = knowledgeOnly.map { "• \($0.knowledge)" }
            result.append(([Self.knowledgeHeader] + bullets).joined(separator: "\n"))
        }
        result.append(Self.closing)
        return result
    }

    var text: String { paragraphs.joined(separator: "\n\n") }
}
