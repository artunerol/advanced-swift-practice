import UIKit
import XCTest
@testable import BookShelf

/// `StarRatingControl`: delegate'e soru sorma, üç kanaldan haber verme ve `weak` delegate'in sahibi tutmaması.
final class DelegationStarRatingTests: XCTestCase {

    // MARK: - Delegate, closure ve target-action

    @MainActor
    func testSelectingRatingAsksDelegateThenNotifiesAllThreeChannels() {
        let control = StarRatingControl()
        let delegate = DelegationSpyDelegate()
        let target = DelegationActionTarget()
        var closureRatings: [Int] = []
        control.delegate = delegate
        control.onRatingChange = { closureRatings.append($0) }
        control.addTarget(target, action: #selector(DelegationActionTarget.ratingChanged(_:)), for: .valueChanged)

        control.selectRating(4)

        XCTAssertEqual(control.rating, 4)
        XCTAssertEqual(delegate.askedRatings, [4], "Önce soru sorulmalı")
        XCTAssertEqual(delegate.changedRatings, [4])
        XCTAssertEqual(closureRatings, [4])
        XCTAssertEqual(target.receivedRatings, [4])
    }

    @MainActor
    func testDelegateCanRejectChangeAndNothingIsNotified() {
        let control = StarRatingControl(rating: 2)
        let delegate = DelegationSpyDelegate()
        delegate.allowsChanges = false
        var closureCalled = false
        control.delegate = delegate
        control.onRatingChange = { _ in closureCalled = true }

        control.selectRating(5)

        XCTAssertEqual(control.rating, 2, "Delegate 'hayır' dedi; puan değişmemeli")
        XCTAssertEqual(delegate.askedRatings, [5])
        XCTAssertTrue(delegate.changedRatings.isEmpty)
        XCTAssertFalse(closureCalled)
    }

    /// Protokol extension'ındaki varsayılan `shouldChangeRatingTo` her değişikliğe izin verir.
    @MainActor
    func testDefaultShouldChangeImplementationAllowsChanges() {
        let control = StarRatingControl()
        let delegate = DelegationMinimalDelegate()
        control.delegate = delegate

        control.selectRating(3)

        XCTAssertEqual(control.rating, 3)
        XCTAssertEqual(delegate.changedRatings, [3])
    }

    @MainActor
    func testSelectingCurrentRatingDoesNotNotifyAgain() {
        let control = StarRatingControl(rating: 3)
        let delegate = DelegationSpyDelegate()
        control.delegate = delegate

        control.selectRating(3)

        XCTAssertTrue(delegate.askedRatings.isEmpty)
        XCTAssertTrue(delegate.changedRatings.isEmpty)
    }

    @MainActor
    func testRatingIsClampedToValidRange() {
        XCTAssertEqual(StarRatingControl(rating: -2).rating, 0)
        let control = StarRatingControl()
        control.selectRating(9)
        XCTAssertEqual(control.rating, StarRatingControl.maximumRating)
    }

    /// Yıldız düğmesine dokunmak (UIAction) `selectRating`'i doğru sayıyla çağırır.
    @MainActor
    func testTappingStarButtonSelectsThatRating() {
        let control = StarRatingControl()
        XCTAssertEqual(control.starButtons.count, 5)

        control.starButtons[3].sendActions(for: .primaryActionTriggered)

        XCTAssertEqual(control.rating, 4)
        XCTAssertEqual(control.starButtons[3].accessibilityIdentifier, AccessibilityID.Delegation.starButton(4))
        XCTAssertEqual(control.starButtons[3].accessibilityLabel, "4 yıldız")
    }

    // MARK: - Sahiplik

    /// Mülakatın asıl sorusu: Kontrol sahibinden uzun yaşarsa ne olur? `weak` delegate sahibi tutmaz ve
    /// sahip ölünce kendiliğinden `nil` olur. Saf Swift nesneleriyle sonuç anında ve deterministiktir.
    @MainActor
    func testWeakDelegateDoesNotKeepOwnerAliveAndBecomesNil() {
        let control = StarRatingControl()
        weak var weakOwner: DelegationSpyDelegate?

        do {
            let owner = DelegationSpyDelegate()
            control.delegate = owner
            weakOwner = owner
            XCTAssertNotNil(control.delegate)
        } // ← sahibin tek güçlü referansı bitti

        XCTAssertNil(weakOwner, "Kontrol sahibini tutmamalı")
        XCTAssertNil(control.delegate, "weak referans nesne ölünce nil olur (zeroing)")

        control.selectRating(2) // Delegate yok: optional chaining atlar, çökme yok.
        XCTAssertEqual(control.rating, 2)
    }

    /// Karşılaştırma: Delegate'i **güçlü** tutan bir nesne (sızıntı laboratuvarındaki `LeakLabReporter`'ın
    /// sızdıran ayarı) sahibiyle döngü kurar ve ikisi de yaşamaya devam eder.
    @MainActor
    func testStrongDelegateCreatesCycleUntilDetached() {
        weak var weakOwner: DelegationReporterOwner?
        weak var weakReporter: LeakLabReporter?

        do {
            let owner = DelegationReporterOwner()
            let reporter = LeakLabReporter(delegate: owner, holdsDelegateStrongly: true)
            owner.reporter = reporter          // sahip → reporter (strong)
            weakOwner = owner                  // reporter → sahip (strong) → DÖNGÜ
            weakReporter = reporter
        }

        XCTAssertNotNil(weakOwner, "Döngü: sahip bellekte kalmalı")
        XCTAssertNotNil(weakReporter)

        weakReporter?.detachDelegate()         // geri oku kopar → zincir ağaca döner

        XCTAssertNil(weakOwner)
        XCTAssertNil(weakReporter)
    }

    /// Aynı yapı `weak` delegate ile: döngü yok, kapsam bitince ikisi de silinir.
    @MainActor
    func testWeakReporterDelegateDoesNotCreateCycle() {
        weak var weakOwner: DelegationReporterOwner?
        weak var weakReporter: LeakLabReporter?

        do {
            let owner = DelegationReporterOwner()
            let reporter = LeakLabReporter(delegate: owner, holdsDelegateStrongly: false)
            owner.reporter = reporter
            weakOwner = owner
            weakReporter = reporter
            reporter.report()
            XCTAssertEqual(owner.updateCount, 1)
        }

        XCTAssertNil(weakOwner)
        XCTAssertNil(weakReporter)
    }

    /// UIKit'in sözü: "the target is not retained". Target-action sahibi hayatta tutmaz.
    @MainActor
    func testControlDoesNotRetainItsTarget() async {
        let control = StarRatingControl()
        let probe: DeallocationProbe<DelegationActionTarget>
        do {
            let target = DelegationActionTarget()
            control.addTarget(target, action: #selector(DelegationActionTarget.ratingChanged(_:)), for: .valueChanged)
            probe = DeallocationProbe(target)
        }

        let released = await probe.waitForRelease(timeout: .seconds(1))
        XCTAssertTrue(released)
    }
}

// MARK: - Test dublörleri (private: modüldeki diğer testlerle isim çakışmasın)

/// Her soruyu ve haberi kaydeden sahte delegate (spy).
@MainActor
private final class DelegationSpyDelegate: StarRatingControlDelegate {
    var allowsChanges = true
    private(set) var askedRatings: [Int] = []
    private(set) var changedRatings: [Int] = []

    func starRatingControl(_ control: StarRatingControl, shouldChangeRatingTo rating: Int) -> Bool {
        askedRatings.append(rating)
        return allowsChanges
    }

    func starRatingControl(_ control: StarRatingControl, didChangeRating rating: Int) {
        changedRatings.append(rating)
    }
}

/// Yalnızca zorunlu metodu uygular; `shouldChangeRatingTo` protokol extension'ından gelir.
@MainActor
private final class DelegationMinimalDelegate: StarRatingControlDelegate {
    private(set) var changedRatings: [Int] = []

    func starRatingControl(_ control: StarRatingControl, didChangeRating rating: Int) {
        changedRatings.append(rating)
    }
}

/// Target-action için `@objc` metodu olan bir hedef. Selector çağrısı Objective-C çalışma zamanından geçtiği için `NSObject`.
@MainActor
private final class DelegationActionTarget: NSObject {
    private(set) var receivedRatings: [Int] = []

    @objc func ratingChanged(_ sender: StarRatingControl) {
        receivedRatings.append(sender.rating)
    }
}

/// `LeakLabReporter`'ın sahibi rolünde, en küçük delegate.
@MainActor
private final class DelegationReporterOwner: LeakLabReporterDelegate {
    var reporter: LeakLabReporter?
    private(set) var updateCount = 0

    func reporterDidProduceUpdate(_ reporter: LeakLabReporter) {
        updateCount += 1
    }
}
