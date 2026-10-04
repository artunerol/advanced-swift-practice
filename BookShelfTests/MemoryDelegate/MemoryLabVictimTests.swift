import UIKit
import XCTest
@testable import BookShelf

/// Sızıntı laboratuvarının beş senaryosunu, ekran olmadan (pencere yok, sunum yok) doğrular.
///
/// Yöntem, laboratuvarın kendisiyle aynı:
/// 1. Kurbanı oluştur, yaşam döngüsünü elle sür: `loadViewIfNeeded()` → `viewDidLoad`;
///    `beginAppearanceTransition`/`endAppearanceTransition` → görünme ve kaybolma callback'leri.
/// 2. Son güçlü referansı bırak (yardımcı fonksiyon döndüğünde yerel değişken biter).
/// 3. `DeallocationProbe` ile zayıf referansın `nil` olup olmadığına bak.
///
/// Sızan kurbanlar testin sonunda `breakRetainCycles()` ile temizlenir ve serbest kaldıkları da doğrulanır;
/// böylece hem "temizlik gerçekten döngüyü kırıyor" test edilir hem de test süreci çöp biriktirmez.
///
/// Neden "hemen nil" değil de kısa bekleme? UIKit view controller'ları autorelease havuzunda bir run loop turu
/// kalabilir; iptal edilen bir Task'ın da closure'ını bırakması için bir kez daha çalışması gerekir.
/// Sızdıran sürümlerde ise bekleme ne kadar uzun olursa olsun nesne silinmez (yapısal bir döngü var).
final class MemoryLabVictimTests: XCTestCase {

    // MARK: - (a) Saklanan closure

    @MainActor
    func testClosureCapturingSelfStronglyLeaks() async {
        await assertLeaksUntilCyclesAreBroken(.closure)
    }

    @MainActor
    func testClosureCapturingWeakSelfIsReleased() async {
        await assertReleased(.closure)
    }

    // MARK: - (b) Timer

    @MainActor
    func testTimerThatIsNeverInvalidatedLeaks() async {
        await assertLeaksUntilCyclesAreBroken(.timer)
    }

    @MainActor
    func testTimerInvalidatedInViewDidDisappearIsReleased() async {
        await assertReleased(.timer)
    }

    // MARK: - (c) Delegate

    @MainActor
    func testStrongDelegateLeaks() async {
        await assertLeaksUntilCyclesAreBroken(.delegate)
    }

    @MainActor
    func testWeakDelegateIsReleased() async {
        await assertReleased(.delegate)
    }

    // MARK: - (d) NotificationCenter

    @MainActor
    func testBlockObserverCapturingSelfStronglyLeaks() async {
        await assertLeaksUntilCyclesAreBroken(.notification)
    }

    @MainActor
    func testBlockObserverWithWeakSelfAndRemovalIsReleased() async {
        await assertReleased(.notification)
    }

    // MARK: - (e) Hiç bitmeyen Task

    @MainActor
    func testNeverEndingTaskCapturingSelfLeaks() async {
        await assertLeaksUntilCyclesAreBroken(.task)
    }

    @MainActor
    func testTaskWithWeakSelfCancelledOnDisappearIsReleased() async {
        await assertReleased(.task)
    }

    // MARK: - Düzeltme işlevi bozmamalı

    /// Düzeltilmiş sürümler sadece "sızmayan" değil, aynı zamanda **çalışan** sürümler olmalı.
    @MainActor
    func testFixedVariantsStillDeliverCallbacks() {
        for scenario in [LeakScenario.closure, .delegate, .notification] {
            let victim = makeVisibleVictim(scenario, .fixed)

            victim.trigger()

            XCTAssertEqual(victim.callbackCount, 1, "\(scenario)")
            XCTAssertEqual(victim.callbackCountLabel.text, "Callback sayısı: 1", "\(scenario)")
            simulateDisappearance(of: victim)
        }
    }

    /// Düzeltilmiş gözlemci ekran kaybolunca kaldırılır: sonraki bildirimler artık ona ulaşmaz.
    @MainActor
    func testFixedNotificationObserverIsRemovedWhenScreenDisappears() {
        let victim = makeVisibleVictim(.notification, .fixed)
        victim.trigger()
        XCTAssertEqual(victim.callbackCount, 1)

        simulateDisappearance(of: victim)
        NotificationCenter.default.post(name: .leakLabPing, object: nil)

        XCTAssertEqual(victim.callbackCount, 1, "Kaldırılmış gözlemci bildirim almamalı")
    }

