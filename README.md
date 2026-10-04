# Advanced Swift Practice — Kitaplık (BookShelf)

> **EN:** A small iOS app built as hands-on practice for advanced Swift/iOS topics: Swift 6 strict concurrency
> (async/await, actors, task groups, `Sendable`), SwiftUI and UIKit side by side, Clean Architecture with VIPER and
> MVVM, five persistence options behind one protocol, Objective-C interop, XCTest + XCUITest, and a GitHub Actions
> CI pipeline. An in-app hub turns 16 common iOS interview questions into short answers, live demos and code pointers.
> Code comments and lessons are in Turkish.

Küçük ama "gerçek" bir iOS uygulaması üzerinden ileri seviye Swift/iOS konularını pratik etmek için hazırlandı.
Her dosya öğretici olacak şekilde yazıldı: yorumlar **neden** sorusunu cevaplar, `docs/` klasöründeki dersler
kavramları sıfırdan anlatıp koddaki yerlerini gösterir.

## Hızlı başlangıç

```bash
open BookShelf.xcodeproj
```

```bash
make test
```

- Gereksinim: Xcode 16+ (geliştirme Xcode 26 ile yapıldı), iOS 17+ simülatör.
- `make help` tüm komutları listeler; CI ile aynı adımları `scripts/ci.sh` çalıştırır.
- Nereden başlamalı? Mülakat sorularına çalışıyorsan [00 Mülakat rehberi](docs/00-mulakat-rehberi.md), projenin
  nasıl kurulduğunu merak ediyorsan [01 Proje yapısı](docs/01-proje-yapisi.md).

## Uygulama

| Sekme | Teknoloji | Konular |
|---|---|---|
| Kitaplar | SwiftUI | `@Observable` MVVM, async/await, `async let`, `.task` ve iptal |
| Favoriler | UIKit (SwiftUI içinde) | `UIViewController` yaşam döngüsü, diffable data source, `AsyncStream`, interop |
| Laboratuvar | SwiftUI | `TaskGroup`, data race vs actor, actor reentrancy, cooperative cancellation |
| Mülakat | SwiftUI + UIKit + Objective-C | 16 soru; her biri **Cevap** (30 saniyelik cevap, ek sorular, tuzaklar), **Demo** (canlı örnek) ve **Kod** (bakılacak dosyalar) |

## Dersler (`docs/`)

