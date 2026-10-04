import XCTest

/// `XCUIElement` için "koşul sağlanana kadar bekle" ve "görünene kadar kaydır" yardımcıları.
///
/// Neden gerekli? UI testi uygulamadan AYRI bir süreçte çalışır. Bir düğmeye dokunduğumuzda uygulama o dokunuşu
/// kendi hızında işler: bir `Task` başlatır, bir actor'ü bekler, ekranı yeniden çizer. Dokunuştan hemen sonra
/// ekranı okursak eski durumu görebiliriz. Doğru yol sabit bir süre uyumak (`sleep(2)`) değil, **beklediğimiz
/// koşulu tarif edip** o koşul sağlanana kadar (bir üst sınırla) beklemektir.
///
/// Tüm fonksiyonlar `Bool` döndürür ve kendileri test başarısızlığı raporlamaz. Doğrulama kararı çağırana
/// (testin kendisine ya da `BookShelfUITestCase`'teki `assert...` yardımcılarına) aittir. Böylece aynı
/// yardımcı hem doğrulamada hem de "varsa şunu yap" gibi kontrol akışında kullanılabilir.
///
/// `XCUIElement` SDK'da `@MainActor` olarak işaretlidir; bu extension'daki metotlar da ana actor'dedir.
extension XCUIElement {

    // MARK: - Koşul beklemek (predicate expectation)

    /// `predicate` bu öğe üzerinde doğru olana kadar en fazla `timeout` saniye bekler.
    ///
    /// - `XCTNSPredicateExpectation`: Verilen `NSPredicate`'i nesne (burada öğe) üzerinde, koşul sağlanana kadar
    ///   aralıklarla yeniden değerlendirir. Her değerlendirmede XCUITest uygulamadan taze bir anlık görüntü
    ///   (snapshot) alır; yani `label`, `value`, `exists` hep güncel değeri verir.
    /// - `XCTWaiter().wait(for:timeout:)`: `XCTestCase.wait(for:timeout:)`'un aksine zaman aşımında testi kendisi
    ///   kırmaz, sonucu (`.completed`, `.timedOut` ...) döndürür. Hata mesajını çağıran, gerçek değerle birlikte yazar.
    ///
    /// Predicate'lerin hepsi `exists == true AND ...` ile başlar: Olmayan bir öğenin `label`'ını okumak XCUITest'te
    /// "No matches found" hatasıdır. `AND` ilk koşul yanlışsa ikincisini hiç değerlendirmez.
    func waitUntil(_ predicate: NSPredicate, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// `label` tam olarak `expected` olana kadar bekler.
    func waitForLabel(_ expected: String, timeout: TimeInterval = UITestTimeout.standard) -> Bool {
        waitUntil(NSPredicate(format: "exists == true AND label == %@", expected), timeout: timeout)
    }

    /// `label` `substring`'i içerene kadar bekler. Metnin bir kısmı değişken olduğunda (ör. süreler) kullanılır.
    func waitForLabel(containing substring: String, timeout: TimeInterval = UITestTimeout.standard) -> Bool {
        waitUntil(NSPredicate(format: "exists == true AND label CONTAINS %@", substring), timeout: timeout)
    }

    /// `label` düzenli ifadeye (regex) TAMAMEN uyana kadar bekler. `MATCHES`, metnin bir parçasını değil
    /// tamamını karşılaştırır (ICU regex sözdizimi).
    func waitForLabel(matching pattern: String, timeout: TimeInterval = UITestTimeout.standard) -> Bool {
        waitUntil(NSPredicate(format: "exists == true AND label MATCHES %@", pattern), timeout: timeout)
    }

    /// `value` (ör. `accessibilityValue`) tam olarak `expected` olana kadar bekler.
    func waitForValue(_ expected: String, timeout: TimeInterval = UITestTimeout.standard) -> Bool {
        waitUntil(NSPredicate(format: "exists == true AND value == %@", expected), timeout: timeout)
    }

    /// Öğe etkinleşene (`isEnabled == true`) kadar bekler. Örneğin bir iş başlayınca açılan "İptal et" düğmesi.
    func waitUntilEnabled(timeout: TimeInterval = UITestTimeout.standard) -> Bool {
        waitUntil(NSPredicate(format: "exists == true AND isEnabled == true"), timeout: timeout)
    }

    // MARK: - Kaydırarak göstermek

    /// Bu öğeyi (bir `List`, `Form` ya da tablo) `target` **dokunulabilir** hale gelene kadar yukarı kaydırır.
    ///
    /// Neden gerekli? SwiftUI `List`/`Form` ve `UITableView` tembeldir (lazy): yalnızca ekrandaki satırları oluşturur.
    /// Ekranın altındaki bir satır erişilebilirlik ağacında henüz **yoktur**; `waitForExistence` onu hiç bulamaz.
    /// Ayrıca iOS 26'daki yüzen sekme çubuğu listenin üstünde durur: altında kalan bir satır "var" ama dokunuş sekme
    /// çubuğuna gider. `isHittable`, dokunma noktasının gerçekten o öğeye düşüp düşmediğini söyler.
    ///
    /// `swipeUp(velocity: .slow)`: Yavaş kaydırma az ivme (momentum) bırakır; hedef satırı atlayıp geçme ihtimali düşer.
    /// `maxSwipes` sonsuz döngüye karşı üst sınırdır: liste bittiğinde kaydırmak hiçbir şeyi değiştirmez.
    ///
    /// Koordinat kullanmıyoruz: Kaydırma kabın kendisine uygulanır, XCUITest kabın ortasından başlatır.
    /// Bu yüzden farklı ekran boyutlarında da aynı şekilde çalışır.
    @discardableResult
    func scrollUp(toReveal target: XCUIElement, maxSwipes: Int = 8) -> Bool {
        var swipes = 0
        while !(target.exists && target.isHittable) {
            guard swipes < maxSwipes else { return false }
            swipeUp(velocity: .slow)
            swipes += 1
        }
        return true
    }
}