    /// Task ana actor'ü miras alır ve ilk turda hemen callback üretir; ekran kaybolunca iptal edilir.
    @MainActor
    func testFixedTaskTicksWhileVisibleAndIsCancelledOnDisappear() async throws {
        let victim = makeVisibleVictim(.task, .fixed)
        let task = try XCTUnwrap(victim.tickTask)

        await waitUntil("Task ilk callback'i üretmeli") { victim.callbackCount >= 1 }
        simulateDisappearance(of: victim)

        XCTAssertTrue(task.isCancelled)
        XCTAssertNil(victim.tickTask)
    }

    /// Timer ve Task kendiliğinden tetiklendiği için kurban ekranında "tetikle" düğmesi yalnızca diğerlerinde görünür.
    @MainActor
    func testTriggerButtonIsHiddenForSelfFiringScenarios() {
        for scenario in LeakScenario.allCases {
            let victim = LeakVictimViewController(scenario: scenario, variant: .fixed)
            victim.loadViewIfNeeded()
            XCTAssertEqual(victim.triggerButton.isHidden, scenario.firesAutomatically, "\(scenario)")
            XCTAssertEqual(victim.view.accessibilityIdentifier, AccessibilityID.MemoryLab.Victim.root)
        }
    }

    // MARK: - Yardımcılar (private: diğer test dosyalarıyla isim çakışmasın)

    /// Sızdıran sürüm bellekte kalmalı; döngü kırılınca serbest kalmalı.
    @MainActor
    private func assertLeaksUntilCyclesAreBroken(
        _ scenario: LeakScenario,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let probe = runAndReleaseVictim(scenario, .leaking)

        let releasedOnItsOwn = await probe.waitForRelease(timeout: .milliseconds(300))
        XCTAssertFalse(releasedOnItsOwn, "\(scenario) / sızdıran: deinit çalışmamalıydı", file: file, line: line)

        probe.object?.breakRetainCycles()
        let releasedAfterBreaking = await probe.waitForRelease(timeout: .seconds(2))
        XCTAssertTrue(releasedAfterBreaking, "\(scenario): döngü kırılınca kurban serbest kalmalı", file: file, line: line)
    }

    /// Düzeltilmiş sürüm, ekran kaybolup son referans bırakılınca serbest kalmalı.
    @MainActor
    private func assertReleased(
        _ scenario: LeakScenario,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let probe = runAndReleaseVictim(scenario, .fixed)

        let released = await probe.waitForRelease(timeout: .seconds(2))
        XCTAssertTrue(released, "\(scenario) / düzeltilmiş: deinit çalışmalıydı", file: file, line: line)

        // Test kırılsa bile süreçte çöp bırakmayalım.
        probe.object?.breakRetainCycles()
    }

    /// Kurbanı açar, gösterir, gizler ve probe'unu döndürür. Fonksiyon dönünce kurbana güçlü referans kalmaz.
    @MainActor
    private func runAndReleaseVictim(
        _ scenario: LeakScenario,
        _ variant: LeakVariant
    ) -> DeallocationProbe<LeakVictimViewController> {
        let victim = makeVisibleVictim(scenario, variant)
        simulateDisappearance(of: victim)
        return DeallocationProbe(victim)
    }

    @MainActor
    private func makeVisibleVictim(_ scenario: LeakScenario, _ variant: LeakVariant) -> LeakVictimViewController {
        let victim = LeakVictimViewController(scenario: scenario, variant: variant)
        victim.loadViewIfNeeded()
        victim.beginAppearanceTransition(true, animated: false)
        victim.endAppearanceTransition()
        return victim
    }

    @MainActor
    private func simulateDisappearance(of viewController: UIViewController) {
        viewController.beginAppearanceTransition(false, animated: false)
        viewController.endAppearanceTransition()
    }

    /// Koşul sağlanana kadar ana actor'ü kısa aralıklarla serbest bırakarak bekler.
    @MainActor
    private func waitUntil(
        _ description: String,
        timeout: Duration = .seconds(3),
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Zaman aşımı: \(description)", file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
