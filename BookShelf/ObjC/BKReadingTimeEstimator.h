//
//  BKReadingTimeEstimator.h
//  BookShelf
//
//  Bir kitabın sayfa sayısından tahmini okuma süresini hesaplayan küçük bir Objective-C sınıfı.
//
//  Swift'te nasıl görünür?
//      let estimator = ReadingTimeEstimator(pagesPerHour: 40)
//      estimator.pagesPerHour                               -> Double
//      estimator.estimatedSeconds(forPageCount: 320)        -> TimeInterval (Double)
//      estimator.formattedEstimate(forPageCount: 320)       -> String, ör. "8 sa"
//
//  İki yönlü köprü örneği: Bu sınıf Objective-C'de yazıldı ve Swift'ten kullanılıyor; ama varsayılan hızı
//  Swift'te yazılmış `ReadingPace` (ObjC adı `BKReadingPace`) sınıfından okuyor. Bunun için .m dosyası
//  Xcode'un ürettiği "BookShelf-Swift.h"yi import ediyor. Bu header'da (.h) ise o import'u YAPMIYORUZ:
//  Bu header köprü başlığına (bridging header) dahil; Swift derlenmeden önce okunuyor, "BookShelf-Swift.h" ise
//  Swift derlendikten SONRA üretiliyor. Header'dan import etmek bir döngü (cycle) yaratırdı.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// `NS_SWIFT_SENDABLE`: Bu sınıf değişmez (immutable) olduğu için Swift'e "thread'ler arasında güvenle
/// taşınabilir" (`Sendable`) diye bildiriyoruz. Bu bir SÖZ'dür; derleyici ObjC kodunu denetleyemez.
/// (Swift bu sınıfı `@unchecked Sendable` olarak içe aktarır.)
///
/// Biçimlendirme kuralları (`formattedEstimateForPageCount:`):
///   - Süre en yakın dakikaya yuvarlanır (29 sn -> 0 dk, 30 sn -> 1 dk).
///   - Sayfa sayısı <= 0                  -> "0 dk"
///   - Yuvarlanınca 0 dk (ama sayfa > 0)  -> "1 dk'dan az"
///   - 60 dakikadan az                    -> "45 dk"
///   - Tam saat                           -> "8 sa"
///   - Diğer                              -> "5 sa 30 dk"
///   - Gün birimi yoktur: 125 saat -> "125 sa".
/// Metin cihazın dil/bölge (locale) ayarlarından bağımsızdır; her cihazda aynı sonucu verir (testler için önemli).
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(ReadingTimeEstimator)
@interface BKReadingTimeEstimator : NSObject

/// Saatte okunan sayfa sayısı. `readonly`: dışarıdan değiştirilemez.
/// Her zaman pozitif ve sonludur (başlatıcı geçersiz değerleri varsayılanla değiştirir).
@property (nonatomic, readonly) double pagesPerHour;

/// Belirlenmiş (designated) başlatıcı. Swift'te `ReadingTimeEstimator(pagesPerHour: 40)` olur.
/// `pagesPerHour` <= 0 (ya da NaN / sonsuz) verilirse varsayılan 40 kullanılır.
/// Varsayılan değer Swift'teki `ReadingPace.defaultPagesPerHour`'dan gelir.
- (instancetype)initWithPagesPerHour:(double)pagesPerHour NS_DESIGNATED_INITIALIZER;

/// NSObject'ten gelen parametresiz `init`'i kapatıyoruz; herkes hızı açıkça vermek zorunda.
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// Tahmini okuma süresi (saniye). `NSTimeInterval` Swift'te `TimeInterval` (= Double) olur.
/// Formül: sayfa / saatte sayfa × 3600. Sayfa sayısı <= 0 ise 0 döner.
- (NSTimeInterval)estimatedSecondsForPageCount:(NSInteger)pageCount NS_SWIFT_NAME(estimatedSeconds(forPageCount:));

/// İnsan dostu metin, ör. "5 sa 30 dk" veya "45 dk". Kurallar için sınıf açıklamasına bak.
- (NSString *)formattedEstimateForPageCount:(NSInteger)pageCount NS_SWIFT_NAME(formattedEstimate(forPageCount:));

@end

NS_ASSUME_NONNULL_END
