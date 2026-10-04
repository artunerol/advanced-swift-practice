import UIKit
import XCTest
@testable import BookShelf

/// Sızıntı laboratuvarının yardımcıları: `DeallocationProbe`, `LeakRegistry`, `LeakMeasurement` ve senaryo metinleri.
final class MemoryLabSupportTests: XCTestCase {

    // MARK: - DeallocationProbe

    @MainActor
    func testProbeReportsReleaseWhenLastStrongReferenceGoesAway() async {
        let probe: DeallocationProbe<MemoryLabPlainObject>
        do {
            let object = MemoryLabPlainObject()
            probe = DeallocationProbe(object)
            XCTAssertFalse(probe.isReleased)
        } // ← tek güçlü referans burada bitti

        let released = await probe.waitForRelease(timeout: .seconds(1))
        XCTAssertTrue(released)
        XCTAssertNil(probe.object)
    }

    @MainActor
    func testProbeDoesNotKeepObjectAliveAndReportsSurvivor() async {
        let object = MemoryLabPlainObject()
        let probe = DeallocationProbe(object)

        let released = await probe.waitForRelease(timeout: .milliseconds(50))

        XCTAssertFalse(released, "Nesneyi test tutuyor; silinmemeli")
        XCTAssertTrue(probe.object === object)
    }

    // MARK: - LeakRegistry

    @MainActor
    func testRegistryCountsOnlySurvivorsAndBreakingCyclesReleasesThem() async {
        let registry = LeakRegistry()
        trackClosedVictim(.closure, .leaking, in: registry)
        trackClosedVictim(.delegate, .leaking, in: registry)
        let fixedProbe = trackClosedVictim(.closure, .fixed, in: registry)

        let fixedReleased = await fixedProbe.waitForRelease(timeout: .seconds(2))
        XCTAssertTrue(fixedReleased)
        XCTAssertEqual(registry.survivorCount, 2, "Yalnızca iki sızdıran kurban yaşıyor olmalı")

        let probes = registry.breakAllCycles()
        XCTAssertEqual(probes.count, 2)
        for probe in probes {
            let released = await probe.waitForRelease(timeout: .seconds(2))
            XCTAssertTrue(released)
        }
        XCTAssertEqual(registry.survivorCount, 0)
    }

    // MARK: - LeakMeasurement

    @MainActor
    func testMeasurementTextsUseSharedVerdicts() {
        let leaked = LeakMeasurement(scenario: .timer, variant: .leaking, released: false)
        XCTAssertEqual(leaked.verdict, AccessibilityID.MemoryLab.verdictLeaked)
        XCTAssertEqual(leaked.verdict, "SIZINTI: hâlâ bellekte ✗")
        XCTAssertTrue(leaked.detail.contains(LeakScenario.timer.retainChain))
        XCTAssertTrue(leaked.matchesExpectation)

        let released = LeakMeasurement(scenario: .timer, variant: .fixed, released: true)
        XCTAssertEqual(released.verdict, "Serbest bırakıldı ✓")
        XCTAssertEqual(released.detail, "Timer'ın target'ı · düzeltilmiş sürüm: deinit çalıştı, nesne bellekten silindi.")
        XCTAssertTrue(released.matchesExpectation)

        XCTAssertFalse(LeakMeasurement(scenario: .task, variant: .fixed, released: false).matchesExpectation)
        XCTAssertEqual(AccessibilityID.MemoryLab.leakCountText(2), "Bellekte kalan kurban: 2")
    }

    // MARK: - Senaryo metinleri

    func testEveryScenarioShowsDifferentCodeForTheTwoVariants() {
        for scenario in LeakScenario.allCases {
            XCTAssertNotEqual(scenario.code(for: .leaking), scenario.code(for: .fixed), "\(scenario)")
            XCTAssertFalse(scenario.lesson.isEmpty, "\(scenario)")
        }
        XCTAssertEqual(Set(LeakScenario.allCases.map(\.segmentTitle)).count, LeakScenario.allCases.count)
    }

    // MARK: - Yardımcılar

    /// Kurbanı açıp kapatır (laboratuvardaki gibi) ve kayıt defterine ekler. Fonksiyon dönünce güçlü referans kalmaz.
    @MainActor
    @discardableResult
    private func trackClosedVictim(
        _ scenario: LeakScenario,
        _ variant: LeakVariant,
        in registry: LeakRegistry
    ) -> DeallocationProbe<LeakVictimViewController> {
        let victim = LeakVictimViewController(scenario: scenario, variant: variant)
        victim.loadViewIfNeeded()
        victim.beginAppearanceTransition(true, animated: false)
        victim.endAppearanceTransition()
        victim.beginAppearanceTransition(false, animated: false)
        victim.endAppearanceTransition()
        return registry.track(victim)
    }
}

/// Saf Swift nesnesi: autorelease havuzuna girmez, son referans bırakılınca hemen silinir.
private final class MemoryLabPlainObject {}
