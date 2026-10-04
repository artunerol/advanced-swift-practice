import Foundation

extension ConcurrencyLab {
    /// Uzun işin nasıl bittiği.
    enum LongJobOutcome: Hashable, Sendable {
        /// Tüm adımlar tamamlandı.
        case completed(steps: Int)
        /// İş iptal edildi; o ana kadar `completedSteps` adım bitmişti.
        case cancelled(completedSteps: Int)
    }

    /// Adım adım ilerleyen, **kooperatif iptali** destekleyen uzun bir iş.
    ///
    /// Swift'te iptal *kooperatiftir* (cooperative): `task.cancel()` işi zorla DURDURMAZ, sadece task'ın üzerine
    /// "iptal edildi" bayrağını koyar. İşin kendisi bu bayrağı kontrol edip kendi isteğiyle, temiz bir şekilde durmalıdır.
    /// Bayrağa hiç bakmayan bir döngü, iptal edilse bile sonuna kadar çalışır.
    ///
    /// Bayrağa bakmanın yolları:
    /// - `Task.isCancelled` → `Bool`. Fırlatmaz; ne yapacağına sen karar verirsin (ör. kısmi sonuç döndürmek).
    /// - `try Task.checkCancellation()` → iptal edildiyse `CancellationError` fırlatır.
    /// - `Task.sleep` gibi iptale duyarlı API'ler: bekleme sırasında iptal gelirse hemen `CancellationError` fırlatır.
    struct LongRunningJob: Sendable {
        let stepCount: Int
        let stepDuration: Duration

        /// İşi çalıştırır. Her adım bittiğinde `onProgress(tamamlananAdım)` çağrılır.
        ///
        /// Fonksiyon `throws` değil; iptali bir hata olarak değil, `LongJobOutcome.cancelled` olarak bildiriyor.
        /// Böylece kaç adımın bittiği bilgisi (kısmi ilerleme) kaybolmuyor.
        ///
        /// `onProgress` `@Sendable` ve `async`: Bu fonksiyon arka planda çalışırken çağıran taraf closure içinde
        /// `await` ile kendi actor'üne (ör. `@MainActor` view model'e) geçip UI durumunu güncelleyebilir.
        func run(onProgress: @Sendable (Int) async -> Void = { _ in }) async -> LongJobOutcome {
            var completedSteps = 0
            while completedSteps < stepCount {
                // 1) Yeni bir adıma başlamadan önce bayrağa bak. İptal istendiyse işe hiç girişme.
                //    (Pahalı bir işe başlamadan önce kontrol etmek, iptalin en ucuz ve en önemli noktasıdır.)
                if Task.isCancelled {
                    return .cancelled(completedSteps: completedSteps)
                }
                do {
                    // 2) Adımın "işi". `Task.sleep` iptale duyarlıdır: bekleme sürerken iptal gelirse
                    //    beklemeyi yarıda keser ve `CancellationError` fırlatır.
                    try await Task.sleep(for: stepDuration)
                } catch {
                    // Burada fırlayabilecek tek hata `CancellationError`.
                    return .cancelled(completedSteps: completedSteps)
                }
                completedSteps += 1
                await onProgress(completedSteps)
            }
            return .completed(steps: completedSteps)
        }
    }
}
