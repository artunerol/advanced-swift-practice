import XCTest

/// Page Object (ekran nesnesi) kalıbının ortak sözleşmesi.
///
/// **Page Object nedir?** Uygulamanın her ekranı için, o ekrandaki öğeleri nasıl bulacağımızı (`app.buttons[...]`)
/// ve ekranda neler yapılabileceğini (`openBook(id:)`, `toggleFavorite()`) bilen küçük bir tip yazarız.
/// Testler `app.buttons["bookList.row.8"].tap()` yerine `bookList.openBook(id: 8)` der.
///
/// Kazançlar:
/// - **Tek değişiklik noktası:** Bir öğenin kimliği ya da ekranın yapısı değişirse yalnızca o ekranın dosyası
///   güncellenir; ona bağlı on test değil.
/// - **Okunabilirlik:** Test, kullanıcının niyetini anlatır ("kitabı favorile, Favoriler sekmesine geç"),
///   XCUITest sorgularının ayrıntısını değil.
/// - **Navigasyon tipi taşır:** `openBook(id:)` bir `BookDetailScreen` döndürür. Detay ekranında olmayan bir
///   öğeyi aramaya çalışmak derleme anında zorlaşır.
///
/// Kural: Ekran nesneleri öğeleri ve eylemleri sunar; **doğrulama (assert) testte yapılır.** İstisna, ekranın
/// açıldığını doğrulayan `waitUntilDisplayed()`: navigasyonun bir parçası olduğu için burada durur.
///
/// Ekranlar `struct`: Kendi durumları yoktur, sadece `app`'i taşırlar. Öğeleri hesaplanan özellik
/// (`var x: XCUIElement { ... }`) olarak tanımlıyoruz. Bir `XCUIElement` "bulunmuş bir öğe" değil, bir **sorgu
/// tarifidir**: Her kullanımda (`tap()`, `label`, `exists`) XCUITest onu o anki ekranda yeniden çözer. Bu yüzden
/// ekran değiştikten sonra da güvenle kullanılabilir; eski bir görüntüye takılı kalmaz.
///
/// `@MainActor`: `XCUIApplication` ve `XCUIElement` güncel SDK'da ana actor'e bağlıdır; onlara dokunan her şey de öyle.
@MainActor
protocol Screen {
    var app: XCUIApplication { get }

    /// Ekranın açıldığını kanıtlayan, ekran açıkken HER ZAMAN var olan bir öğe.
    var rootElement: XCUIElement { get }
}

extension Screen {
    /// Ekran görünene kadar bekler; görünmezse testi, bu metodu çağıran satırda kırar.
    ///
    /// `@discardableResult` ve `Self` dönüşü zincirleme yazmayı sağlar:
    /// `let detail = BookDetailScreen(app: app).waitUntilDisplayed()`
    @discardableResult
    func waitUntilDisplayed(
        timeout: TimeInterval = UITestTimeout.standard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        XCTAssertTrue(
            rootElement.waitForExistence(timeout: timeout),
            "\(Self.self) \(timeout) sn içinde görünmedi. Aranan öğe: \(rootElement)",
            file: file, line: line
        )
        return self
    }

    /// Her ekrandan sekme çubuğuna ulaşmak için.
    var tabBar: TabBarScreen { TabBarScreen(app: app) }

    /// Navigasyon çubuğundaki geri düğmesine dokunur.
    ///
    /// Geri düğmesini sistem oluşturur; kimliği ve etiketi bizim kontrolümüzde değildir. iOS 26'da kimliği
    /// `"BackButton"`, etiketi önceki ekranın başlığıdır (ör. "Kitaplar"), ama bu sürümden sürüme değişebilir.
    /// Değişmeyen şey şu: Push edilmiş bir ekranda navigasyon çubuğundaki İLK düğme geri düğmesidir
    /// (bizim eklediğimiz düğmeler sağda, `.topBarTrailing`'de durur).
    func tapBackButton() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
