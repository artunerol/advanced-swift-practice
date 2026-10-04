import XCTest
@testable import BookShelf

/// Swift temelleri mülakat konularının (protocol + extension, protocol tip olarak, struct vs class, typealias)
/// içerik kuralları: madde sayıları ve "Koda bak" yönlendirmelerinin GERÇEKTEN var olan dosya ve sembollere gitmesi.
///
/// Neden test? Kod yönlendirmeleri düz metin; bir dosya taşınır ya da bir tip yeniden adlandırılırsa derleyici fark
/// etmez. Bu test, yönlendirmenin kırıldığını hemen söyler.
final class FundamentalsInterviewTopicTests: XCTestCase {
    private let topics: [InterviewTopic] = [.protocolExtension, .protocolAsType, .structVsClass, .typealiasTopic]

    func testTopicsUseTheirFrozenIDsAndSection() {
        typealias TopicID = AccessibilityID.Interview.TopicID
        XCTAssertEqual(
            topics.map(\.id),
            [TopicID.protocolExtension, TopicID.protocolAsType, TopicID.structVsClass, TopicID.typealiasTopic]
        )
        XCTAssertTrue(topics.allSatisfy { $0.section == .swift })
    }

    func testTopicsFollowTheContentRules() {
        for topic in topics {
            XCTAssertTrue((3...6).contains(topic.shortAnswer.count), "\(topic.id): kısa cevap 3-6 madde")
            XCTAssertTrue((3...5).contains(topic.followUps.count), "\(topic.id): ek soru 3-5")
            XCTAssertTrue((2...4).contains(topic.pitfalls.count), "\(topic.id): tuzak 2-4")
            XCTAssertTrue((3...6).contains(topic.codePointers.count), "\(topic.id): kod yönlendirmesi 3-6")

            let allText = topic.shortAnswer + topic.pitfalls + topic.followUps.flatMap { [$0.question, $0.answer] }
            XCTAssertFalse(allText.contains { $0.isEmpty }, "\(topic.id): boş metin")
            XCTAssertFalse(allText.contains { $0.contains("GEÇİCİ") }, "\(topic.id): iskelet metni kalmış")
        }
    }

    func testCodePointersReferToExistingFilesAndSymbols() throws {
        // Bu dosya: <kök>/BookShelfTests/Fundamentals/FundamentalsInterviewTopicTests.swift
        // Simülatördeki test süreci Mac'in dosya sistemini okuyabilir; derleme anındaki yol (#filePath) kökü verir.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for topic in topics {
            for pointer in topic.codePointers {
                let url = root.appending(path: pointer.file)
                let contents = try String(contentsOf: url, encoding: .utf8)
                XCTAssertTrue(
                    contents.contains(Self.searchableName(of: pointer.symbol)),
                    "\(topic.id): '\(pointer.symbol)' sembolü \(pointer.file) içinde bulunamadı"
                )
                XCTAssertFalse(pointer.note.isEmpty, "\(topic.id): \(pointer.symbol) için not yok")
            }
        }
    }

    /// "ProtocolDispatchDemo.observe(from:)" → "observe", "extension Book: PagedReadingItem" → "Book: PagedReadingItem".
    private static func searchableName(of symbol: String) -> String {
        var name = symbol
        if name.hasPrefix("extension ") { name.removeFirst("extension ".count) }
        if let parenthesis = name.firstIndex(of: "(") { name = String(name[..<parenthesis]) }
        if !name.contains(":"), let dot = name.lastIndex(of: ".") { name = String(name[name.index(after: dot)...]) }
        return name
    }
}
