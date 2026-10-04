import Foundation

/// UI testlerinde kullanılan bekleme süreleri (saniye).
///
/// Bunlar **gecikme değil, üst sınırdır**. `waitForExistence(timeout:)` gibi beklemeler koşul sağlandığı an döner;
/// her şey yolundaysa test bu sürelerin hiçbirini tam olarak beklemez. Bu yüzden süreleri cömert tutmanın,
/// geçen bir testi yavaşlatmak gibi bir bedeli yoktur. Sadece bir hata durumunda testin ne kadar sonra
/// kırılacağını belirler. Yüklü bir CI makinesi, geliştirici Mac'inden birkaç kat yavaş olabilir.
///
/// Sabitleri tek yerde toplamak, "bu test neden 3, şu test neden 10 saniye bekliyor?" sorusunu ortadan kaldırır.
enum UITestTimeout {
    /// Uygulamanın açılıp ilk ekranın gelmesi. Soğuk açılış (ilk kurulum) en yavaş adımdır.
    static let launch: TimeInterval = 20
    /// Bir dokunuştan sonra ekranın güncellenmesi (navigasyon, durum değişikliği).
    static let standard: TimeInterval = 10
    /// Laboratuvardaki, gerçekten zaman harcayan deneyler (sayaçlar, TaskGroup, uzun işin iptali).
    static let longOperation: TimeInterval = 30
}
