import Foundation
import os

// MARK: - Ortak arayüz

extension ConcurrencyLab {
    /// Deneydeki sayaçların ortak arayüzü (protocol).
    ///
    /// - `: Sendable`: Sayaç aynı anda birçok child task'a verilecek; bu yüzden uygulayan her tip `Sendable` olmalı.
    /// - Gereksinimler `async`: Actor'ün metotlarını dışarıdan çağırmak `await` ister. **Senkron** bir metot da
    ///   `async` bir gereksinimi karşılayabilir (tersi olmaz); bu yüzden kilitsiz ve kilitli sayaçlar senkron
    ///   metotlarla, actor ise kendi izole metotlarıyla aynı protokole uyar.
    protocol SharedCounter: Sendable {
        func increment() async
        var value: Int { get async }
    }

    /// Bir sayaç deneyinin sonucu.
    struct CounterReport: Hashable, Sendable {
        let finalValue: Int
        let expectedValue: Int

        /// Kaybolan artış sayısı (lost updates).
        var lostUpdates: Int { expectedValue - finalValue }
        var isExact: Bool { finalValue == expectedValue }
    }
}

// MARK: - 1) Kilitsiz sayaç: BİLEREK HATALI

extension ConcurrencyLab {
    /// ⚠️ BİLEREK HATALI KOD — SADECE ÖĞRETİM İÇİN. GERÇEK KODDA ASLA BÖYLE YAZMA. ⚠️
    ///
    /// Korumasız, paylaşılan, değiştirilebilir durum (shared mutable state):
    /// - `@unchecked Sendable` derleyiciye "bu tipi thread'ler arasında paylaşmak güvenli, bana güven" der ve
    ///   Swift 6'nın data race denetimini bu tip için **susturur**. Ama söz yalandır: `value`'yu hiçbir şey korumuyor.
    /// - `value += 1` tek bir işlem değildir: **oku → artır → yaz**. İki thread aynı anda eski değeri (ör. 41) okursa
    ///   ikisi de 42 yazar; bir artış kaybolur (*lost update*). Sonuç 1000 yerine ör. 912 çıkar ve her seferinde değişir.
    /// - Daha kötüsü: Swift'te (C/C++'ta olduğu gibi) data race **tanımsız davranıştır** (undefined behavior).
    ///   "Biraz eksik sayar" garantisi bile yoktur; derleyici ve işlemci race olmadığını varsayarak optimizasyon yapar.
    /// - Scheme > Run > Diagnostics > **Thread Sanitizer** açıkken bu deneyi çalıştırırsan TSan "Data race" raporu verir.
    /// - `@unchecked Sendable` yalnızca tipin içinde durumu GERÇEKTEN koruyan bir mekanizma (kilit, atomik) varsa
    ///   ve derleyici bunu göremiyorsa kullanılır. Doğru örnekler: aşağıdaki `LockedCounter` ve `ActorCounter`.
    final class UnsafeCounter: SharedCounter, @unchecked Sendable {
        var value = 0

        func increment() {
            value += 1 // ❌ Korumasız okuma-değiştirme-yazma: data race.
        }
    }
}

// MARK: - 2) Kilitli sayaç

extension ConcurrencyLab {
    /// Durumu bir kilit (lock) ile koruyan sayaç. Sonuç her zaman tam doğrudur.
    ///
    /// - `OSAllocatedUnfairLock` (iOS 16+, `import os`): Durumu (`Int`) kilidin **içinde** saklar. Duruma yalnızca
    ///   `withLock { }` içinden erişilebilir; kilidi almayı "unutmak" mümkün değildir.
    /// - Sınıf `final` ve tek alanı `let` + `Sendable` olduğu için derleyici `Sendable` uygunluğunu KENDİSİ
    ///   doğrular; `@unchecked` gerekmez. Durumu kilit sahiplendiği için güvenlik derleyicinin gözü önündedir.
    /// - iOS 18+ hedefleyen projelerde aynı işi `Synchronization` modülündeki `Mutex` yapar
    ///   (`let state = Mutex(0)`); bu proje iOS 17'yi desteklediği için `OSAllocatedUnfairLock` kullanıyoruz.
    /// - Kilitler kısa, senkron kritik bölgeler içindir. Kilidi tutarken ASLA `await` etme.
    final class LockedCounter: SharedCounter {
        private let state = OSAllocatedUnfairLock(initialState: 0)

        func increment() {
            state.withLock { $0 += 1 }
        }

        var value: Int {
            state.withLock { $0 }
        }
    }
}

// MARK: - 3) Actor sayaç

extension ConcurrencyLab {
    /// Durumu bir actor ile koruyan sayaç. Sonuç her zaman tam doğrudur.
    ///
    /// Actor, izole durumuna (`value`) aynı anda yalnızca **bir** görevin erişmesine izin verir. `increment()`
    /// senkron olduğu için içinde askıya alınma noktası (`await`) yoktur; oku-artır-yaz kesintisiz çalışır.
    /// Dışarıdan her çağrı `await counter.increment()` şeklindedir: "sıra bana gelene kadar bekleyebilirim".
    actor ActorCounter: SharedCounter {
        private(set) var value = 0

        func increment() {
            value += 1
        }
    }
}

