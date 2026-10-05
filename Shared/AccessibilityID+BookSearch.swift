import Foundation

// Sahibi: Kitap Arama VIPER modülü (BookSearchViewController + BookSearchRouter).
// Mülakat merkezinde "VIPER'da bir servis çağrısı nasıl akar?" konusunun demosunda görünür.
extension AccessibilityID {
    enum BookSearch {
        /// `UISearchBar` → XCUITest'te `searchFields`.
        static let searchField = "bookSearch.searchField"
        static let table = "bookSearch.table"
        /// Sonuç satırı (hücre). Kitap kimliği satırı bulmanın kararlı yolu; başlık değişse de test kırılmaz.
        static func resultCell(bookID: Int) -> String { "bookSearch.result.\(bookID)" }
        /// Geçmişteki `index`. arama (0 = en yeni).
        static func recentCell(_ index: Int) -> String { "bookSearch.recent.\(index)" }

        /// Yükleniyor / boş / hata mesajı ve "Tekrar dene" düğmesi.
        static let loadingIndicator = "bookSearch.loading"
        static let messageLabel = "bookSearch.message"
        static let retryButton = "bookSearch.retry"
        /// Favori geri bildirimi, ör. "“Huzur” favorilere eklendi."
        static let statusLabel = "bookSearch.status"

        /// Sola kaydırınca çıkan eylemlerin **görünen başlıkları**. `UIContextualAction` bir view değildir, kimlik
        /// alamaz; XCUITest onu etiketiyle bulur: `cell.swipeLeft(); app.buttons[BookSearch.insightsActionTitle].tap()`.
        static let insightsActionTitle = "Özet"
        static let favoriteActionTitle = "Favori"

        /// Kitap özeti penceresi (`UIAlertController`) ve "Tamam" düğmesi.
        static let insightsAlert = "bookSearch.insights"
        static let insightsOKButton = "bookSearch.insights.ok"
        /// Özet yüklenemediğinde çıkan hata penceresi.
        static let errorAlert = "bookSearch.error"

        /// Detay ekranının altındaki "Sonuçlara dön" düğmesi (UIKit navigasyon çubuğu gizli; bkz. `BookSearchVIPERContainer`).
        static let backToResultsButton = "bookSearch.backToResults"
    }
}
