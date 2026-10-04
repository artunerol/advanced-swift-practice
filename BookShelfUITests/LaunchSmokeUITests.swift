import XCTest

/// Uygulamanın açıldığını ve 4 sekmenin göründüğünü doğrulayan en basit UI testi.
///
/// UI testleri uygulamayı AYRI bir süreçte başlatır ve ona "kullanıcı gibi" dokunur.
/// Uygulama modülünü import EDEMEZ; ekrandaki öğeleri erişilebilirlik (accessibility) ağacı üzerinden bulur.
final class LaunchSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        // Bir doğrulama başarısız olursa testin geri kalanını çalıştırma; ilk hatada dur.
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesWithFourTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.uiTesting]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        for title in [AccessibilityID.Tab.books, AccessibilityID.Tab.favorites, AccessibilityID.Tab.lab, AccessibilityID.Tab.interview] {
            XCTAssertTrue(tabBar.buttons[title].exists, "\(title) sekmesi bulunamadı")
        }
    }
}
