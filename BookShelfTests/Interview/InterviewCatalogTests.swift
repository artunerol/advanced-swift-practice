import UIKit
import XCTest
@testable import BookShelf

/// Mülakat kataloğunun (`InterviewTopic.all`) değişmez kuralları (invariants).
///
/// Konu içeriği 16 ayrı dosyada, farklı kişilerin elinden çıkıyor. Bu testler "her konu doğru yerde mi, kimliği
/// doğru mu, içerik kurallara uyuyor mu, Kod bölümündeki yollar gerçekten var mı?" sorularını her derlemede sorar.
final class InterviewCatalogTests: XCTestCase {
    private typealias TopicID = AccessibilityID.Interview.TopicID

    /// Kullanıcının mülakatta karşılaştığı sıra.
    private static let expectedOrder = [
        TopicID.protocolExtension, TopicID.protocolAsType, TopicID.structVsClass, TopicID.typealiasTopic,
        TopicID.arcRetainCycle,
        TopicID.vcLifecycle, TopicID.dynamicCells, TopicID.frameVsBounds, TopicID.tableVsCollection, TopicID.delegate,
        TopicID.architecture, TopicID.dipVsDi,
        TopicID.persistence,
        TopicID.cicd,
        TopicID.concurrency, TopicID.objcInterop,
    ]

    // MARK: - Katalog yapısı

    func testCatalogListsAllSixteenTopicsInInterviewOrder() {
        XCTAssertEqual(InterviewTopic.all.map(\.id), Self.expectedOrder)
    }

    func testTopicIDsAreUnique() {
        let ids = InterviewTopic.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Aynı kimliği kullanan iki konu var: \(ids)")
    }

    func testEverySectionHasTopicsAndSectionsAppearInDeclaredOrder() {
        let groups = InterviewTopic.grouped(InterviewTopic.all)
        XCTAssertEqual(groups.map(\.section), InterviewTopic.Section.allCases, "Her bölümde en az bir konu olmalı.")

        // Ekrandaki sıra, katalogdaki sırayla aynı olmalı: Bölümlere ayırmak konuların yerini değiştirmemeli.
        XCTAssertEqual(groups.flatMap(\.topics).map(\.id), InterviewTopic.all.map(\.id))
    }

    // MARK: - İçerik kuralları

    /// Kurallar (bkz. `InterviewTopic`): 3-6 kısa cevap maddesi, 3-5 ek soru, 2-4 tuzak, 3-6 kod yönlendirmesi.
    /// Henüz iskelet halindeki konular bu testte atlanır; onları `testNoTopicIsStillAPlaceholder` yakalar.
    func testFinishedTopicsFollowContentRules() {
        for topic in InterviewTopic.all where !Self.isPlaceholder(topic) {
            XCTAssertTrue((3...6).contains(topic.shortAnswer.count), "\(topic.id): kısa cevap \(topic.shortAnswer.count) madde")
            XCTAssertTrue((3...5).contains(topic.followUps.count), "\(topic.id): \(topic.followUps.count) ek soru")
            XCTAssertTrue((2...4).contains(topic.pitfalls.count), "\(topic.id): \(topic.pitfalls.count) tuzak")
            XCTAssertTrue((3...6).contains(topic.codePointers.count), "\(topic.id): \(topic.codePointers.count) kod yönlendirmesi")

            let texts = [topic.question] + topic.shortAnswer + topic.pitfalls
                + topic.followUps.flatMap { [$0.question, $0.answer] }
                + topic.codePointers.flatMap { [$0.file, $0.symbol, $0.note] }
            XCTAssertFalse(
                texts.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                "\(topic.id): boş bir metin var."
            )
        }
    }

    /// Bu projede (paralel çalışan konu sahipleri birleştirilmeden önce) bazı konular hâlâ iskelet olabilir.
    /// O durumda bu test BİLEREK kırmızıdır: "bitmemiş konu var" bilgisini görünür tutar.
    func testNoTopicIsStillAPlaceholder() {
        let placeholders = InterviewTopic.all.filter(Self.isPlaceholder).map(\.id)
        XCTAssertEqual(placeholders, [], "Hâlâ GEÇİCİ içerikli konular var: \(placeholders)")
    }

