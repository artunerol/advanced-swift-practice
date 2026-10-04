import Foundation

/// ISBN doğrulayıcı ekranında gösterilecek sonuç.
///
/// Neden view'un içinde değil de ayrı bir tip?
/// Objective-C hatasını (`NSError`) Swift'te yakalayıp ekrana uygun bir modele çeviren mantık burada.
/// SwiftUI'dan bağımsız olduğu için unit test ile doğrudan doğrulanabilir; view sadece sonucu çizer.
///
/// Neden `enum`? Sonuç ya geçerlidir ya geçersizdir; ikisi aynı anda olamaz. "Hem geçerli hem hata mesajı var"
/// gibi imkânsız durumlar enum ile *temsil edilemez* hale gelir. Ayrı `isValid`, `errorMessage` alanları
/// tutsaydık bu tutarlılığı her yerde elle korumamız gerekirdi.
enum ISBNCheckOutcome: Equatable {
    /// ISBN geçerli. `normalized`: tireleri ve boşlukları temizlenmiş hali.
    case valid(normalized: String)

    /// ISBN geçersiz.
    /// - `code`: Objective-C'deki `NS_ERROR_ENUM`'dan gelen tipli hata kodu. Hata beklenmedik bir türdeyse `nil`.
    /// - `message`: `NSError`'ın `localizedDescription`'ı (ObjC tarafında yazılan Türkçe mesaj).
    /// - `hint`: Kullanıcıya ek ipucu (ör. doğru kontrol hanesi). Her hata için olmayabilir.
    case invalid(code: BKISBNValidatorError.Code?, message: String, hint: String?)

    /// Geçerli ISBN için gösterilen metin.
    static let validMessage = "Geçerli ISBN-13 ✓"

    /// Sonuç satırında gösterilecek ana metin.
    var message: String {
        switch self {
        case .valid: Self.validMessage
        case .invalid(_, let message, _): message
        }
    }

    var isValid: Bool {
        if case .valid = self { true } else { false }
    }

    /// Girdiyi Objective-C doğrulayıcısına verip sonucu Swift modeline çevirir.
    static func evaluate(_ input: String) -> ISBNCheckOutcome {
        let normalized = ISBNValidator.normalizedISBN(input)
        do {
            // ObjC imzası: + (BOOL)validateISBN13:(NSString *)isbn error:(NSError **)error
            // Swift'teki hali: static func validateISBN13(_ isbn: String) throws
            // BOOL dönüşü kayboldu: NO + dolu `*error` -> Swift'te `throw`; YES -> normal dönüş.
            try ISBNValidator.validateISBN13(input)
            return .valid(normalized: normalized)
        } catch let error as BKISBNValidatorError {
            // `NS_ERROR_ENUM` sayesinde ObjC'nin `NSError`'ı Swift'e TİPLİ bir hata olarak gelir.
            // `error.code` bir `NSInteger` değil, `BKISBNValidatorError.Code` enum'udur; `switch` ile ele alabiliriz.
            return .invalid(
                code: error.code,
                message: error.localizedDescription,
                hint: hint(for: error.code, normalized: normalized)
            )
        } catch {
            // Swift'te bir `throws` fonksiyon herhangi bir `Error` fırlatabilir (tipsiz throws). Derleyici bu yüzden
            // genel bir `catch` ister. Doğrulayıcımız yalnızca kendi domain'inden hata üretse de savunmacı davranıyoruz.
            return .invalid(code: nil, message: error.localizedDescription, hint: nil)
        }
    }

    /// Hata koduna göre kullanıcıya gösterilecek ek ipucu.
    private static func hint(for code: BKISBNValidatorError.Code, normalized: String) -> String? {
        switch code {
        case .empty:
            return "Bir ISBN yazın ya da aşağıdaki örneklerden birine dokunun."
        case .invalidCharacters:
            return "Tire ve boşluklar otomatik temizlenir; kalan her karakter 0-9 arası bir rakam olmalı."
        case .invalidLength:
            return nil
        case .checksumMismatch:
            // Başka bir ObjC API'si: `+checkDigitForFirst12Digits:` -> Swift'te `checkDigit(forFirst12Digits:)`.
            // `nullable` dönüş tipi Swift'te `String?` olduğu için `guard let` ile açıyoruz.
            guard let checkDigit = ISBNValidator.checkDigit(forFirst12Digits: String(normalized.prefix(12))) else {
                return nil
            }
            return "Doğru kontrol hanesi: \(checkDigit)"
        @unknown default:
            // C'den gelen enum'lar "donmamış" (non-frozen) kabul edilir: ObjC tarafı ileride yeni bir hata kodu
            // ekleyebilir. Swift 6 bu yüzden `@unknown default` olmadan bu `switch`'i derlemez.
            // `default` yerine `@unknown default` yazmanın faydası: bilinen bir vakayı unutursak derleyici UYARIR.
            return nil
        }
    }
}
