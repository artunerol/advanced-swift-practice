//
//  BookShelf-Bridging-Header.h
//
//  KÖPRÜ BAŞLIĞI (Bridging Header): Objective-C -> Swift yönü.
//
//  Buraya #import edilen her Objective-C header'ı, uygulama hedefindeki TÜM Swift dosyalarında
//  ayrıca `import` yazmadan kullanılabilir hale gelir.
//  Hangi dosyanın köprü başlığı olduğu Build Settings > "Objective-C Bridging Header"
//  (SWIFT_OBJC_BRIDGING_HEADER) ayarında belirtilir.
//
//  Ters yön (Swift -> Objective-C) için Xcode otomatik olarak "BookShelf-Swift.h" üretir;
//  bir .m dosyasında `#import "BookShelf-Swift.h"` yazarak @objc işaretli Swift tiplerini kullanabilirsin.
//

#import "BKISBNValidator.h"
#import "BKReadingTimeEstimator.h"
