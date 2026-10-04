import Foundation

// Sahibi: Favoriler sekmesi (UIKit). Yeni kimlik gerekirse buraya ekle.
//
// UIKit'te kimlik, `accessibilityIdentifier` özelliğiyle verilir. Bu özellik `UIView`, `UIBarItem`
// (ör. `UIBarButtonItem`) ve `UIAlertAction` üzerinde vardır. XCUITest tarafında karşılıkları:
//   app.tables[AccessibilityID.Favorites.table]
//   app.cells[AccessibilityID.Favorites.cell(bookID: 1)]
//   app.staticTexts[AccessibilityID.Favorites.emptyState]
//   app.buttons[AccessibilityID.Favorites.clearAllButton]
extension AccessibilityID {
    enum Favorites {
        /// `UITableView`'un kendisi.
        static let table = "favorites.table"
        /// Liste boşken görünen açıklama metni (`UILabel`).
        static let emptyState = "favorites.emptyState"
        /// Her satır (`UITableViewCell`). Hücreler yeniden kullanıldığı (reuse) için kimlik her
        /// yapılandırmada yeniden atanır; yani ekrandaki hücre her zaman gösterdiği kitabın kimliğini taşır.
        static func cell(bookID: Int) -> String { "favorites.cell.\(bookID)" }

        /// İlk yükleme sırasında dönen gösterge (`UIActivityIndicatorView`).
        static let loadingIndicator = "favorites.loading"
        /// Kitaplar yüklenemediğinde görünen hata metni (`UILabel`).
        static let errorMessage = "favorites.error"
        /// Hata durumunda görünen "Tekrar dene" düğmesi (`UIButton`, klasik target-action).
        static let retryButton = "favorites.retry"

        /// Navigasyon çubuğundaki "Tümünü temizle" düğmesi (`UIBarButtonItem`). Liste boşken devre dışıdır.
        static let clearAllButton = "favorites.clearAll"
        /// "Tümünü temizle" onay penceresi (`UIAlertController`'ın view'ı): `app.alerts[clearAllAlert]`.
        /// Pencere başlığı da sabittir: `app.alerts["Tüm favoriler kaldırılsın mı?"]` ile de bulunabilir.
        static let clearAllAlert = "favorites.clearAllAlert"
        /// Onay penceresindeki yıkıcı (destructive) "Tümünü kaldır" düğmesi (`UIAlertAction`).
        ///
        /// Dikkat (iOS 26 simülatöründe doğrulandı): Alert düğmeleri erişilebilirlik ağacında iç içe **iki kez**
        /// görünür (aynı kimlik ve etiketle). `app.buttons[clearAllConfirmButton].tap()` "Multiple matching elements"
        /// hatası verir; `app.buttons[clearAllConfirmButton].firstMatch.tap()` kullan. Aynısı "Vazgeç" için de geçerli.
        static let clearAllConfirmButton = "favorites.clearAllConfirm"
        /// Onay penceresindeki "Vazgeç" düğmesi (`UIAlertAction`). `.firstMatch` notu için yukarıya bak.
        static let clearAllCancelButton = "favorites.clearAllCancel"

        /// Satırı sola kaydırınca çıkan "Kaldır" düğmesinin **görünen başlığı**.
        ///
        /// `UIContextualAction` bir `UIView` değildir ve `accessibilityIdentifier` özelliği yoktur.
        /// Bu yüzden (sekme düğmelerinde olduğu gibi) XCUITest onu etiket metniyle bulur:
        /// `cell.swipeLeft(); app.buttons[AccessibilityID.Favorites.removeActionTitle].tap()`.
        /// Not: Tam (uzun) kaydırma ilk eylemi doğrudan çalıştırabilir; bu durumda satır düğmeye dokunmadan kaybolur.
        static let removeActionTitle = "Kaldır"
    }
}
