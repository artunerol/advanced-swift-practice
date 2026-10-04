import Foundation

/// Laboratuvar sekmesindeki deneylerin **saf mantığı**: UI yok, SwiftUI yok, hiçbir actor'e bağlı değil.
///
/// Neden ayrı bir katman?
/// - View model'den bağımsız olduğu için birim testlerinde doğrudan `try await ConcurrencyLab.runSequentially(...)`
///   diyebiliriz. Test etmek için ekran açmak gerekmez.
/// - Buradaki tipler ve fonksiyonlar hiçbir global actor'e bağlı değil (*nonisolated*). Bu projede
///   (Swift 6 dil modu, "Approachable Concurrency" kapalı) nonisolated bir `async` fonksiyon, çağıranın actor'ünde
///   DEĞİL, Swift'in **global concurrent executor**'ünde (arka plandaki kooperatif thread havuzunda) çalışır.
///   `@MainActor` view model bunları `await` ile çağırdığında ana thread serbest kalır, UI donmaz.
///
/// `case`'i olmayan bir `enum` = **isim alanı** (namespace). Örneği oluşturulamaz; sadece iç içe tipleri ve
/// statik fonksiyonları gruplar. Böylece `ConcurrencyLab.ActorCounter` gibi adlar modüldeki diğer tiplerle çakışmaz.
///
/// Dosyalar:
/// - `ParallelismLab.swift`: sıralı `await` vs `async let` vs `TaskGroup`
/// - `LabCounters.swift`: paylaşılan durum — data race, kilit, actor ve actor reentrancy
/// - `LongRunningJob.swift`: kooperatif iptal (cooperative cancellation)
enum ConcurrencyLab {}

// MARK: - Ayarlar

extension ConcurrencyLab {
    /// Deneylerin süre ve adet ayarları.
    ///
    /// Süreleri koda gömmek yerine dışarıdan veriyoruz (*dependency injection*): uygulama gerçekçi süreler kullanır,
    /// birim testleri milisaniyelik süreler verir, UI testleri de `-ui-testing` ile kısaltılmış süreleri alır.
    /// Tüm alanlar `Sendable` olduğu için struct da `Sendable`'dır; actor sınırlarını güvenle geçebilir.
    struct Settings: Hashable, Sendable {
        /// Paralellik deneyindeki üç iş. Süreler bilerek farklı: `TaskGroup`'un sonuçları işlerin
        /// *bitiş* sırasıyla teslim ettiğini gözle görebilmek için.
        var jobs: JobTrio
        /// Paylaşılan durum deneyinde aynı anda çalışan child task sayısı.
        var counterChildTaskCount: Int
        /// Her child task'ın sayacı kaç kez artıracağı.
        var incrementsPerChild: Int
        /// Uzun işin adım sayısı.
        var longTaskStepCount: Int
        /// Uzun işin her adımının süresi.
        var longTaskStepDuration: Duration

        /// Sayaç deneylerinde beklenen doğru sonuç.
        var expectedCounterTotal: Int { counterChildTaskCount * incrementsPerChild }

        /// Uygulamanın normal ayarları: 10 child task × 100 artış = 1000.
        static let standard = Settings(
            jobs: JobTrio(.milliseconds(500), .milliseconds(300), .milliseconds(400)),
            counterChildTaskCount: 10,
            incrementsPerChild: 100,
            longTaskStepCount: 20,
            longTaskStepDuration: .milliseconds(200)
        )

        /// UI testleri için kısaltılmış (ama sıfır olmayan) süreler.
        ///
        /// Süreler sıfır DEĞİL: sıfır olsaydı paralellik farkı görünmez, uzun iş de UI testi "İptal" düğmesine
        /// basamadan biterdi.
        ///
        /// Uzun işin her adımı kısa (0,15 sn) ama adım sayısı standardın iki katı: toplam yaklaşık 6 saniye (40 × 0,15 sn).
        /// UI testinde "Başlat"a dokunmakla "İptal"e dokunmak arasında yaklaşık 0,8 sn geçiyor; yavaş bir CI makinesinde
        /// bu birkaç saniyeye çıkabilir. İş iptalden önce biterse test kırılır (flaky). Test işi hep erkenden iptal
        /// ettiği için uzun toplam süre testi yavaşlatmaz, sadece güvenlik payını büyütür.
        static let uiTesting = Settings(
            jobs: JobTrio(.milliseconds(100), .milliseconds(60), .milliseconds(80)),
            counterChildTaskCount: 10,
            incrementsPerChild: 100,
            longTaskStepCount: 40,
            longTaskStepDuration: .milliseconds(150)
        )

        /// Başlatma argümanlarına göre ayar seçer (`AppDependencies.makeForLaunch(arguments:)` ile aynı fikir).
        static func forLaunch(arguments: [String]) -> Settings {
            arguments.contains(LaunchArgument.uiTesting) ? .uiTesting : .standard
        }
    }
}

// MARK: - Biçimlendirme

extension ConcurrencyLab {
    /// Süreyi Türkçe biçimde saniye cinsinden yazar: `1,51 sn`.
    ///
    /// Yerel ayarı (locale) bilerek sabitliyoruz: simülatör İngilizce olsa bile ondalık ayırıcı virgül olur,
    /// böylece hem metin tutarlı kalır hem de testler cihaz diline bağlı olmaz.
    static func formattedSeconds(_ duration: Duration) -> String {
        let components = duration.components
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
        let number = seconds.formatted(
            .number.precision(.fractionLength(2)).locale(Locale(identifier: "tr_TR"))
        )
        return "\(number) sn"
    }
}
