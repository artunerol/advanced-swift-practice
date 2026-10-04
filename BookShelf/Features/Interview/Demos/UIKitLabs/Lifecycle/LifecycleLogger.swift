import Foundation

/// Günlük değiştiğinde haber almak isteyen nesne (lab'da: günlüğü ekrana yazan `LifecycleLabViewController`).
///
/// `AnyObject`: Yalnızca sınıflar uyabilir; böylece `weak var delegate` yazılabilir.
/// `@MainActor`: Çağrılar her zaman ana actor'den gelir; uygulayan VC de zaten ana actor'de.
@MainActor
protocol LifecycleLoggerDelegate: AnyObject {
    func lifecycleLoggerDidChange(_ logger: LifecycleLogger)
}

/// View controller'ların yaşam döngüsü çağrılarını sıra numarası ve zaman damgasıyla biriktiren günlük.
///
/// Sahiplik (kim kimi tutuyor?) — delegate sorusunun cevabı burada:
/// ```
/// LifecycleLabViewController ──strong──▶ LifecycleLogger ──weak delegate──▶ LifecycleLabViewController
/// LoggingViewController(lar) ──strong──▶ LifecycleLogger
/// ```
/// Günlüğü kap (lab ekranı) **sahiplenir**; günlük, kabı yalnızca **zayıf** delegate olarak bilir.
/// İkisi de güçlü olsaydı birbirlerini hayatta tutarlardı (retain cycle).
///
/// `final class` (struct değil): Birden çok VC **aynı** günlüğe yazar; paylaşılan, kimliği olan bir nesne gerekir.
/// `@MainActor`: UIKit çağrıları zaten ana thread'de gelir; günlüğü de oraya bağlamak veri yarışını derleme anında engeller.
@MainActor
final class LifecycleLogger {
    struct Entry: Equatable, Sendable {
        /// 1'den başlar, `clear()` ile sıfırlanır.
        let sequence: Int
        /// Günlüğün başlangıcından (ya da son temizlemeden) bu yana geçen süre.
        let elapsed: Duration
        /// Olayın geldiği ekranın adı, ör. "Ana", "PageSheet".
        let source: String
        let event: LifecycleEvent

        /// Ekrandaki satır, ör. "12. +452 ms  Ana · viewDidLoad".
        var text: String {
            let milliseconds = elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000
            return "\(sequence). +\(milliseconds) ms  \(source) · \(event.title)"
        }
    }

    /// Bellek sınırsız büyümesin diye en fazla bu kadar satır tutulur; en eskiler atılır.
    static let maximumEntryCount = 300

    weak var delegate: (any LifecycleLoggerDelegate)?

    private(set) var entries: [Entry] = []
    private var nextSequence = 1
    private let clock = ContinuousClock()
    private var startedAt: ContinuousClock.Instant

    init() {
        startedAt = clock.now
    }

    func record(_ event: LifecycleEvent, from source: String) {
        entries.append(Entry(sequence: nextSequence, elapsed: clock.now - startedAt, source: source, event: event))
        nextSequence += 1
        if entries.count > Self.maximumEntryCount {
            entries.removeFirst(entries.count - Self.maximumEntryCount)
        }
        delegate?.lifecycleLoggerDidChange(self)
    }

    /// Günlüğü boşaltır; sıra numarası ve saat de sıfırdan başlar.
    func clear() {
        entries.removeAll()
        nextSequence = 1
        startedAt = clock.now
        delegate?.lifecycleLoggerDidChange(self)
    }

    /// Tek bir ekranın olayları, geliş sırasıyla.
    func events(from source: String) -> [LifecycleEvent] {
        entries.filter { $0.source == source }.map(\.event)
    }

    /// Ekranda gösterilen metnin tamamı; en yeni satır en altta.
    var text: String {
        entries.map(\.text).joined(separator: "\n")
    }
}
