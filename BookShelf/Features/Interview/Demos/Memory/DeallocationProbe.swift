import Foundation

/// Bir nesneyi **sahiplenmeden** izler: "Bu nesne bellekten silindi mi?"
///
/// Sızıntı testinin temel fikri budur: Nesneye zayıf (`weak`) bir referans tut, son güçlü referansı bırak ve
/// zayıf referansın `nil` olmasını bekle. `weak` sayacı artırmadığı için ölçüm, ölçtüğü şeyi etkilemez.
/// Birim testlerdeki `weak var weakViewController` kalıbının (bkz. `FavoritesViewControllerTests`) yeniden kullanılabilir hali.
///
/// Neden "hemen" değil de "kısa süre içinde"? UIKit, kapanan bir ekranı geçiş (transition) bitene ya da
/// autorelease havuzu boşalana kadar (ana run loop'un bir sonraki turu) tutabilir. İptal edilen bir `Task`'ın da
/// closure'ını bırakması için bir kez daha çalışma sırası alması gerekir. Bu yüzden kısa aralıklarla yokluyoruz.
/// Gerçek bir döngüde ise süre ne olursa olsun nesne silinmez.
@MainActor
final class DeallocationProbe<Object: AnyObject> {
    private weak var weakObject: Object?

    init(_ object: Object) {
        weakObject = object
    }

    /// Nesne hâlâ yaşıyorsa ona (geçici olarak güçlü) bir referans; silindiyse `nil`.
    var object: Object? {
        weakObject
    }

    var isReleased: Bool {
        weakObject == nil
    }

    /// Nesne silinene kadar ana actor'ü bloklamadan bekler; `timeout` içinde silinmezse `false` döner.
    ///
    /// `Task.sleep` askıya alır (suspend): ana thread bu sırada serbesttir, UIKit geçişi ve run loop çalışmaya devam eder.
    func waitForRelease(timeout: Duration = .seconds(1)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !isReleased {
            guard clock.now < deadline else { return false }
            do {
                try await Task.sleep(for: .milliseconds(20))
            } catch {
                // Bekleyen görev iptal edildi: beklemeyi bırak, o anki durumu bildir.
                return isReleased
            }
        }
        return true
    }
}

/// Laboratuvarın kapattığı kurbanları **zayıf** referanslarla hatırlar.
///
/// Neden zayıf? Kayıt defteri güçlü tutsaydı her kurbanı kendisi hayatta tutardı ve ölçüm anlamsızlaşırdı.
/// Zayıf referans, sızan (döngüsü yüzünden yaşayan) kurbana yine de ulaşmamızı sağlar: "Sızıntıları temizle"
/// onların döngüsünü kırar (`breakRetainCycles()`), böylece uygulama çalıştıkça çöp birikmez.
///
/// `shared`: Kurbanlar laboratuvar ekranından uzun yaşayabilir (sızıntının tanımı bu). Konudan çıkıp geri
/// gelindiğinde de sızanları görebilmek için kayıt uygulama boyunca tek. Testler kendi örneklerini oluşturur.
@MainActor
final class LeakRegistry {
    static let shared = LeakRegistry()

    private var probes: [DeallocationProbe<LeakVictimViewController>] = []

    /// Kapanan bir kurbanı izlemeye başlar ve onun probe'unu döndürür.
    @discardableResult
    func track(_ victim: LeakVictimViewController) -> DeallocationProbe<LeakVictimViewController> {
        probes.removeAll { $0.isReleased }
        let probe = DeallocationProbe(victim)
        probes.append(probe)
        return probe
    }

    /// Kapatılmış ama hâlâ bellekte olan kurban sayısı.
    var survivorCount: Int {
        probes.count(where: { !$0.isReleased })
    }

    /// Yaşayan her kurbanın döngüsünü kırar. Döndürülen probe'larla serbest kalmaları beklenebilir.
    func breakAllCycles() -> [DeallocationProbe<LeakVictimViewController>] {
        let survivors = probes.filter { !$0.isReleased }
        for probe in survivors {
            probe.object?.breakRetainCycles()
        }
        probes = survivors
        return survivors
    }
}
