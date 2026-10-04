import Foundation

/// Erişilebilirlik kimlikleri (accessibility identifier).
///
/// XCUITest, ekrandaki öğeleri bu kimliklerle bulur: `app.buttons[AccessibilityID.BookDetail.favoriteButton]`.
/// Kimlikler kullanıcıya görünmez ve metin değişse (ör. çeviri) bile sabit kalır; bu yüzden testler için
/// görünen metinden çok daha güvenilirdir.
///
/// Her özellik kendi kimliklerini ayrı bir dosyada `extension AccessibilityID` içinde tanımlar
/// (ör. `AccessibilityID+BookList.swift`). Bu dosya `Shared/` altında olduğu için hem uygulama hem UI testleri görür.
enum AccessibilityID {
    /// Sekme çubuğu düğmeleri. XCUITest'te sekme düğmeleri **etiket metni** ile bulunur:
    /// `app.tabBars.buttons[AccessibilityID.Tab.books]`. Bu yüzden buradaki değerler aynı zamanda sekme başlıklarıdır.
    enum Tab {
        static let books = "Kitaplar"
        static let favorites = "Favoriler"
        static let lab = "Laboratuvar"
        static let fundamentals = "Temeller"
    }
}
