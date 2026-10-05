import Foundation

extension InterviewTopic {
    /// Merkezde gösterilen tüm konular, ekrandaki sırayla. Bölüm başlıkları `section` alanından gelir.
    ///
    /// Sıra, mülakatta sorulan soruların sırası. Yeni bir konu eklemek = `Topics/` altında yeni bir dosya +
    /// buraya bir satır (+ `Hub/InterviewTopic+HubInfo.swift`'te simge ve ipucu).
    static let all: [InterviewTopic] = [
        .protocolExtension,
        .protocolAsType,
        .structVsClass,
        .typealiasTopic,
        .arcRetainCycle,
        .vcLifecycle,
        .dynamicCells,
        .frameVsBounds,
        .tableVsCollection,
        .delegate,
        .architecture,
        .dipVsDi,
        .viperService,
        .persistence,
        .cicd,
        .concurrency,
        .objcInterop,
    ]
}

// MARK: - Merkez listesi için gruplama ve arama

extension InterviewTopic {
    /// Bir bölüm ve o bölümdeki konular. `ForEach` bir kimlik ister; bölüm her grupta tek olduğu için kimlik odur.
    ///
    /// Adı neden `Group` değil? İç içe (nested) bir tip, `extension InterviewTopic { ... }` içindeki kodda aynı adlı
    /// dış tipleri gölgeler. Konu dosyalarında `Group { ... }` yazan biri SwiftUI'ın `Group`'u yerine bunu bulurdu.
    struct SectionGroup: Identifiable {
        let section: Section
        let topics: [InterviewTopic]
        var id: Section { section }
    }

    /// Konuları `Section` sırasıyla gruplar; konusu olmayan bölümleri atlar. Bölüm içindeki sıra korunur.
    ///
    /// Saf (pure) bir fonksiyon: Girdi aynıysa çıktı aynı, yan etkisi yok. Bu yüzden view'dan ayrı, birim testiyle
    /// doğrudan denetlenebilir (`InterviewHubLogicTests`).
    static func grouped(_ topics: [InterviewTopic]) -> [SectionGroup] {
        Section.allCases.compactMap { section in
            let topicsInSection = topics.filter { $0.section == section }
            return topicsInSection.isEmpty ? nil : SectionGroup(section: section, topics: topicsInSection)
        }
    }

    /// Arama kutusu için filtre. Boş (ya da yalnızca boşluk olan) arama her şeyi döndürür.
    ///
    /// Soruda, bölüm adında ve kısa cevapta arar. `localizedStandardContains`, Finder'ın aramasıyla aynı kuralları
    /// uygular: büyük/küçük harf ve aksan (diakritik) farkını yok sayar ("ACTOR" → "actor", "ozellik" → "özellik")
    /// ve cihazın diline göre karşılaştırır. Dikkat: "ı" aksanlı bir "i" değil, ayrı bir harftir; "sinif" araması
    /// "sınıf"ı bulmaz.
    static func filtered(_ topics: [InterviewTopic], matching query: String) -> [InterviewTopic] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return topics }
        return topics.filter { topic in
            topic.question.localizedStandardContains(query)
                || topic.section.rawValue.localizedStandardContains(query)
                || topic.shortAnswer.contains { $0.localizedStandardContains(query) }
        }
    }
}
