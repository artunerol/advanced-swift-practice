import UIKit

/// Deney: "Sahip ölür, kontrol yaşamaya devam eder. Ne olur?"
///
/// Gerçek tiplerle çalışır: Bir `BookRatingViewController` (sahip) oluşturulur, view'u yüklenir (`viewDidLoad`
/// kontrolün üç kanalını bağlar), sonra kontrolü **sahibinden uzun yaşatmak** için elimizde tutup sahibi bırakırız.
///
/// Beklenen (ve testlerde doğrulanan) sonuç:
/// 1. Sahip serbest bırakılır: üç kanalın hiçbiri (weak delegate, `[weak self]` closure, target-action) onu tutmuyor.
/// 2. `control.delegate` kendiliğinden `nil` olur: `weak` referanslar sıfırlanır (*zeroing*).
/// 3. Kontrol çalışmaya devam eder ve çökmez: `delegate?.` optional chaining, olmayan delegate'i atlar.
///    `unowned` olsaydı 3. adımda uygulama çökerdi.
@MainActor
enum DelegateLifetimeExperiment {
    struct Outcome: Equatable, Sendable {
        let ownerReleased: Bool
        let delegateIsNil: Bool
        /// Sahip yokken puan değiştirmek çökmeden çalıştı mı?
        let controlStillWorks: Bool

        var summary: String {
            "Sahip serbest bırakıldı: \(ownerReleased ? "Evet" : "Hayır") · control.delegate: \(delegateIsNil ? "nil" : "hâlâ dolu")"
        }
    }

    static func run() async -> Outcome {
        let control: StarRatingControl
        let ownerProbe: DeallocationProbe<BookRatingViewController>
        do {
            let owner = BookRatingViewController()
            owner.loadViewIfNeeded()
            control = owner.ratingControl
            ownerProbe = DeallocationProbe(owner)
        } // ← Sahibin tek güçlü referansı (`owner`) burada bitti. Kontrolü ise biz tutuyoruz.

        let ownerReleased = await ownerProbe.waitForRelease()
        let delegateIsNil = control.delegate == nil

        let ratingBefore = control.rating
        control.selectRating(ratingBefore == 3 ? 4 : 3)
        let controlStillWorks = control.rating != ratingBefore

        return Outcome(ownerReleased: ownerReleased, delegateIsNil: delegateIsNil, controlStillWorks: controlStillWorks)
    }
}
