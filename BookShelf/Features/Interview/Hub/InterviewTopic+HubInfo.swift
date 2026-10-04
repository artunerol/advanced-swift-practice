import Foundation

/// Bu dosyaya özel kısa ad. (Dosya düzeyinde `private`: Başka dosyalardaki adlarla çakışmaz.)
private typealias HubTopicID = AccessibilityID.Interview.TopicID

/// Merkez listesinin görsel bilgileri: her satırın simgesi ve "Demo: ..." ipucu, her bölümün kısa açıklaması.
///
/// Neden `InterviewTopic`'in içinde bir alan değil de burada? Konu modeli, konu sahiplerinin doldurduğu
/// **içerik** sözleşmesidir (soru, cevap, demo). Simge ve satır ipucu ise yalnızca merkez ekranın **sunum**
/// kararıdır. Ayrı tutunca merkezin görünümünü değiştirmek 16 konu dosyasına dokunmayı gerektirmez.
/// Bedeli: Bir konunun demosu değişirse buradaki ipucu da elle güncellenmeli. `InterviewCatalogTests`
/// her konunun burada bir kaydı olduğunu ve simgelerin gerçekten var olduğunu denetler.
extension InterviewTopic {
    struct HubInfo: Hashable, Sendable {
        /// SF Symbol adı.
        let systemImage: String
        /// Satırın ikinci satırı, ör. "Demo: UIKit · yaşam döngüsü günlüğü".
        let demoHint: String
    }

    /// Bu konunun merkezdeki simgesi ve ipucu. Kaydı olmayan (yeni eklenmiş) bir konu çökmez, genel bir görünüm alır.
    var hubInfo: HubInfo {
        Self.hubInfoByID[id] ?? Self.fallbackHubInfo
    }

    static let fallbackHubInfo = HubInfo(systemImage: "questionmark.bubble", demoHint: "Demo")

    /// Konu kimliği → merkezdeki görünüm. Sıra, `InterviewTopic.all` ile aynı.
    static let hubInfoByID: [String: HubInfo] = [
        // Swift temelleri
        HubTopicID.protocolExtension: HubInfo(systemImage: "puzzlepiece.extension", demoHint: "Demo: dispatch · varsayılan · koşullu extension"),
        HubTopicID.protocolAsType: HubInfo(systemImage: "questionmark.diamond", demoHint: "Demo: 16 soruluk \"derlenir mi?\" quiz'i"),
        HubTopicID.structVsClass: HubInfo(systemImage: "square.on.square", demoHint: "Demo: kopyalama · CoW · ARC · bellek"),
        HubTopicID.typealiasTopic: HubInfo(systemImage: "tag", demoHint: "Demo: closure, birleşim ve generic alias örnekleri"),
        HubTopicID.arcRetainCycle: HubInfo(systemImage: "arrow.triangle.2.circlepath", demoHint: "Demo: UIKit · 5 sızıntı ve düzeltilmiş halleri"),
        // UIKit
        HubTopicID.vcLifecycle: HubInfo(systemImage: "arrow.clockwise.circle", demoHint: "Demo: UIKit · yaşam döngüsü günlüğü"),
        HubTopicID.dynamicCells: HubInfo(systemImage: "list.bullet.rectangle", demoHint: "Demo: UIKit · self-sizing hücreler"),
        HubTopicID.frameVsBounds: HubInfo(systemImage: "rectangle.dashed", demoHint: "Demo: UIKit · frame ve bounds değerleri"),
        HubTopicID.tableVsCollection: HubInfo(systemImage: "square.grid.2x2", demoHint: "Demo: UIKit · tablo, liste ve ızgara"),
        HubTopicID.delegate: HubInfo(systemImage: "arrow.left.arrow.right", demoHint: "Demo: UIKit · yıldız kontrolü · sahiplik şeması"),
        // Mimari
        HubTopicID.architecture: HubInfo(systemImage: "square.stack.3d.up", demoHint: "Demo: okuma notları · VIPER ve MVVM yan yana"),
        HubTopicID.dipVsDi: HubInfo(systemImage: "arrow.up.arrow.down", demoHint: "Demo: 3 sayaç · Environment ile enjeksiyon"),
        // Veri
        HubTopicID.persistence: HubInfo(systemImage: "externaldrive", demoHint: "Demo: 5 depo yan yana · Keychain · @AppStorage"),
        // Süreç
        HubTopicID.cicd: HubInfo(systemImage: "gearshape.2", demoHint: "Demo: 8 aşamalı pipeline · cevap taslağı"),
        // Bonus
        HubTopicID.concurrency: HubInfo(systemImage: "bolt.horizontal", demoHint: "Demo: SwiftUI · 4 deney"),
        HubTopicID.objcInterop: HubInfo(systemImage: "chevron.left.forwardslash.chevron.right", demoHint: "Demo: Objective-C · ISBN doğrulayıcı"),
    ]
}

extension InterviewTopic.Section {
    /// Bölüm başlığının altındaki kısa açıklama.
    var summary: String {
        switch self {
        case .swift: "Dilin kendisi: tipler, protokoller, bellek"
        case .uikit: "Ekran, görünüm ve liste soruları"
        case .architecture: "Katmanlar, sorumluluklar, bağımlılıklar"
        case .data: "Veriyi nerede ve nasıl saklarsın?"
        case .process: "Kodun derlenmesi, test edilmesi, dağıtılması"
        case .bonus: "Sık gelen ek konular"
        }
    }

    /// UI testlerinin bölümü bulduğu sabit anahtar (bkz. `AccessibilityID.Interview.SectionKey`).
    var accessibilityKey: String {
        typealias Key = AccessibilityID.Interview.SectionKey
        return switch self {
        case .swift: Key.swift
        case .uikit: Key.uikit
        case .architecture: Key.architecture
        case .data: Key.data
        case .process: Key.process
        case .bonus: Key.bonus
        }
    }
}