// MARK: - 4) Actor reentrancy

extension ConcurrencyLab {
    /// Actor **reentrancy** (yeniden girilebilirlik) tuzağını gösteren sayaç.
    ///
    /// Actor bir metot `await` ile askıya alındığında actor'ü kilitli TUTMAZ. Bekleme sırasında aynı actor'e gelen
    /// başka çağrılar çalışabilir (reentrancy). Bu, deadlock'ları önler; ama bedeli şudur:
    /// **`await`'ten önce okuduğun durum, `await`'ten sonra artık geçerli olmayabilir.**
    ///
    /// Actor'ler *data race*'i (aynı belleğe korumasız eşzamanlı erişim) önler; ama *mantıksal race condition*'ı
    /// (askıya alınma noktaları arasında işlemlerin araya girmesi) önlemez.
    actor ReentrantCounter {
        private(set) var value = 0

        /// ❌ HATALI: oku → `await` → yaz.
        ///
        /// 1000 çağrıda sonuç 1000'den çok daha küçük çıkar: birçok çağrı aynı `snapshot`'ı okur, askıya alınır,
        /// sonra hepsi aynı `snapshot + 1` değerini yazar. Burada DATA RACE YOK (her erişim actor üzerinde, sırayla);
        /// hata tamamen mantıksal.
        func incrementAcrossSuspension() async {
            let snapshot = value
            // Askıya alınma noktası. Gerçek hayatta bu bir ağ isteği, disk okuması vb. olurdu.
            // `Task.yield()` görevi geri sıraya koyar; actor bu arada sıradaki diğer çağrıları işler.
            await Task.yield()
            value = snapshot + 1 // Eski anlık görüntüyle yazıyoruz: araya girenlerin artışları siliniyor.
        }

        /// ✅ DOĞRU: Okuma ile yazma arasında `await` yok → kesintisiz (atomik) çalışır.
        ///
        /// Genel kural: Actor durumunu **senkron** kod içinde değiştir. Bir `await` gerekiyorsa, `await`'ten sonra
        /// durumu yeniden oku / varsayımlarını yeniden kontrol et.
        func increment() {
            value += 1
        }
    }

    /// Reentrancy deneyinin iki sonucu.
    struct ReentrancyReport: Hashable, Sendable {
        /// Okuma ile yazma arasında `await` olan hatalı sürüm.
        let acrossSuspension: CounterReport
        /// Arada `await` olmayan doğru sürüm.
        let atomic: CounterReport
    }
}

// MARK: - Deneyler

extension ConcurrencyLab {
    /// Sayacı `childTaskCount` adet eşzamanlı child task'tan, her biri `incrementsPerChild` kez olmak üzere artırır.
    static func runCounterExperiment(
        _ counter: some SharedCounter,
        childTaskCount: Int,
        incrementsPerChild: Int
    ) async -> CounterReport {
        await hammer(childTaskCount: childTaskCount, repetitionsPerChild: incrementsPerChild) {
            await counter.increment()
        }
        return CounterReport(
            finalValue: await counter.value,
            expectedValue: childTaskCount * incrementsPerChild
        )
    }

    /// Aynı yükü hatalı (`incrementAcrossSuspension`) ve doğru (`increment`) actor metotlarına uygular.
    static func runReentrancyExperiment(childTaskCount: Int, incrementsPerChild: Int) async -> ReentrancyReport {
        let expected = childTaskCount * incrementsPerChild

        let buggy = ReentrantCounter()
        await hammer(childTaskCount: childTaskCount, repetitionsPerChild: incrementsPerChild) {
            await buggy.incrementAcrossSuspension()
        }

        let fixed = ReentrantCounter()
        await hammer(childTaskCount: childTaskCount, repetitionsPerChild: incrementsPerChild) {
            await fixed.increment()
        }

        return ReentrancyReport(
            acrossSuspension: CounterReport(finalValue: await buggy.value, expectedValue: expected),
            atomic: CounterReport(finalValue: await fixed.value, expectedValue: expected)
        )
    }

    /// `childTaskCount` adet child task başlatır; her biri `operation`'ı `repetitionsPerChild` kez çağırır.
    ///
    /// `withDiscardingTaskGroup` (iOS 17+): Child'lar sonuç döndürmüyorsa en uygun grup. Biten child'ın
    /// kaynaklarını hemen bırakır; `for await` ile sonuç toplamaya gerek yoktur. Fonksiyon, tüm child'lar
    /// bitmeden geri DÖNMEZ (yapısal concurrency). `withTaskGroup(of: Void.self)` ile de aynısı yazılabilirdi.
    ///
    /// `operation` `@Sendable`: Aynı anda birçok child task'tan çağrılacağı için yakaladığı her şey `Sendable` olmalı.
    private static func hammer(
        childTaskCount: Int,
        repetitionsPerChild: Int,
        operation: @escaping @Sendable () async -> Void
    ) async {
        await withDiscardingTaskGroup { group in
            for _ in 0..<childTaskCount {
                group.addTask {
                    for _ in 0..<repetitionsPerChild {
                        await operation()
                    }
                }
            }
        }
    }
}
