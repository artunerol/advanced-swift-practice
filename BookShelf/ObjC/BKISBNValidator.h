//
//  BKISBNValidator.h
//  BookShelf
//
//  Objective-C'de bir sınıfın "genel arayüzü" (public interface) .h (header) dosyasında,
//  "uygulaması" (implementation) ise .m dosyasında yazılır. Swift bu header'ı
//  BookShelf-Bridging-Header.h üzerinden görür ve otomatik olarak Swift API'sine çevirir.
//
//  Swift'te nasıl görünür?
//      ISBNValidator.normalizedISBN("978-605-...")                    -> String
//      ISBNValidator.isValidISBN13("978-605-...")                     -> Bool
//      try ISBNValidator.validateISBN13("978-605-...")                -> throws (NSError** => Swift hatası)
//      ISBNValidator.checkDigit(forFirst12Digits: "978605000008")     -> String?  (nullable => Optional)
//
//  ISBN-13 kontrol hanesi nasıl hesaplanır?
//      İlk 12 hane sırayla 1, 3, 1, 3, ... ağırlıklarıyla çarpılıp toplanır.
//      Kontrol hanesi = (10 - toplam % 10) % 10   (sondaki % 10, toplam 10'un katıysa sonucu 0 yapar.)
//      Örnek: 978605000001 -> 9·1 + 7·3 + 8·1 + 6·3 + 0·1 + 5·3 + ... + 1·3 = 74 -> (10 - 4) % 10 = 6 -> 978-605-000-001-6
//

#import <Foundation/Foundation.h>

// NS_ASSUME_NONNULL_BEGIN/END arasındaki tüm pointer'lar varsayılan olarak "nil olamaz" (nonnull) kabul edilir.
// Swift tarafında bunlar `String!` (implicitly unwrapped) yerine düz `String` olarak görünür.
NS_ASSUME_NONNULL_BEGIN

/// ISBN doğrulama hatalarının "alanı" (domain). NSError'lar domain + code ikilisiyle tanımlanır.
///
/// `FOUNDATION_EXPORT` (= `extern`): Bu sabitin burada yalnızca *bildirildiğini*, değerinin ise .m dosyasında
/// *tanımlandığını* söyler. Değeri header'a yazsaydık, header'ı import eden her dosya kendi kopyasını üretirdi.
FOUNDATION_EXPORT NSErrorDomain const BKISBNValidatorErrorDomain;

/// NS_ERROR_ENUM, Swift'e bu hataların *tipli* olarak aktarılmasını sağlar:
/// Swift'te `catch let error as BKISBNValidatorError { if error.code == .checksumMismatch { ... } }`
///
/// Swift'e aktarılan şekli (kabaca):
///     struct BKISBNValidatorError: Error {        // NSError'ı saran tipli bir hata
///         enum Code: Int { case empty = 1, invalidLength, invalidCharacters, checksumMismatch }
///         var code: Code { get }
///         static var errorDomain: String { get }  // "BKISBNValidatorErrorDomain"
///     }
/// Vaka adlarındaki ortak `BKISBNValidatorError` öneki Swift'te otomatik olarak atılır.
/// Not: C enum'ları "genişleyebilir" (non-frozen) kabul edilir; Swift 6'da `switch error.code` yazarken
/// `@unknown default` vakası zorunludur.
typedef NS_ERROR_ENUM(BKISBNValidatorErrorDomain, BKISBNValidatorError) {
    /// Girdi boş (tire ve boşluklar temizlendikten sonra hiç karakter kalmadı).
    BKISBNValidatorErrorEmpty = 1,
    /// Tire/boşluk temizlendikten sonra 13 karakter değil.
    BKISBNValidatorErrorInvalidLength = 2,
    /// Rakam dışında karakter var.
    BKISBNValidatorErrorInvalidCharacters = 3,
    /// Kontrol hanesi (son hane) tutmuyor.
    BKISBNValidatorErrorChecksumMismatch = 4,
};

/// ISBN-13 doğrulayıcı.
///
/// Objective-C'de isim çakışmalarını önlemek için sınıf adlarına önek (prefix) konur: "BK" = BookShelf Kit.
/// `NS_SWIFT_NAME` ile Swift tarafında öneksiz, daha doğal bir ad veriyoruz: `ISBNValidator`.
///
/// Tüm metotlar sınıf metodu (`+`); sınıfın hiç durumu (state) yok. Bu yüzden thread'ler arasında
/// güvenle çağrılabilir.
NS_SWIFT_NAME(ISBNValidator)
@interface BKISBNValidator : NSObject

/// Tire ve boşlukları temizler: "978-605-000-001-3" -> "9786050000013".
///
/// Başka hiçbir karakteri silmez: "978-ABC" -> "978ABC". Karakterlerin geçerliliğine
/// `validateISBN13:error:` karar verir.
+ (NSString *)normalizedISBN:(NSString *)isbn;

/// Basit evet/hayır API'si. BOOL, Swift'te `Bool` olur.
/// Hata ayrıntısı gerekmediğinde `validateISBN13:error:`'u `error` yerine `NULL` vererek çağırır.
+ (BOOL)isValidISBN13:(NSString *)isbn;

/// Hata ayrıntısı veren API.
///
/// Objective-C geleneği: başarıda YES döner; başarısızlıkta NO döner ve `*error`'u doldurur.
/// Swift bu kalıbı tanır ve fonksiyonu otomatik olarak `throws` yapar; son `error:` parametresi kaybolur:
///     do { try ISBNValidator.validateISBN13(text) } catch { ... }
///
/// Denetim sırası (ilk başarısız olan kural hatayı belirler):
///   1. Temizlenmiş metin boş              -> BKISBNValidatorErrorEmpty
///   2. Rakam (0-9) dışı karakter var       -> BKISBNValidatorErrorInvalidCharacters
///   3. Uzunluk 13 değil                    -> BKISBNValidatorErrorInvalidLength
///   4. Kontrol hanesi tutmuyor             -> BKISBNValidatorErrorChecksumMismatch
/// Hatanın `localizedDescription`'ı kullanıcıya gösterilebilecek Türkçe bir mesajdır.
+ (BOOL)validateISBN13:(NSString *)isbn error:(NSError * _Nullable * _Nullable)error;

/// İlk 12 hane için kontrol hanesini ("0"..."9") hesaplar.
/// Girdi 12 rakam değilse `nil` döner. `nullable` dönüş tipi Swift'te `String?` (Optional) olur.
///
/// Girdi temizlenmez: tam olarak 12 ASCII rakam beklenir ("978-605-..." gibi tireli bir girdi `nil` döner).
+ (nullable NSString *)checkDigitForFirst12Digits:(NSString *)digits NS_SWIFT_NAME(checkDigit(forFirst12Digits:));

@end

NS_ASSUME_NONNULL_END
