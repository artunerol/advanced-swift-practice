//
//  BKISBNValidator.m
//  BookShelf
//
//  BKISBNValidator'ın uygulaması (implementation). Header'da söz verilen her metot burada yazılır.
//
//  Bu dosyada görülecek Objective-C alışkanlıkları:
//  - ARC (Automatic Reference Counting): `retain`/`release` yazmıyoruz; derleyici ekliyor.
//  - `static` C fonksiyonları: Sınıfın dışında, yalnızca bu dosyaya özel yardımcılar (Swift'teki `private func`).
//  - `dispatch_once`: Bir değeri tek sefer ve thread-safe biçimde oluşturmak (Swift'teki `static let`).
//  - `NSError **` çıkış parametresi (out-parameter) ve NULL denetimi.
//  - Erken dönüş (early return): Her kural başarısız olduğunda hemen çıkıyoruz; iç içe `if` yok.
//

#import "BKISBNValidator.h"

// Header'da `FOUNDATION_EXPORT` (extern) ile *bildirilen* sabitin TEK *tanımı* burada.
NSErrorDomain const BKISBNValidatorErrorDomain = @"BKISBNValidatorErrorDomain";

// .m dosyasında da nullability varsayılanını açıyoruz; aşağıdaki yardımcıların pointer'ları da nonnull sayılır.
NS_ASSUME_NONNULL_BEGIN

/// ISBN-13'ün toplam hane sayısı ve kontrol hanesinden önceki hane sayısı.
/// `static const`: Yalnızca bu dosyada görünen, derleme anında bilinen sabitler. `#define` yerine tercih edilir,
/// çünkü bir tipi vardır ve hata ayıklayıcıda (debugger) görünür.
static const NSUInteger BKISBN13Length = 13;
static const NSUInteger BKISBN13PayloadLength = 12;

#pragma mark - Yardımcı fonksiyonlar

/// Temizlenecek karakterler: boşluk, satır sonu ve tire.
///
/// `dispatch_once` bloğu uygulamanın ömrü boyunca yalnızca BİR kez çalışır; aynı anda birden çok thread
/// çağırsa bile. Swift'te `static let` aynı garantiyi kendiliğinden verir (tembel + atomik başlatma).
static NSCharacterSet *BKISBNSeparatorCharacterSet(void) {
    static NSCharacterSet *separators;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
        [set addCharactersInString:@"-"];
        // Değiştirilebilir (mutable) kümeyi dışarı sızdırmıyoruz; değişmez bir kopyasını saklıyoruz.
        separators = [set copy];
    });
    return separators;
}

/// "Rakam OLMAYAN" karakterler kümesi.
///
/// Dikkat: `[NSCharacterSet decimalDigitCharacterSet]` KULLANMIYORUZ. O küme yalnızca 0-9 değil,
/// Arapça-Hint rakamları ("٣") gibi tüm Unicode rakamlarını da içerir. ISBN yalnızca ASCII 0-9 kabul eder.
static NSCharacterSet *BKISBNNonDigitCharacterSet(void) {
    static NSCharacterSet *nonDigits;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nonDigits = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    });
    return nonDigits;
}

/// Metinde 0-9 dışında karakter yoksa YES döner. (Boş metin için de YES; boşluğu çağıran ayrıca denetler.)
static BOOL BKISBNContainsOnlyDigits(NSString *string) {
    // `rangeOfCharacterFromSet:` bulamazsa `location` alanı `NSNotFound` olur. ObjC'de "bulunamadı" için
    // Optional yoktur; bunun yerine bu tür özel değerler (sentinel) kullanılır.
    return [string rangeOfCharacterFromSet:BKISBNNonDigitCharacterSet()].location == NSNotFound;
}

/// İlk 12 hanenin ağırlıklı toplamından kontrol hanesini (0-9) hesaplar.
/// Ön koşul: `digits`'in ilk 12 karakteri ASCII rakamdır (çağıranlar bunu önceden denetler).
static NSInteger BKISBNComputeCheckDigit(NSString *digits) {
    NSInteger sum = 0;
    for (NSUInteger index = 0; index < BKISBN13PayloadLength; index++) {
        // `characterAtIndex:` bir `unichar` (16 bitlik UTF-16 kod birimi) döndürür. '0'...'9' kodları ardışık
        // olduğu için `karakter - '0'` rakamın sayısal değerini verir: '7' - '0' == 7.
        NSInteger digit = [digits characterAtIndex:index] - '0';
        NSInteger weight = (index % 2 == 0) ? 1 : 3;
        sum += digit * weight;
    }
    return (10 - sum % 10) % 10;
}

