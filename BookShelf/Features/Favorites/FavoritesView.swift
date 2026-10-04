import SwiftUI
import UIKit

/// SwiftUI → UIKit köprüsü: UIKit ile yazılmış Favoriler ekranını SwiftUI'ın `TabView`'ına yerleştirir.
///
/// Bu projede iki yönlü bir "sandviç" var:
/// ```
/// SwiftUI TabView
///   └─ FavoritesView (UIViewControllerRepresentable)          ← SwiftUI, UIKit'i barındırıyor
///        └─ UINavigationController
///             ├─ FavoritesViewController (UITableView)
///             └─ UIHostingController(rootView: BookDetailView) ← UIKit, SwiftUI'ı barındırıyor
/// ```
/// - **SwiftUI içinde UIKit:** `UIViewControllerRepresentable` (bir view controller için) veya
///   `UIViewRepresentable` (tek bir `UIView` için, ör. `MKMapView`, `WKWebView`).
/// - **UIKit içinde SwiftUI:** `UIHostingController(rootView:)`. Bu, SwiftUI view'ını içeren sıradan bir
///   `UIViewController`'dır; push edilebilir, modal açılabilir, child VC olarak eklenebilir.
///   (Bkz. `FavoritesViewController.tableView(_:didSelectRowAt:)`.)
///
/// Yaşam döngüsü: SwiftUI bu küçük struct'ı istediği kadar yeniden oluşturabilir (her `body` hesaplamasında).
/// Bu ucuzdur. Ama asıl UIKit nesnesi `makeUIViewController` ile yalnızca **bir kez** oluşturulur ve SwiftUI onu,
/// view ağaçtaki kimliğini (identity) koruduğu sürece saklar. Sonraki her güncellemede sadece
/// `updateUIViewController` çağrılır.
///
/// `UIViewControllerRepresentable` bir `@MainActor` protokolüdür; bu yüzden bu struct da (ve metotları) ana actor'e bağlıdır.
struct FavoritesView : UIViewControllerRepresentable {
    let dependencies: AppDependencies

    /// UIKit nesnesini oluşturur. SwiftUI bunu view'ın ömrü boyunca **bir kez** çağırır.
    ///
    /// Neden `UINavigationController` ile sarıyoruz?
    /// SwiftUI'ın `TabView`'ı bir UIKit view controller'ına navigasyon yığını (stack) sağlamaz. Sarmalamasaydık
    /// `FavoritesViewController.navigationController` `nil` olurdu; yani ne navigasyon çubuğu (büyük başlık,
    /// "Tümünü temizle" düğmesi) olurdu ne de detay ekranını `pushViewController` ile açabilirdik.
    /// SwiftUI tarafındaki `NavigationStack`'in UIKit'teki karşılığı `UINavigationController`'dır.
    func makeUIViewController(context: Context) -> UINavigationController {
        let favoritesViewController = FavoritesViewController(dependencies: dependencies)
        let navigationController = UINavigationController(rootViewController: favoritesViewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    /// SwiftUI tarafındaki girdiler (bu struct'ın alanları, `@State`, `@Environment` vb.) değiştiğinde çağrılır.
    /// Görevi, yeni değerleri **mevcut** UIKit nesnesine aktarmaktır; burada yeni nesne oluşturulmaz.
    ///
    /// Bizim tek girdimiz `dependencies` ve uygulama boyunca değişmiyor; favori değişiklikleri SwiftUI state'i
    /// üzerinden değil, `FavoritesStore` actor'ünün `AsyncStream`'i üzerinden akıyor. Bu yüzden yapılacak iş yok.
    func updateUIViewController(_ navigationController: UINavigationController, context: Context) {}

    // Coordinator: UIKit'in delegate/target-action olaylarını SwiftUI'a (ör. bir `@Binding`'e) geri taşımak
    // gerektiğinde `makeCoordinator()` ile bir yardımcı nesne üretilir ve `context.coordinator` ile erişilir.
    // Burada UIKit'ten SwiftUI'a veri akışı olmadığı için tanımlamadık; varsayılan Coordinator tipi `Void`'dir.
}

#Preview("Birkaç favori") {
    FavoritesView(dependencies: AppDependencies(
        bookService: LocalBookService(latency: .milliseconds(300)),
        favorites: FavoritesStore(initialFavorites: [1, 3, 8])
    ))
}

#Preview("Boş liste") {
    FavoritesView(dependencies: .preview)
}