    // MARK: - Kod yönlendirmeleri gerçekten var mı?

    /// "Kod" bölümündeki her dosya yolu gerçekten var mı ve dosyada `symbol`'deki adlar geçiyor mu?
    ///
    /// Bir dosya taşınır ya da bir fonksiyonun adı değişirse yönlendirme sessizce bayatlar; çalışırken
    /// "bu dosya nerede?" diye kaybolmak en kötü öğrenme deneyimidir. Bu test bunu derleme sonrası hemen yakalar.
    ///
    /// Nasıl? Testler simülatörde çalışır ama simülatör Mac'in dosya sistemini okuyabilir. `#filePath` bu test
    /// dosyasının diskteki yolunu verir; iki klasör yukarısı projenin köküdür.
    func testCodePointersReferToExistingFilesAndSymbols() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent() // Interview/
            .deletingLastPathComponent() // BookShelfTests/
            .deletingLastPathComponent() // proje kökü
        guard FileManager.default.fileExists(atPath: root.appending(path: "BookShelf.xcodeproj").path(percentEncoded: false)) else {
            throw XCTSkip("Kaynak ağacı bu makinede yok (testler başka yerde derlenmiş olabilir): \(root.path(percentEncoded: false))")
        }

        for topic in InterviewTopic.all {
            for pointer in topic.codePointers {
                let fileURL = root.appending(path: pointer.file)
                guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    XCTFail("\(topic.id): dosya bulunamadı: \(pointer.file)")
                    continue
                }
                for name in Self.identifiers(in: pointer.symbol) {
                    XCTAssertTrue(contents.contains(name), "\(topic.id): '\(name)' \(pointer.file) içinde geçmiyor (sembol: \(pointer.symbol))")
                }
            }
        }
    }

    // MARK: - Merkezdeki görünüm bilgileri

    func testEveryTopicHasHubInfoWithAnExistingSymbol() {
        XCTAssertEqual(Set(InterviewTopic.hubInfoByID.keys), Set(InterviewTopic.all.map(\.id)), "Her konunun (ve yalnızca onların) simgesi ve ipucu olmalı.")

        let infos = InterviewTopic.all.map(\.hubInfo) + [InterviewTopic.fallbackHubInfo]
        for info in infos {
            // Yanlış yazılmış bir SF Symbol adı derleme hatası vermez; ekranda boş bir alan bırakır.
            XCTAssertNotNil(UIImage(systemName: info.systemImage), "SF Symbol bulunamadı: \(info.systemImage)")
            XCTAssertTrue(info.demoHint.hasPrefix("Demo"), "İpucu 'Demo' ile başlamalı: \(info.demoHint)")
        }
    }

    func testSectionsHaveSummariesAndUniqueAccessibilityKeys() {
        let sections = InterviewTopic.Section.allCases
        XCTAssertEqual(Set(sections.map(\.accessibilityKey)).count, sections.count)
        XCTAssertFalse(sections.contains { $0.summary.isEmpty })
    }

    // MARK: - Yardımcılar

    /// İskelet konular "GEÇİCİ" kelimesini içerir (bkz. `Topics/` altındaki iskelet dosyaları).
    private static func isPlaceholder(_ topic: InterviewTopic) -> Bool {
        let texts = [topic.question] + topic.shortAnswer + topic.pitfalls
            + topic.followUps.flatMap { [$0.question, $0.answer] }
            + topic.codePointers.map(\.note)
        return texts.contains { $0.contains("GEÇİCİ") }
    }

    /// Sembolün içindeki adlar. Parametre listesi atılır: "LongRunningJob.run(onProgress:)" → ["LongRunningJob", "run"];
    /// "+validateISBN13:error:" → ["validateISBN13", "error"].
    private static func identifiers(in symbol: String) -> [String] {
        let name = symbol.prefix { $0 != "(" }
        return name.matches(of: /[A-Za-z_][A-Za-z0-9_]*/).map { String($0.output) }
    }
}
