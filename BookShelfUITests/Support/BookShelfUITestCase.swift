import XCTest

/// Bu projedeki tüm akış (flow) UI testlerinin ortak üst sınıfı.
///
/// Üç iş yapar:
/// 1. **Kurulum:** `continueAfterFailure = false`. UI testinde bir adım başarısız olursa (ör. detay ekranı açılmadı)
///    sonraki adımlar zaten anlamsızdır ve kafa karıştıran ikinci, üçüncü hatalar üretir. İlk hatada dururuz.
/// 2. **Başlatma:** `launchApp(extraArguments:)` uygulamayı HER ZAMAN `-ui-testing` ile başlatır. Unutulması
///    mümkün olmayan tek bir giriş noktası olduğu için hiçbir test yanlışlıkla 600 ms gecikmeli servisle koşmaz.
/// 3. **Bekleyen doğrulamalar:** `assertLabel`, `assertValue`, `assertAppears`... Her biri önce koşulu bekler,
///    başarısız olursa **gerçek** değeri de mesaja yazar ve hatayı testteki satıra (`file:line:`) bağlar.
///
/// Neden sınıfın tamamı `@MainActor` değil? `XCTestCase`'in senkron `setUp`/`tearDown` override'ları nonisolated
/// kalır; sınıfı ana actor'e bağlamak orada uyarılara yol açar (bkz. docs/09-xctest.md). Bunun yerine
/// `XCUIApplication`'a dokunan her metot ayrı ayrı `@MainActor` işaretlenir.
///
/// Bu sınıfta `test...` ile başlayan metot yok; XCTest onu listeler ama içinde çalışacak test bulmaz.
class BookShelfUITestCase: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // MARK: - Başlatma

    /// Uygulamayı test modunda (ayrı bir süreç olarak) başlatır ve sekme çubuğu görünene kadar bekler.
    ///
    /// - `launchArguments`: Uygulamanın `ProcessInfo.processInfo.arguments` dizisine eklenir.
    ///   `AppDependencies.makeForLaunch(arguments:)` bunlara bakıp sıfır gecikmeli ya da hata veren servisi kurar.
    /// - `launchEnvironment` (burada kullanılmıyor): Aynı işi ortam değişkenleriyle yapar; uygulama
    ///   `ProcessInfo.processInfo.environment["ANAHTAR"]` ile okur. Değer taşımak gerekince (ör. bir URL) daha uygundur.
    /// - `launch()` her çağrıda uygulamayı SIFIRDAN başlatır; çalışan bir kopya varsa önce kapatır. Favoriler bellekte
    ///   tutulduğu için her test boş bir favori listesiyle başlar: testler birbirinden bağımsızdır.
    @MainActor
    func launchApp(
        extraArguments: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.uiTesting] + extraArguments
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: UITestTimeout.launch),
            "Uygulama \(UITestTimeout.launch) sn içinde açılmadı (sekme çubuğu görünmedi).",
            file: file, line: line
        )
        return app
    }

    // MARK: - Bekleyen doğrulamalar

    /// `element`'in `label`'ı `expected` olana kadar bekler; olmazsa gerçek değeri yazarak testi kırar.
    @MainActor
    func assertLabel(
        _ element: XCUIElement,
        equals expected: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForLabel(expected, timeout: timeout),
            "Beklenen label: \"\(expected)\", gerçek: \(Self.currentLabel(of: element))",
            file: file, line: line
        )
    }

    /// `element`'in `label`'ı `substring`'i içerene kadar bekler.
    @MainActor
    func assertLabel(
        _ element: XCUIElement,
        contains substring: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForLabel(containing: substring, timeout: timeout),
            "Label \"\(substring)\" içermiyor. Gerçek: \(Self.currentLabel(of: element))",
            file: file, line: line
        )
    }

    /// `element`'in `label`'ı düzenli ifadeye (`pattern`) tamamen uyana kadar bekler.
    @MainActor
    func assertLabel(
        _ element: XCUIElement,
        matches pattern: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForLabel(matching: pattern, timeout: timeout),
            "Label /\(pattern)/ kalıbına uymuyor. Gerçek: \(Self.currentLabel(of: element))",
            file: file, line: line
        )
    }

    /// `element`'in `value`'su (ör. `accessibilityValue`) `expected` olana kadar bekler.
    @MainActor
    func assertValue(
        _ element: XCUIElement,
        equals expected: String,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForValue(expected, timeout: timeout),
            "Beklenen value: \"\(expected)\", gerçek: \(Self.currentValue(of: element))",
            file: file, line: line
        )
    }

    /// `element` erişilebilirlik ağacında görünene kadar bekler.
    @MainActor
    func assertAppears(
        _ element: XCUIElement,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "\(element) \(timeout) sn içinde görünmedi.",
            file: file, line: line
        )
    }

    /// `element` erişilebilirlik ağacından kaybolana kadar bekler (ör. silinen satır, kapanan ekran).
    @MainActor
    func assertDisappears(
        _ element: XCUIElement,
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForNonExistence(timeout: timeout),
            "\(element) \(timeout) sn sonra hâlâ ekranda.",
            file: file, line: line
        )
    }

    // MARK: - Hata mesajı yardımcıları

    /// Hata mesajında gösterilecek güncel `label`. Öğe yoksa `label`'ı okumak ayrı bir hata üreteceği için önce bakarız.
    @MainActor
    private static func currentLabel(of element: XCUIElement) -> String {
        element.exists ? "\"\(element.label)\"" : "öğe bulunamadı (\(element))"
    }

    @MainActor
    private static func currentValue(of element: XCUIElement) -> String {
        guard element.exists else { return "öğe bulunamadı (\(element))" }
        return element.value.map { "\"\($0)\"" } ?? "nil"
    }
}
