import XCTest

/// Laboratuvar sekmesi: gerçekten eşzamanlı çalışan deneylerin sonuçlarını arayüzden doğrular.
///
/// Buradaki deneyler gerçek süre harcar (TaskGroup, uzun iş) ya da bilerek yarış (data race) içerir. UI testi
/// yazarken asıl zorluk bu: **Değişken sonuçları nasıl doğrularız?**
/// - Tam değer yalnızca deterministik olan şeyler için: Actor ve kilitli sayaç HER ZAMAN 1000 / 1000 verir.
/// - Yarışlı sonuç (kilitsiz sayaç) için değer değil **biçim**: "Kilitsiz class: <sayı> / 1000".
/// - Süreler için değer değil biçim: "TaskGroup: 0,11 sn" → `[0-9]+,[0-9]+ sn`.
/// - Zamanlamaya bağlı akış (iptal) için kesin adım sayısı değil **değişmez**: "40 adımın hepsi bitmeden durdu".
final class ConcurrencyLabUITests: BookShelfUITestCase {

    @MainActor
    func testActorAndLockedCountersAlwaysReachExpectedTotal() {
        let lab = TabBarScreen(app: launchApp()).openLab().waitUntilDisplayed()

        XCTContext.runActivity(named: "Üç sayacı çalıştır") { _ in
            lab.runCounters()
        }

        XCTContext.runActivity(named: "Actor ve kilitli sayaç tam sonuç verir") { _ in
            assertLabel(lab.actorCounterResult, equals: "Actor: 1000 / 1000", timeout: UITestTimeout.longOperation)
            assertLabel(lab.lockedCounterResult, equals: "Kilitli class: 1000 / 1000")
        }

        XCTContext.runActivity(named: "Kilitsiz sayaç: değer değişken, biçimi sabit") { _ in
            // Data race'te kaç artışın kaybolacağı belirsizdir; hatta hiç kaybolmayabilir. Bu yüzden sayı sormuyoruz.
            // Kalıp iki durumu da kapsar: "... 1000 / 1000" ya da "... 917 / 1000 (83 artış kayboldu)".
            assertLabel(lab.unsafeCounterResult, matches: "Kilitsiz class: [0-9]+ / 1000( \\([0-9]+ artış kayboldu\\))?")
        }
    }

    @MainActor
    func testCancellingLongTaskStopsItBeforeTheEnd() {
        let lab = TabBarScreen(app: launchApp()).openLab().waitUntilDisplayed()
        lab.revealLongTask()

        XCTContext.runActivity(named: "Başlangıç: iş hazır, 'İptal et' devre dışı") { _ in
            assertLabel(lab.longTaskStatus, equals: "Hazır: 40 adım")
            XCTAssertFalse(lab.cancelLongTaskButton.isEnabled, "İş başlamadan iptal edilemez olmalı.")
        }

        XCTContext.runActivity(named: "Başlat: 'İptal et' etkinleşir") { _ in
            lab.startLongTask()
            XCTAssertTrue(lab.cancelLongTaskButton.waitUntilEnabled(), "İş başlayınca 'İptal et' etkinleşmeli.")
        }

        XCTContext.runActivity(named: "İptal et: iş 40 adımı bitirmeden durur") { _ in
            lab.cancelLongTask()
            // Kaçıncı adımda durduğu zamanlamaya bağlı (0...39); o yüzden sayıyı değil, "bitmeden durdu" kuralını
            // doğruluyoruz. Kalıp 40'ı kabul etmez: `[0-9]|[1-3][0-9]` yalnızca 0...39'a uyar.
            // (`-ui-testing` ile uzun iş 40 adım sürer; normalde 20. Bkz. `ConcurrencyLab.Settings.uiTesting`.)
            assertLabel(
                lab.longTaskStatus,
                matches: "İptal edildi: ([0-9]|[1-3][0-9]) / 40 adımda durdu",
                timeout: UITestTimeout.longOperation
            )
            // İş bitince durum sıfırlanır: yeniden başlatılabilir, iptal edilemez.
            XCTAssertTrue(lab.startLongTaskButton.waitUntilEnabled())
            XCTAssertFalse(lab.cancelLongTaskButton.isEnabled)
        }
    }

    @MainActor
    func testTaskGroupReportsDurationAndRestoresSubmissionOrder() {
        let lab = TabBarScreen(app: launchApp()).openLab().waitUntilDisplayed()
        assertLabel(lab.taskGroupResult, equals: "TaskGroup: —")

        lab.runTaskGroup()

        XCTContext.runActivity(named: "Süre ölçülür ve sonuçlar gönderilme sırasına dizilir") { _ in
            assertLabel(lab.taskGroupResult, matches: "TaskGroup: [0-9]+,[0-9]+ sn", timeout: UITestTimeout.longOperation)
            // Geliş sırası (ör. "İş 2 → İş 3 → İş 1") işlerin bitiş sırasıdır ve yük altında değişebilir.
            // Değişmeyen kısım: sonuçlar kimliklerine göre yeniden sıraya dizilir.
            assertLabel(lab.taskGroupArrivalOrder, contains: "Sıraya dizildi: 1, 2, 3")
        }
    }
}
