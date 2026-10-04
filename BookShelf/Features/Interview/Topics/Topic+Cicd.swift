import SwiftUI

extension InterviewTopic {
    /// "CI/CD ile çalıştın mı? Hangi araçları kullandın?"
    ///
    /// Bu soru bilgi kadar DÜRÜSTLÜK de ölçer: Mülakatçı cevabındaki her aracı bir ek soruyla yoklar.
    /// Demo (`CICDTopicView`) hem pipeline'ı gösterir hem de yalnızca gerçekten yaptıklarını iddia eden bir
    /// cevap taslağı üretir. Ayrıntılı ders: docs/11-ci.md.
    static let cicd = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.cicd,
        section: .process,
        question: "CI/CD ile çalıştın mı? Hangi araçları kullandın?",
        shortAnswer: [
            "CI: Her push ve PR'da temiz bir makinede otomatik derleme ve test. Amaç: ana dal her an derlenir ve testleri geçer halde.",
            "CD: Geçen build'i otomatik olarak dağıtılabilir pakete çevirmek. Continuous Delivery'de yayın kararı insanda, Continuous Deployment'ta o da otomatik. iOS'ta App Review yüzünden mağazaya tam otomatik yayın yok; pratikte TestFlight'a otomatik dağıtım, mağazaya insan onayı.",
            "Tipik iOS hattı: lint → bir kez derle (build-for-testing) → birim ve UI testleri → .xcresult artifact. Sürüm etiketinde: arşiv → imzalama → TestFlight.",
            "Code signing = sertifika (kim imzalıyor) + provisioning profile (hangi App ID, hangi sertifikalar, hangi yetkiler; geliştirme ve ad hoc'ta hangi cihazlar). CI'da geçici bir keychain'e yüklenir ya da fastlane match kullanılır.",
            "Sırlar secrets'ta durur, loga asla yazılmaz; TestFlight'a App Store Connect API anahtarıyla yüklenir. Hız için önbellek; flaky UI testinde önce kök neden, sonra sınırlı tekrar.",
        ],
        followUps: [
            FollowUp(
                question: "build-for-testing ve test-without-building neden ayrı?",
                answer: """
                Derleme bir kez yapılır; ürünler ve .xctestrun dosyasıyla birim ve UI testleri yeniden derlenmeden \
                koşar. Derleme hatası ile test hatası ayrı adımlarda görünür. Ürünler başka makinelere dağıtılıp \
                testler bölünebilir (sharding).
                """
            ),
            FollowUp(
                question: "Sürüm ve build numarasını nasıl yönetirsin?",
                answer: """
                Sürüm (CFBundleShortVersionString, ör. 1.2.0) bir insan kararıdır ve git etiketinden gelir. Build \
                numarası (CFBundleVersion) her yüklemede artmalı: App Store Connect aynı sürüm için aynı numarayı ikinci \
                kez kabul etmez. CI çalıştırma numarasını CURRENT_PROJECT_VERSION=... ile komut satırından veririm; \
                projeye commit'lemem. Alternatifler: agvtool, fastlane increment_build_number.
                """
            ),
            FollowUp(
                question: "Hangi CI araçlarını biliyorsun, nasıl seçersin?",
                answer: """
                GitHub Actions (depoyla entegre, macOS runner), Xcode Cloud (Apple'ın; imzalama ve TestFlight hazır), \
                Bitrise ve Codemagic (mobil odaklı, hazır adımlar), Jenkins (self-hosted, esnek ama bakım yükü), \
                GitLab CI, CircleCI. Otomasyon için fastlane. Seçim ölçütleri: kodun nerede durduğu, macOS makine \
                maliyeti, imzalama ihtiyacı ve ekibin deneyimi.
                """
            ),
            FollowUp(
                question: "fastlane match ne işe yarar?",
                answer: """
                Sertifikaları ve profilleri şifreli olarak özel bir git deposunda (ya da bulut depolamada) tutar; bütün \
                ekip ve CI aynı imzalama kimliğini kullanır. CI'da salt okunur modda (readonly) yalnızca indirir, yeni \
                sertifika üretmez. Böylece "sadece benim Mac'imde imzalanıyor" sorunu ve gereksiz sertifika iptalleri biter.
                """
            ),
            FollowUp(
                question: "Testler CI'da kırıldı, lokalde geçiyor. Ne yaparsın?",
                answer: """
                Önce .xcresult'ı indirip hatayı ve ekran görüntüsünü incelerim. Sonra ortam farkına bakarım: Xcode/SDK \
                sürümü, simülatör ve iOS sürümü, zaman dilimi ve dil, test sırası, yavaş makinede zamanlama. Lokalde \
                aynı komutu (ci.sh) çalıştırır, gerekirse testi tekrar tekrar koşturup (Run Repeatedly) yeniden üretirim.
                """
            ),
        ],
        pitfalls: [
            """
            Yapmadığın şeyi yapmış gibi anlatmak. "TestFlight'a otomatik yükleme kurdum" dersen ilk ek soru keychain, \
            profil ve API anahtarı olur. Bu projede imzalı yükleme bir şablon; "şablonunu biliyorum, gerçek hesapla \
            koşmadım" demek güçlü bir cevaptır.
            """,
            """
            `xcodebuild ... | xcbeautify` zincirinde pipefail olmaması: Testler kırılsa bile çıkış kodu xcbeautify'ınki \
            (0) olur ve CI yeşil görünür.
            """,
            """
            Sırları loga sızdırmak: `echo $SECRET`, `set -x` ya da base64'ten çözülmüş değeri yazdırmak. CI yalnızca \
            secret'ın kendisini maskeler; türetilmiş değeri maskeleyemez.
            """,
            """
            Birim testlerine de tekrar (retry) açmak. Deterministik olması gereken bir testin ara sıra kalması gerçek \
            bir hatadır (çoğunlukla yarış durumu); tekrar onu gizler.
            """,
        ],
        codePointers: [
            CodePointer(
                file: ".github/workflows/ci.yml",
                symbol: "build-and-test",
                note: "Adım sırası: quiz (fail fast) → build-for-testing → birim → UI testleri. UI adımının if: koşuluna, adım zaman sınırlarına ve if: always() ile .xcresult yüklemesine bak."
            ),
            CodePointer(
                file: "scripts/ci.sh",
                symbol: "cmd_ui",
                note: "-retry-tests-on-failure yalnızca UI testlerinde. Dosyanın başındaki set -euo pipefail olmasa xcbeautify kırık testi yeşile çevirirdi."
            ),
            CodePointer(
                file: "scripts/ci.sh",
                symbol: "cmd_archive",
                note: "Sürüm ve build numarası CURRENT_PROJECT_VERSION / MARKETING_VERSION override ile verilir, arşivden geri okunup doğrulanır; CODE_SIGNING_ALLOWED=NO ile imzasız."
            ),
            CodePointer(
                file: ".github/workflows/release.yml",
                symbol: "signing-check",
                note: "İş düzeyindeki if: secrets'ı okuyamaz. Ucuz bir Linux işi secrets'ın var olup olmadığını çıktı olarak verir, testflight işi needs ile ona bakar."
            ),
            CodePointer(
                file: ".github/workflows/release.yml",
                symbol: "testflight",
                note: "Şablon: geçici keychain, set-key-partition-list, profil kurulumu, manuel imzalı arşiv, ExportOptions.plist (app-store-connect + upload) ve API anahtarıyla yükleme."
            ),
            CodePointer(
                file: "BookShelf/App/AppDependencies.swift",
                symbol: "makeForLaunch",
                note: "-ui-testing argümanı gecikmeyi sıfırlar ve notları bellekte tutar: Flaky UI testlerine karşı ilk savunma uygulama kodunda."
            ),
        ],
        demo: { _ in AnyView(CICDTopicView()) }
    )
}
