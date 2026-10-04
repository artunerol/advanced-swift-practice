import XCTest
@testable import BookShelf

/// Mülakat merkezinin view'dan bağımsız mantığı: "çalışıldı" işaretleri, `UserDefaults` seçimi, arama ve gruplama.
final class InterviewHubLogicTests: XCTestCase {
    private typealias TopicID = AccessibilityID.Interview.TopicID

    override func tearDown() {
        // `makeStore` testleri simülatörde gerçek bir plist dosyası oluşturur; arkada iz bırakmayalım.
        UserDefaults().removePersistentDomain(forName: StudiedTopics.uiTestingSuiteName)
        super.tearDown()
    }

    // MARK: - StudiedTopics

    func testToggleMarksAndUnmarksATopic() {
        var studied = StudiedTopics()
        studied.toggle(TopicID.delegate)
        XCTAssertTrue(studied.contains(TopicID.delegate))

        studied.toggle(TopicID.delegate)
        XCTAssertFalse(studied.contains(TopicID.delegate))
        XCTAssertEqual(studied, StudiedTopics())
    }

    func testRawValueIsSortedAndRoundTrips() {
        let studied = StudiedTopics(ids: [TopicID.typealiasTopic, TopicID.concurrency, TopicID.delegate])
        // Küme sırasızdır; saklanan metnin her seferinde aynı olması için sıralanır.
        XCTAssertEqual(studied.rawValue, "concurrency,delegate,typealias")
        XCTAssertEqual(StudiedTopics(rawValue: studied.rawValue), studied)
    }

    func testEmptyRawValueMeansNothingStudied() {
        XCTAssertEqual(StudiedTopics(rawValue: ""), StudiedTopics())
        XCTAssertEqual(StudiedTopics().rawValue, "")
    }

    func testCountIgnoresIDsThatAreNoLongerInTheCatalog() {
        // Silinmiş/yeniden adlandırılmış bir konunun kimliği UserDefaults'ta kalmış olabilir.
        let studied = StudiedTopics(ids: [TopicID.concurrency, "silinmisKonu"])
        XCTAssertEqual(studied.count(in: InterviewTopic.all), 1)
        XCTAssertEqual(studied.count(in: []), 0)
    }

    // MARK: - Hangi UserDefaults?

    func testNormalLaunchUsesStandardDefaults() {
        XCTAssertTrue(StudiedTopics.makeStore(arguments: []) === UserDefaults.standard)
    }

    func testUITestingLaunchStartsWithAFreshSeparateStore() {
        let first = StudiedTopics.makeStore(arguments: [LaunchArgument.uiTesting])
        XCTAssertFalse(first === UserDefaults.standard, "UI testleri geliştiricinin gerçek işaretlerine dokunmamalı.")
        first.set("concurrency", forKey: StudiedTopics.storageKey)

        // Yeni bir "açılış": Önceki çalıştırmadan kalan değer silinmiş olmalı.
        let second = StudiedTopics.makeStore(arguments: [LaunchArgument.uiTesting])
        XCTAssertNil(second.string(forKey: StudiedTopics.storageKey))
    }

    // MARK: - Arama

    func testEmptyOrWhitespaceQueryReturnsEverything() {
        XCTAssertEqual(InterviewTopic.filtered(InterviewTopic.all, matching: "").map(\.id), InterviewTopic.all.map(\.id))
        XCTAssertEqual(InterviewTopic.filtered(InterviewTopic.all, matching: "  \n").map(\.id), InterviewTopic.all.map(\.id))
    }

    func testSearchIgnoresCaseAndSurroundingSpaces() {
        for query in ["actor", "ACTOR", "  Actor "] {
            let ids = InterviewTopic.filtered(InterviewTopic.all, matching: query).map(\.id)
            XCTAssertTrue(ids.contains(TopicID.concurrency), "'\(query)' araması concurrency konusunu bulmalı: \(ids)")
        }
    }

    func testSearchMatchesSectionNameAndShortAnswer() {
        // Bölüm adı: "Bonus".
        let bonus = InterviewTopic.filtered(InterviewTopic.all, matching: "bonus").map(\.id)
        XCTAssertTrue(bonus.contains(TopicID.concurrency) && bonus.contains(TopicID.objcInterop), "\(bonus)")

        // Yalnızca kısa cevapta geçen bir kelime: "köprü başlığı".
        let bridging = InterviewTopic.filtered(InterviewTopic.all, matching: "köprü başlığı").map(\.id)
        XCTAssertTrue(bridging.contains(TopicID.objcInterop), "\(bridging)")
    }

    func testSearchWithNoMatchReturnsNothing() {
        XCTAssertTrue(InterviewTopic.filtered(InterviewTopic.all, matching: "zzqxw").isEmpty)
    }

    // MARK: - Gruplama

    func testGroupingSkipsSectionsWithoutTopics() {
        let groups = InterviewTopic.grouped([.objcInterop, .concurrency])
        XCTAssertEqual(groups.map(\.section), [.bonus])
        // Bölüm içindeki sıra, verilen sıradır.
        XCTAssertEqual(groups.first?.topics.map(\.id), [TopicID.objcInterop, TopicID.concurrency])
        XCTAssertTrue(InterviewTopic.grouped([]).isEmpty)
    }

    // MARK: - Kod yönlendirmesi

    func testCodePointerFileNameIsTheLastPathComponent() {
        let nested = InterviewTopic.CodePointer(file: "BookShelf/Core/Stores/FavoritesStore.swift", symbol: "FavoritesStore", note: "-")
        XCTAssertEqual(nested.fileName, "FavoritesStore.swift")

        let flat = InterviewTopic.CodePointer(file: "Makefile", symbol: "test", note: "-")
        XCTAssertEqual(flat.fileName, "Makefile")
    }
}
