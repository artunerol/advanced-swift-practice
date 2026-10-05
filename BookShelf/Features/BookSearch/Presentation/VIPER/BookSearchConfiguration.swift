import Foundation

/// Kitap arama modülünün zamanlama ayarları.
///
/// Neden interactor `ProcessInfo`'ya kendisi bakmıyor? Bakarsa testte süreyi değiştiremeyiz ve interactor "UI testinde
/// miyim?" gibi uygulama düzeyinde bir şeyi bilmek zorunda kalır. Ayar dışarıdan verilir (dependency injection):
/// uygulama `forLaunch(arguments:)` ile seçer, birim testleri istediği süreyi (`BookSearchConfiguration(debounce: ...)`) verir.
/// Aynı fikir: `ConcurrencyLab.Settings.forLaunch(arguments:)`, `AppDependencies.makeForLaunch(arguments:)`.
struct BookSearchConfiguration: Equatable, Sendable {
    /// Yazarken son harften sonra aramadan önce beklenecek süre (debounce). Bu sürede yeni harf gelirse önceki arama hiç
    /// yapılmaz: "at", "ata", "atay" için 3 değil 1 servis çağrısı ("a" zaten 2 harf kuralına takılır, servise hiç gitmez).
    var debounce: Duration

    /// Uygulamanın normal ayarı: 300 ms. Kısa olursa her harfte istek gider; uzun olursa arama "ağır" hissettirir.
    static let standard = BookSearchConfiguration(debounce: .milliseconds(300))

    /// UI testleri: bekleme yok. Testler zaten koşulu bekler (`waitForExistence`); sabit gecikme sadece yavaşlatır.
    static let uiTesting = BookSearchConfiguration(debounce: .zero)

    static func forLaunch(arguments: [String]) -> BookSearchConfiguration {
        arguments.contains(LaunchArgument.uiTesting) ? .uiTesting : .standard
    }
}
