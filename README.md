# Advanced Swift Practice — Kitaplık (BookShelf)

> **EN:** A small iOS app built as hands-on practice for advanced Swift/iOS topics: Swift 6 strict concurrency
> (async/await, actors, task groups, `Sendable`), SwiftUI and UIKit side by side, Objective-C interop,
> XCTest + XCUITest, and a GitHub Actions CI pipeline. Code comments and lessons are in Turkish.

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

## Uygulama

| Sekme | Teknoloji | Konular |
|---|---|---|
| Kitaplar | SwiftUI | `@Observable` MVVM, async/await, `async let`, `.task` ve iptal |
| Favoriler | UIKit (SwiftUI içinde) | `UIViewController` yaşam döngüsü, diffable data source, `AsyncStream`, interop |
| Laboratuvar | SwiftUI | `TaskGroup`, data race vs actor, actor reentrancy, cooperative cancellation |
| Temeller | SwiftUI + Objective-C | struct vs class, ARC, protocol'ler, ObjC köprüsü (`NS_SWIFT_NAME`, `NSError**` → `throws`) |

## Dersler (`docs/`)

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
[11 CI](docs/11-ci.md)
