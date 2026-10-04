import Foundation

/// "Çalışıldı" olarak işaretlenen konuların kimlikleri.
///
/// **Gerçek hayattan küçük bir `UserDefaults` örneği.** Bu bilgi küçük, gizli değil ve kaybolursa felaket
/// olmaz: tam `UserDefaults`'un işi. (Şifre/token → Keychain; büyük ya da ilişkisel veri → dosya, Core Data,
/// SwiftData. Ayrıntısı "Veri saklama yolları" konusunda.)
///
/// Ekranlar bu değeri `@AppStorage` ile okur ve yazar:
/// `@AppStorage(StudiedTopics.storageKey, store: StudiedTopics.store) var studied = StudiedTopics()`
/// - `@AppStorage`, `UserDefaults`'taki bir anahtarı SwiftUI durumu gibi kullandırır: değer değişince o anahtarı
///   okuyan HER ekran yeniden çizilir. Merkezdeki ilerleme metni, konu ekranında dokunulan ✓ ile kendiliğinden güncellenir.
/// - `@AppStorage` yalnızca basit tipleri (`Bool`, `Int`, `Double`, `String`, `URL`, `Data`) ve ham değeri `String` ya da
///   `Int` olan `RawRepresentable` tipleri saklayabilir. `Set<String>` doğrudan desteklenmez; bu yüzden tip
///   `RawRepresentable` ve kümeyi virgülle ayrılmış tek bir metin olarak saklıyor.
struct StudiedTopics: Equatable, Sendable {
    private(set) var ids: Set<String>

    init(ids: Set<String> = []) {
        self.ids = ids
    }

    func contains(_ topicID: String) -> Bool {
        ids.contains(topicID)
    }

    mutating func toggle(_ topicID: String) {
        if ids.remove(topicID) == nil {
            ids.insert(topicID)
        }
    }

    /// Verilen konulardan kaç tanesi çalışıldı?
    ///
    /// Yalnızca listede GERÇEKTEN olan konular sayılır. Bir konu ileride silinir ya da kimliği değişirse
    /// eski kimlik `UserDefaults`'ta kalır; onu da saysaydık ekranda "17 / 16" gibi bir saçmalık görünürdü.
    func count(in topics: [InterviewTopic]) -> Int {
        topics.count { ids.contains($0.id) }
    }
}

// MARK: - UserDefaults'ta saklama biçimi

extension StudiedTopics: RawRepresentable {
    /// "concurrency,delegate,typealias" → üç kimlik. Boş metin → boş küme.
    ///
    /// Başlatıcı "başarısız olabilir" (`init?`) çünkü protokol öyle istiyor; biz her metni kabul ediyoruz.
    /// Kimliklerde virgül yok (bkz. `AccessibilityID.Interview.TopicID`), bu yüzden virgül güvenli bir ayırıcı.
    init?(rawValue: String) {
        ids = Set(rawValue.split(separator: ",").map(String.init))
    }

    /// Sıralı yazıyoruz: Aynı küme her zaman aynı metni üretsin (Set'in sırası rastgeledir).
    var rawValue: String {
        ids.sorted().joined(separator: ",")
    }
}

// MARK: - Hangi UserDefaults?

extension StudiedTopics {
    /// `UserDefaults`'taki anahtar.
    static let storageKey = "interview.studiedTopicIDs"

    /// Uygulamanın kullandığı depo. Uygulama açılırken BİR kez seçilir (`static let` tembel ve thread-safe başlatılır).
    ///
    /// `@MainActor`: `UserDefaults` kendi içinde thread-safe olsa da SDK'da `Sendable` olarak işaretli DEĞİL.
    /// Swift 6, `Sendable` olmayan bir `static let`'i "paylaşılan değiştirilebilir durum" sayar ve derlemez.
    /// Değeri yalnızca view'lar (zaten `@MainActor`) okuduğu için ana actor'e bağlamak en dürüst çözüm.
    @MainActor static let store: UserDefaults = makeStore(arguments: ProcessInfo.processInfo.arguments)

    /// Depoyu başlatma argümanlarına göre seçer.
    ///
    /// - Normal açılış: `.standard`. İşaretler uygulama kapanıp açılınca da kalır.
    /// - `-ui-testing`: Ayrı bir "suite" (ayrı bir plist dosyası) ve her açılışta **sıfırlanır**.
    ///   Neden? UI testleri birbirinden bağımsız olmalı: Bir test bir konuyu "çalışıldı" yaparsa, sonraki test
    ///   "0 / 16" yerine "1 / 16" görürdü ve sonuç testlerin çalışma sırasına bağlı olurdu (flaky). Ayrı suite,
    ///   geliştiricinin simülatörde biriktirdiği gerçek işaretlere de dokunmaz.
    static func makeStore(arguments: [String]) -> UserDefaults {
        guard arguments.contains(LaunchArgument.uiTesting) else { return .standard }
        // `UserDefaults(suiteName:)` yalnızca ad uygulamanın bundle kimliği ya da "NSGlobalDomain" ise nil döner.
        // Burada sabit ve farklı bir ad verdiğimiz için nil gelmesi bir programlama hatasıdır.
        guard let defaults = UserDefaults(suiteName: uiTestingSuiteName) else {
            preconditionFailure("UI test suite'i oluşturulamadı: \(uiTestingSuiteName)")
        }
        defaults.removePersistentDomain(forName: uiTestingSuiteName)
        return defaults
    }

    static let uiTestingSuiteName = "BookShelf.uiTesting.interview"
}
