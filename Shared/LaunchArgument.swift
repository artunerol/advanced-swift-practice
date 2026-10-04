import Foundation

/// Uygulamaya başlatılırken verilebilen komut satırı argümanları.
///
/// Bu dosya `Shared/` klasöründe: hem **uygulama** hem de **UI test** hedefi tarafından derlenir.
/// UI testleri uygulamadan AYRI bir süreçte (process) çalışır ve uygulama modülünü `import` edemez;
/// bu yüzden ortak sabitleri iki hedefe birden dahil ediyoruz. Böylece yazım hatası riski kalmaz.
enum LaunchArgument {
    /// Gecikmeleri sıfırlar ve animasyonları kapatır.
    static let uiTesting = "-ui-testing"
    /// Servisin her istekte ağ hatası fırlatmasını sağlar.
    static let simulateNetworkError = "-simulate-network-error"
}
