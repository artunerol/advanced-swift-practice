import Foundation

// Sahibi: ISBN doğrulayıcı ekranı (Objective-C köprüsü). Yeni kimlik gerekirse buraya ekle.
extension AccessibilityID {
    enum ISBNChecker {
        /// ISBN metin kutusu (`app.textFields[...]`).
        static let inputField = "isbnChecker.input"
        /// "Doğrula" düğmesi (`app.buttons[...]`).
        static let validateButton = "isbnChecker.validate"
        /// Sonuç metni (`app.staticTexts[...]`): "Geçerli ISBN-13 ✓" ya da ObjC hatasının mesajı.
        /// Yalnızca bir doğrulamadan sonra görünür; girdi değişince kaybolur.
        static let resultLabel = "isbnChecker.result"
        /// Geçersiz sonuçta ek ipucu (`app.staticTexts[...]`), ör. "Doğru kontrol hanesi: 5". Her hatada görünmez.
        static let hintLabel = "isbnChecker.hint"
        /// Geçerli sonuçta ISBN'in tiresiz/boşluksuz hali (`app.staticTexts[...]`).
        static let normalizedLabel = "isbnChecker.normalized"

        /// "Örnekler" bölümündeki düğmeler (`app.buttons[...]`). Dokununca metin kutusunu doldururlar.
        /// Geçerli: 978-605-000-001-6
        static let sampleValidButton = "isbnChecker.sample.valid"
        /// Kontrol hanesi hatalı: 978-605-000-008-6
        static let sampleChecksumMismatchButton = "isbnChecker.sample.checksumMismatch"
        /// Harf içeren: 978-605-ABC-001-6
        static let sampleLettersButton = "isbnChecker.sample.letters"
    }
}
