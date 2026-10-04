import XCTest

/// Mülakat sekmesindeki iki demo: sızıntı laboratuvarı ("ARC ve retain cycle") ve delegate demosu.
final class MemoryDelegateUITests: BookShelfUITestCase {
    private typealias MemoryID = AccessibilityID.MemoryLab
    private typealias DelegationID = AccessibilityID.Delegation

    /// Uygulamayı açar, konuyu bulur, "Demo" bölümüne geçer ve demo ekranını bekler.
    @MainActor
    private func openDemo<S: Screen>(
        _ topicID: String,
        as screenType: S.Type,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> S {
        let app = launchApp(file: file, line: line)
        TabBarScreen(app: app).openInterview().waitUntilDisplayed(file: file, line: line)
            .openTopic(topicID, file: file, line: line)
            .showDemo()
        return screenType.init(app: app).waitUntilDisplayed(file: file, line: line)
    }

    // MARK: - Sızıntı laboratuvarı

    @MainActor
    func testLeakingClosureStaysInMemoryAndFixedTwinIsReleased() {
        let lab = openDemo(AccessibilityID.Interview.TopicID.arcRetainCycle, as: MemoryLabScreen.self)
        assertLabel(lab.verdictLabel, equals: MemoryID.verdictIdle)
        assertLabel(lab.leakCountLabel, equals: MemoryID.leakCountText(0))

        XCTContext.runActivity(named: "Sızdıran: onUpdate = { self.refresh() } → kapatınca bellekte kalır") { _ in
            let victim = lab.openLeaking()
            victim.trigger()
            assertLabel(victim.callbackCountLabel, equals: "Callback sayısı: 1")
            victim.close()

            assertLabel(lab.verdictLabel, equals: MemoryID.verdictLeaked)
            assertLabel(lab.leakCountLabel, equals: MemoryID.leakCountText(1))
        }

        XCTContext.runActivity(named: "Düzeltilmiş: [weak self] → kapatınca deinit çalışır") { _ in
            lab.openFixed().close()

            assertLabel(lab.verdictLabel, equals: MemoryID.verdictReleased)
            // Önceki sızıntı hâlâ bellekte: düzeltilmiş sürüm onu kurtarmaz.
            assertLabel(lab.leakCountLabel, equals: MemoryID.leakCountText(1))
        }

        XCTContext.runActivity(named: "Temizlik: döngü kırılınca sızan kurban da serbest kalır") { _ in
            lab.cleanUpLeaks()
            assertLabel(lab.leakCountLabel, equals: MemoryID.leakCountText(0))
        }
    }

    @MainActor
    func testNeverEndingTaskLeaksUntilCleanedUp() {
        let lab = openDemo(AccessibilityID.Interview.TopicID.arcRetainCycle, as: MemoryLabScreen.self)
        lab.selectScenario(MemoryID.taskSegment)

        let victim = lab.openLeaking()
        // Task ana actor'de hemen ilk turunu atar; düğmeye gerek yok.
        assertLabel(victim.callbackCountLabel, matches: "Callback sayısı: [1-9][0-9]*")
        victim.close()

        assertLabel(lab.verdictLabel, equals: MemoryID.verdictLeaked)
        // UI testleri uygulama modülünü göremez (`LeakScenario.retainChain`); zinciri metin olarak bekliyoruz.
        assertLabel(lab.verdictDetailLabel, contains: "Çalışan Task → closure → VC")

        lab.cleanUpLeaks()
        assertLabel(lab.leakCountLabel, equals: MemoryID.leakCountText(0))
    }

    // MARK: - Delegate

    @MainActor
    func testRatingReachesAllThreeChannelsAndLockedDelegateRejectsChange() {
        let demo = openDemo(AccessibilityID.Interview.TopicID.delegate, as: DelegationDemoScreen.self)

        XCTContext.runActivity(named: "4 yıldız: delegate, closure ve target-action aynı olayı alır") { _ in
            demo.rate(4)
            assertLabel(demo.delegateLabel, equals: "Delegate: 4/5")
            assertLabel(demo.closureLabel, equals: "Closure: 4/5")
            assertLabel(demo.targetActionLabel, equals: "Target-action: 4/5")
        }

        XCTContext.runActivity(named: "Kilit açıkken delegate 'shouldChange' sorusuna hayır der") { _ in
            demo.toggleLock()
            assertValue(demo.lockSwitch, equals: "1")
            demo.rate(2)
            assertLabel(demo.statusLabel, equals: "Delegate reddetti: puan 4/5 olarak kaldı.")
            assertLabel(demo.delegateLabel, equals: "Delegate: 4/5")
        }
    }

    @MainActor
    func testOwnershipExperimentShowsWeakDelegateBecomesNil() {
        let demo = openDemo(AccessibilityID.Interview.TopicID.delegate, as: DelegationDemoScreen.self)
        demo.showPane(DelegationID.ownershipSegment)

        demo.runLifetimeExperiment()

        assertLabel(demo.lifetimeResultLabel, equals: "Sahip serbest bırakıldı: Evet · control.delegate: nil")
    }
}