[00 Mülakat rehberi](docs/00-mulakat-rehberi.md) ·
[01 Proje yapısı](docs/01-proje-yapisi.md) ·
[02 Struct vs Class](docs/02-struct-vs-class.md) ·
[03 Protocol'ler](docs/03-protocoller.md) ·
[04 SwiftUI](docs/04-swiftui.md) ·
[05 async/await](docs/05-async-await.md) ·
[06 Concurrency & Actor](docs/06-concurrency-ve-actor.md) ·
[07 UIKit](docs/07-uikit.md) ·
[08 Objective-C](docs/08-objective-c.md) ·
[09 XCTest](docs/09-xctest.md) ·
[10 XCUITest](docs/10-xcuitest.md) ·
[11 CI/CD](docs/11-ci.md) ·
[12 ARC ve Delegate](docs/12-arc-ve-delegate.md) ·
[13 Mimari](docs/13-mimari.md) ·
[14 Kalıcılık](docs/14-kalicilik.md)

## Mülakat konuları

Her soru [Mülakat rehberi](docs/00-mulakat-rehberi.md)'nde aynı düzenle işlenir: 30 saniyelik cevap, ek sorular,
tuzaklar, koda bakılacak yerler ve uygulamadaki demo. Uygulama içindeki metin `BookShelf/Features/Interview/Topics/`
altında, her soru kendi dosyasında; demolar `BookShelf/Features/Interview/Demos/` altında.

| Soru (rehberdeki bölüm) | Konu dosyası | Ders |
|---|---|---|
| [1. Protocol + extension](docs/00-mulakat-rehberi.md#soru-01) | [Topic+ProtocolExtension.swift](BookShelf/Features/Interview/Topics/Topic+ProtocolExtension.swift) | [03](docs/03-protocoller.md) |
| [2. Protocol tip olarak: derlenir mi?](docs/00-mulakat-rehberi.md#soru-02) | [Topic+ProtocolAsType.swift](BookShelf/Features/Interview/Topics/Topic+ProtocolAsType.swift) | [03](docs/03-protocoller.md) |
| [3. Struct vs class, stack vs heap](docs/00-mulakat-rehberi.md#soru-03) | [Topic+StructVsClass.swift](BookShelf/Features/Interview/Topics/Topic+StructVsClass.swift) | [02](docs/02-struct-vs-class.md) |
| [4. UIViewController yaşam döngüsü](docs/00-mulakat-rehberi.md#soru-04) | [Topic+VcLifecycle.swift](BookShelf/Features/Interview/Topics/Topic+VcLifecycle.swift) | [07](docs/07-uikit.md) |
| [5. Dinamik (self-sizing) hücre](docs/00-mulakat-rehberi.md#soru-05) | [Topic+DynamicCells.swift](BookShelf/Features/Interview/Topics/Topic+DynamicCells.swift) | [07](docs/07-uikit.md) |
| [6. frame vs bounds](docs/00-mulakat-rehberi.md#soru-06) | [Topic+FrameVsBounds.swift](BookShelf/Features/Interview/Topics/Topic+FrameVsBounds.swift) | [07](docs/07-uikit.md) |
| [7. UITableView vs UICollectionView](docs/00-mulakat-rehberi.md#soru-07) | [Topic+TableVsCollection.swift](BookShelf/Features/Interview/Topics/Topic+TableVsCollection.swift) | [07](docs/07-uikit.md) |
| [8. typealias](docs/00-mulakat-rehberi.md#soru-08) | [Topic+Typealias.swift](BookShelf/Features/Interview/Topics/Topic+Typealias.swift) | [03](docs/03-protocoller.md) |
| [9. CI/CD](docs/00-mulakat-rehberi.md#soru-09) | [Topic+Cicd.swift](BookShelf/Features/Interview/Topics/Topic+Cicd.swift) | [11](docs/11-ci.md) |
| [10. Clean Architecture, VIPER, MVVM](docs/00-mulakat-rehberi.md#soru-10) | [Topic+Architecture.swift](BookShelf/Features/Interview/Topics/Topic+Architecture.swift) | [13](docs/13-mimari.md) |
| [11. Dependency Inversion vs Injection](docs/00-mulakat-rehberi.md#soru-11) | [Topic+DipVsDi.swift](BookShelf/Features/Interview/Topics/Topic+DipVsDi.swift) | [13](docs/13-mimari.md) |
| [12. Kalıcılık (UserDefaults, Keychain, Core Data...)](docs/00-mulakat-rehberi.md#soru-12) | [Topic+Persistence.swift](BookShelf/Features/Interview/Topics/Topic+Persistence.swift) | [14](docs/14-kalicilik.md) |
| [13. ARC ve retain cycle](docs/00-mulakat-rehberi.md#soru-13) | [Topic+ArcRetainCycle.swift](BookShelf/Features/Interview/Topics/Topic+ArcRetainCycle.swift) | [12](docs/12-arc-ve-delegate.md) |
| [14. Delegate: kim kimi tutar?](docs/00-mulakat-rehberi.md#soru-14) | [Topic+Delegate.swift](BookShelf/Features/Interview/Topics/Topic+Delegate.swift) | [12](docs/12-arc-ve-delegate.md) |
| [Bonus: Swift Concurrency](docs/00-mulakat-rehberi.md#bonus-concurrency) | [Topic+Concurrency.swift](BookShelf/Features/Interview/Topics/Topic+Concurrency.swift) | [05](docs/05-async-await.md), [06](docs/06-concurrency-ve-actor.md) |
| [Bonus: Objective-C interop](docs/00-mulakat-rehberi.md#bonus-objc) | [Topic+ObjcInterop.swift](BookShelf/Features/Interview/Topics/Topic+ObjcInterop.swift) | [08](docs/08-objective-c.md) |

Uygulamadaki sıra bölümlere göredir (Swift, UIKit, Mimari, Veri, Süreç, Bonus); rehberdeki numaralar bir çalışma
sırasıdır. İçerikler aynıdır.