/// Hata nesnesini (istenmişse) doldurup `NO` döndürür. Tüm başarısızlık yolları buradan geçer.
///
/// `NSError **` neden iki yıldız? Çağıran, kendi `NSError *` değişkeninin ADRESİNİ verir:
///     NSError *error = nil;
///     if (![BKISBNValidator validateISBN13:text error:&error]) { NSLog(@"%@", error); }
/// Biz de `*error = ...` diyerek çağıranın değişkenine yazarız. Fonksiyonlar tek değer döndürebildiği için
/// ObjC "sonuç dönüş değerinde, hata çıkış parametresinde" kuralını kullanır.
///
/// `if (error != NULL)` denetimi ZORUNLU: Hata ayrıntısıyla ilgilenmeyen çağıran `error:NULL` verir
/// (bkz. `isValidISBN13:`). NULL bir adrese yazmak (`*NULL = ...`) uygulamayı EXC_BAD_ACCESS ile çökertir.
///
/// `__autoreleasing`: ARC'de `NSError **` parametreleri zaten örtük olarak böyledir; burada açıkça yazdık.
/// Anlamı: `*error`'a atanan nesne "autorelease" edilir, böylece fonksiyondan çıkınca yok olmaz ve
/// sahipliği (ownership) çağırana güvenle geçer.
static BOOL BKISBNFail(NSError * _Nullable __autoreleasing * _Nullable error,
                       BKISBNValidatorError code,
                       NSString *message) {
    if (error != NULL) {
        *error = [NSError errorWithDomain:BKISBNValidatorErrorDomain
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }
    return NO;
}

NS_ASSUME_NONNULL_END

#pragma mark - BKISBNValidator

@implementation BKISBNValidator

+ (NSString *)normalizedISBN:(NSString *)isbn {
    // Ayırıcı karakterlerden bölüp parçaları boşluksuz birleştirmek = o karakterleri silmek.
    // "978-605 000" -> @[@"978", @"605", @"000"] -> @"978605000"
    NSArray<NSString *> *parts = [isbn componentsSeparatedByCharactersInSet:BKISBNSeparatorCharacterSet()];
    return [parts componentsJoinedByString:@""];
}

+ (BOOL)isValidISBN13:(NSString *)isbn {
    // Hata ayrıntısı istemiyoruz, bu yüzden `error:` yerine NULL veriyoruz.
    // Bu güvenli, çünkü `validateISBN13:error:` yazmadan önce NULL denetimi yapıyor.
    return [self validateISBN13:isbn error:NULL];
}

+ (BOOL)validateISBN13:(NSString *)isbn error:(NSError * _Nullable * _Nullable)error {
    // Sınıf metodunda (`+`) `self`, nesne değil SINIFIN kendisidir; `[self normalizedISBN:]` bir sınıf metodu çağrısıdır.
    NSString *normalized = [self normalizedISBN:isbn];

    // 1) Boş mu? ("   " veya "---" gibi girdiler de temizlenince boş kalır.)
    if (normalized.length == 0) {
        return BKISBNFail(error, BKISBNValidatorErrorEmpty, @"ISBN boş olamaz.");
    }

    // 2) Karakterler: Uzunluktan ÖNCE denetliyoruz. Böylece aşağıdaki uzunluk mesajındaki sayı gerçekten
    //    "hane" sayısıdır. (`length` UTF-16 birimi sayar; bir emoji 2 birim tutabilir.)
    if (!BKISBNContainsOnlyDigits(normalized)) {
        return BKISBNFail(error, BKISBNValidatorErrorInvalidCharacters,
                          @"ISBN yalnızca rakam, tire ve boşluk içerebilir.");
    }

    // 3) Uzunluk. `NSUInteger`'ı `%lu` ile biçimlerken `(unsigned long)`'a çeviriyoruz; `NSUInteger`'ın boyutu
    //    platforma göre değiştiği için bu, tüm mimarilerde doğru ve uyarısız biçimlemenin standart yoludur.
    if (normalized.length != BKISBN13Length) {
        NSString *message = [NSString stringWithFormat:@"ISBN-13 tam 13 haneden oluşmalı (girilen: %lu hane).",
                             (unsigned long)normalized.length];
        return BKISBNFail(error, BKISBNValidatorErrorInvalidLength, message);
    }

    // 4) Kontrol hanesi: Hesaplanan ile son hane aynı mı?
    NSInteger expectedCheckDigit = BKISBNComputeCheckDigit(normalized);
    NSInteger actualCheckDigit = [normalized characterAtIndex:BKISBN13PayloadLength] - '0';
    if (expectedCheckDigit != actualCheckDigit) {
        return BKISBNFail(error, BKISBNValidatorErrorChecksumMismatch, @"Kontrol hanesi (son hane) hatalı.");
    }

    return YES;
}

+ (nullable NSString *)checkDigitForFirst12Digits:(NSString *)digits {
    // Sözleşme: tam olarak 12 ASCII rakam. Değilse Swift'e `nil` (Optional'ın `.none`'ı) olarak gider.
    if (digits.length != BKISBN13PayloadLength || !BKISBNContainsOnlyDigits(digits)) {
        return nil;
    }
    // `NSInteger` -> `%ld` + `(long)` dönüşümü: `NSUInteger` için yukarıda anlatılan kuralın işaretli hali.
    return [NSString stringWithFormat:@"%ld", (long)BKISBNComputeCheckDigit(digits)];
}

@end
