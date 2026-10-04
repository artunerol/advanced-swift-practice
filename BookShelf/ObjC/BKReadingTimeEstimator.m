//
//  BKReadingTimeEstimator.m
//  BookShelf
//
//  BKReadingTimeEstimator'ın uygulaması. Swift -> Objective-C yönünü de burada görüyoruz.
//

#import "BKReadingTimeEstimator.h"

// Xcode'un Swift kodundan OTOMATİK ürettiği header. Adı "<ModülAdı>-Swift.h" (Build Settings'teki
// SWIFT_OBJC_INTERFACE_HEADER_NAME). İçinde `@objc` ile işaretlenmiş Swift tiplerinin ObjC bildirimleri var;
// örneğin `ReadingPace` sınıfı burada `@interface BKReadingPace : NSObject` olarak görünür.
//
// Kurallar:
// - YALNIZCA .m dosyalarında import edilir. Bir .h'de gerekirse `@class BKReadingPace;` ile ileri bildirim
//   (forward declaration) yapılır. (Neden? bkz. BKReadingTimeEstimator.h'nin başındaki açıklama.)
// - Uygulama hedefinde bir köprü başlığı olduğu için `internal` Swift bildirimleri de bu header'a girer;
//   `private`/`fileprivate` olanlar girmez.
#import "BookShelf-Swift.h"

@implementation BKReadingTimeEstimator

- (instancetype)initWithPagesPerHour:(double)pagesPerHour {
    // Klasik ObjC başlatıcı kalıbı: önce üst sınıfın init'i; nil dönebileceği için sonucu `self`'e atayıp denetliyoruz.
    self = [super init];
    if (self) {
        // Swift'te yazılmış sınıfın sınıf metodunu ObjC'den çağırıyoruz. Geçersiz hız (<= 0, NaN, sonsuz)
        // gelirse `BKReadingPace.defaultPagesPerHour` (40) kullanılır; kural tek yerde, Swift tarafında duruyor.
        //
        // `_pagesPerHour`: `readonly` property'nin arka plandaki değişkeni (backing ivar). Derleyici `@property`
        // için otomatik olarak `_` önekli bir ivar üretir. init içinde setter yerine ivar'a doğrudan yazmak ObjC
        // geleneğidir (hem `readonly` olduğu için setter yok, hem de yarım kurulmuş nesnede setter çağırmak risklidir).
        _pagesPerHour = [BKReadingPace resolvedPagesPerHour:pagesPerHour];
    }
    return self;
}

- (NSTimeInterval)estimatedSecondsForPageCount:(NSInteger)pageCount {
    if (pageCount <= 0) {
        return 0;
    }
    // `(double)` dönüşümü önemli: iki tamsayıyı bölseydik C'de sonuç tamsayı olur ve küsurat kaybolurdu.
    return (double)pageCount / self.pagesPerHour * 3600.0;
}

- (NSString *)formattedEstimateForPageCount:(NSInteger)pageCount {
    if (pageCount <= 0) {
        return @"0 dk";
    }

    // En yakın dakikaya yuvarla. `round` yarımları sıfırdan uzağa yuvarlar: 29,5 dk -> 30 dk.
    // Hesabı `double` ile yapıyoruz; çok büyük sayfa sayılarında bile tamsayı taşması (overflow) olmaz.
    double totalMinutes = round([self estimatedSecondsForPageCount:pageCount] / 60.0);
    if (totalMinutes < 1) {
        return @"1 dk'dan az";
    }

    double hours = floor(totalMinutes / 60.0);
    double minutes = totalMinutes - hours * 60.0;

    // `stringWithFormat:` cihazın bölge ayarlarını KULLANMAZ (onu yapan `localizedStringWithFormat:`'tır).
    // `%.0f` ondalık kısmı olmayan bir sayı yazar; sonuç her cihazda aynıdır. (NSDateComponentsFormatter
    // gibi locale'e bağlı biçimleyiciler dile göre "8 saat" / "8 hr" gibi farklı metinler üretebilirdi.)
    if (hours == 0) {
        return [NSString stringWithFormat:@"%.0f dk", minutes];
    }
    if (minutes == 0) {
        return [NSString stringWithFormat:@"%.0f sa", hours];
    }
    return [NSString stringWithFormat:@"%.0f sa %.0f dk", hours, minutes];
}

@end
