import Foundation

// Sahibi: Kitaplar sekmesi (liste + detay). Yeni kimlik gerekirse buraya ekle.
//
// XCUITest için notlar:
// - Her kimliğin yanında, öğenin erişilebilirlik ağacında hangi TÜRDE göründüğü yazıyor. Yenileme uyarısı
//   ve detaydaki hata bölümü dışındaki tüm türler iOS 26 simülatöründe XCUITest ile doğrulandı.
//   Sorguyu o türle yaz (ör. `app.buttons[...]`). Emin değilsen `app.descendants(matching: .any)[...]` her türü arar.
// - Liste ve detay ekranı `List` kullanır; `List` TEMBELDİR (lazy): ekran dışındaki satırlar erişilebilirlik
//   ağacında YOKTUR. Detayda yorumlar, yazar biyografisi ve yükleme süresi alttadır; sorgulamadan önce
//   `app.swipeUp()` gerekebilir.
// - `-ui-testing` ile gecikme sıfır olduğu için yükleme göstergeleri pratikte hiç görünmez.
extension AccessibilityID {
    enum BookList {
        /// Kitap listesi (`List`). Tür: collectionView.
        static let list = "bookList.list"
        /// İlk yükleme sırasında görünen `ProgressView` ("Kitaplar yükleniyor…"). Tür: activityIndicator.
        static let loadingIndicator = "bookList.loading"
        /// Hata ekranının tamamı (`ContentUnavailableView`, `children: .contain`). Tür: other.
        static let errorView = "bookList.error"
        /// Hata ekranındaki açıklama metni (servisin hata mesajı). Tür: staticText.
        static let errorMessage = "bookList.errorMessage"
        /// Hata ekranındaki "Tekrar Dene" düğmesi. Tür: button.
        static let retryButton = "bookList.retry"
        /// Aşağı çekip yenileme başarısız olursa listenin üstünde çıkan uyarı. Tür: staticText.
        static let refreshErrorBanner = "bookList.refreshError"
        /// Kitap satırı (`NavigationLink`). Tür: button. Dokununca detay ekranı açılır.
        /// `label` ör. "Tutunamayanlar, Oğuz Atay · 1972". Kitap favoriyse `value` == `BookValue.favorite`,
        /// değilse boş metin ("").
        static func row(bookID: Int) -> String { "bookList.row.\(bookID)" }
    }

    enum BookDetail {
        /// Detay ekranının `List`'i. Tür: collectionView. UI testleri alttaki bölümlere kaydırmak için kullanır.
        static let list = "bookDetail.list"
        /// Kitap adı. Tür: staticText.
        static let title = "bookDetail.title"
        /// Yazar adı. Tür: staticText.
        static let author = "bookDetail.author"
        /// Kalp düğmesi. Tür: button. Kitaplar sekmesinden (SwiftUI) açılınca navigasyon çubuğunda, Favoriler
        /// sekmesinden (UIKit, `UIHostingController`) açılınca başlık bölümünün altındaki satırda durur;
        /// kimliği iki durumda da aynıdır. `value` == `BookValue.favorite` ya da `BookValue.notFavorite`.
        static let favoriteButton = "bookDetail.favoriteButton"
        /// ISBN rozeti; `label` == `BookValue.isbnValid` ya da `BookValue.isbnInvalid`. Tür: staticText.
        static let isbnStatus = "bookDetail.isbnStatus"
        /// Objective-C ile hesaplanan tahmini okuma süresi metni (ör. "5 sa 30 dk"). Tür: staticText.
        static let readingTime = "bookDetail.readingTime"
        /// Yorumlar + yazar profili yüklenirken görünen `ProgressView`. Tür: activityIndicator.
        static let extrasLoading = "bookDetail.extrasLoading"
        /// Yorumlar/yazar yüklenemezse görünen hata metni. Tür: staticText.
        static let extrasError = "bookDetail.extrasError"
        /// Yorumlar/yazar hata bölümündeki "Tekrar Dene" düğmesi. Tür: button.
        static let extrasRetryButton = "bookDetail.extrasRetry"
        /// Yazar biyografisi. Tür: staticText.
        static let authorBio = "bookDetail.authorBio"
        /// "Yükleme süresi: 1,2 sn (paralel)" metni. Tür: staticText.
        static let loadDuration = "bookDetail.loadDuration"
        /// Tek bir yorum satırı (alt öğeleri birleştirilmiş tek öğe). Tür: other → `app.otherElements[...]`.
        /// `label` ör. "Ayşe, 5 üzerinden 5 puan, Bir solukta okudum, karakterler çok canlı."
        static func review(id: Int) -> String { "bookDetail.review.\(id)" }
    }

    /// Kitaplar sekmesinde `accessibilityValue` / etiket olarak kullanılan SABİT metinler.
    /// UI testleri durumu bu değerlerle doğrular: `XCTAssertEqual(button.value as? String, BookValue.favorite)`.
    enum BookValue {
        static let favorite = "Favori"
        static let notFavorite = "Favori değil"
        static let isbnValid = "Geçerli"
        static let isbnInvalid = "Geçersiz"
    }
}
