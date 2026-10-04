import XCTest

/// Mülakat → "iOS'ta veri saklama yolları" demosu.
///
/// Durum bağımsızlığı: `-ui-testing` ile uygulama, kalıcı veriyi gerçek konum yerine her açılışta SİLİNEN ayrı bir
/// konuma yazar (`PersistenceLocation.current`: geçici klasör + ayrı UserDefaults suite'i + ayrı Keychain service'i).
/// Bu yüzden her test sıfır notla ve varsayılan okuma hızıyla başlar; bir testin yazdığı veri sonrakini bozmaz.
final class PersistenceUITests: BookShelfUITestCase {
    private typealias Raw = AccessibilityID.Persistence.StorageKindRawValue

    @MainActor
    private func openPersistenceDemo(file: StaticString = #filePath, line: UInt = #line) -> (XCUIApplication, PersistenceScreen) {
        let app = launchApp(file: file, line: line)
        TabBarScreen(app: app).openInterview().waitUntilDisplayed(file: file, line: line)
            .openTopic(AccessibilityID.Interview.TopicID.persistence, file: file, line: line)
            .showDemo()
        return (app, PersistenceScreen(app: app).waitUntilDisplayed(file: file, line: line))
    }

    /// Dosyaya yazılan not, aynı depoya yeni bir örnekle bağlanınca da görünür; bellekteki not görünmez.
    @MainActor
    func testFileNoteSurvivesReopenButInMemoryNoteDoesNot() {
        let (_, screen) = openPersistenceDemo()
        screen.showNotes()

        XCTContext.runActivity(named: "Dosya (varsayılan seçili): not ekle, sayı 0 → 1") { _ in
            assertValue(screen.kindRow(Raw.file), equals: "Seçili")
            assertLabel(screen.selectedCount, equals: "Not sayısı: 0")
            screen.addSample()
            assertLabel(screen.selectedCount, equals: "Not sayısı: 1")
        }

        XCTContext.runActivity(named: "Dosya: yeni örnekle yeniden aç → not hâlâ orada") { _ in
            screen.reopen()
            assertLabel(screen.message, equals: "Yeni örnek 1 not gördü: veri kalıcı.")
            assertLabel(screen.selectedCount, equals: "Not sayısı: 1")
        }

        XCTContext.runActivity(named: "Bellek: not ekle, yeniden aç → not kayboldu") { _ in
            screen.selectKind(Raw.inMemory)
            assertLabel(screen.survivesRelaunch, equals: "Kapatıp açınca kalır mı? Hayır")
            screen.addSample()
            assertLabel(screen.selectedCount, equals: "Not sayısı: 1")
            screen.reopen()
            assertLabel(screen.message, equals: "Yeni örnek 0 not gördü: veri yalnızca eski örneğin belleğindeydi.")
            assertLabel(screen.selectedCount, equals: "Not sayısı: 0")
        }
    }

    /// Keychain: kaydet → oku (maskeli) → sil → oku (kayıt yok). Sır ekranda hiçbir zaman açık görünmez.
    @MainActor
    func testKeychainTokenRoundTripShowsOnlyMaskedValue() {
        let (_, screen) = openPersistenceDemo()

        XCTContext.runActivity(named: "Kaydet ve oku: token maskeli görünür") { _ in
            screen.saveToken()
            assertLabel(screen.keychainStatus, equals: "Kaydedildi")
            screen.readToken()
            assertLabel(screen.keychainStatus, equals: "Okundu")
            screen.reveal(screen.keychainMaskedToken)
            assertLabel(screen.keychainMaskedToken, equals: "bk_d••••••••9F4K")
        }

        XCTContext.runActivity(named: "Sil ve tekrar oku: kayıt yok") { _ in
            screen.deleteToken()
            assertLabel(screen.keychainStatus, equals: "Silindi")
            screen.readToken()
            assertLabel(screen.keychainStatus, equals: "Kayıt yok")
            assertLabel(screen.keychainMaskedToken, equals: "—")
        }
    }

    /// UserDefaults'taki okuma hızı ayarı, başka bir ekrandaki hesaplamayı değiştirir.
    @MainActor
    func testReadingSpeedSettingChangesBookDetailEstimate() {
        let (app, screen) = openPersistenceDemo()

        XCTContext.runActivity(named: "Varsayılan: saatte 40 sayfa → 400 sayfa 10 saat") { _ in
            assertLabel(screen.readingSpeedExample, equals: "400 sayfalık bir kitap ≈ 10 sa")
        }

        XCTContext.runActivity(named: "Hızı 45'e çıkar: 400 sayfa ≈ 8 sa 53 dk") { _ in
            screen.increaseReadingSpeed()
            assertLabel(screen.readingSpeedExample, equals: "400 sayfalık bir kitap ≈ 8 sa 53 dk")
        }

        XCTContext.runActivity(named: "Kitap detayı yeni hızı kullanır: 724 sayfa ≈ 16 sa 5 dk (40 ile 18 sa 6 dk)") { _ in
            let detail = TabBarScreen(app: app).openBooks().waitUntilDisplayed().openBook(id: 1)
            assertLabel(detail.readingTime, equals: "16 sa 5 dk")
        }
    }
}
