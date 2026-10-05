import SwiftUI
import UIKit

/// Kitap Arama VIPER modülünü (UIKit) "VIPER'da servis çağrısı" konusunun Demo bölümüne yerleştiren köprü.
///
/// ```
/// SwiftUI NavigationStack (Mülakat sekmesi)  ← görünen TEK navigasyon çubuğu: konu başlığı + ✓
///   └─ InterviewTopicScreen → Demo
///        └─ BookSearchVIPERContainer (UIViewControllerRepresentable)
///             └─ UINavigationController (çubuğu GİZLİ, push için yığın)
///                  ├─ BookSearchViewController           (VIPER modülünün kökü)
///                  └─ UIHostingController(BookDetailView)   ← router'ın push'u; altta "Sonuçlara dön"
/// ```
///
/// Neden `UINavigationController`? Router gerçek bir push yapıyor ve push için bir yığın şart: sarmasaydık
/// `viewController.navigationController` `nil` olurdu ve `showBookDetail` hiçbir şey yapmazdı.
///
/// Neden çubuğu gizli? Konu ekranının SwiftUI çubuğu zaten üstte. UIKit çubuğunu da göstersek alt alta iki navigasyon
/// çubuğu olurdu (UIKit lab'larıyla aynı karar, bkz. `UIKitLabHost`). Bedeli: sistemin geri düğmesi ve kenardan kaydırarak
/// geri dönme yok. Bunun yerine detay ekranı, yığının **alt araç çubuğunda** (toolbar) "Sonuçlara dön" düğmesi taşır
/// (router `toolbarItems` ile verir). Araç çubuğunu ekran ekran açıp kapatan, aşağıdaki `Coordinator`.
///
/// Gözlem (iOS 26.2 simülatörü, ekran görüntüsüyle): Detay açıkken üstteki SwiftUI çubuğunun başlığı kitabın adına döner.
/// `BookDetailView`'ın `.navigationTitle`'ı, araya giren UIKit yığınına rağmen en yakın görünen SwiftUI çubuğuna yansıyor;
/// "Sonuçlara dön" ile geri gelince konu başlığı geri gelir. Böylece ikinci bir çubuk olmadan "neredeyim?" sorusu cevaplanıyor.
///
/// Composition: Ayar (`BookSearchConfiguration.forLaunch`) ve son aramaların deposu burada seçilir. `ProcessInfo`'yu
/// interactor değil, bu en dış katman okur.
struct BookSearchVIPERContainer: UIViewControllerRepresentable {
    let dependencies: AppDependencies

    func makeUIViewController(context: Context) -> UINavigationController {
        let arguments = ProcessInfo.processInfo.arguments
        let root = BookSearchRouter.build(
            dependencies: dependencies,
            // `PersistenceLocation.current`: normalde `.standard`, `-ui-testing` ile her açılışta sıfırlanan ayrı bir alan.
            recentSearchesStore: UserDefaultsRecentSearchesStore(suiteName: PersistenceLocation.current.defaultsSuiteName),
            configuration: .forLaunch(arguments: arguments)
        )
        let navigationController = UINavigationController(rootViewController: root)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.delegate = context.coordinator
        return navigationController
    }

    func updateUIViewController(_ navigationController: UINavigationController, context: Context) {}

    /// SwiftUI, coordinator'ı representable yaşadığı sürece saklar. `UINavigationController.delegate` `weak` olduğu için
    /// delegate'i birinin strong tutması gerekir; coordinator tam bu iş için uygun yer.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Yığına bir ekran gelirken alt araç çubuğunu o ekrana göre açar/kapatır: `toolbarItems`'ı olan (detay) ekranda
    /// görünür, olmayan (arama) ekranında gizlenir. Router'ın "ne gösterilecek", container'ın "çerçeve nasıl" kararı ayrı kalır.
    @MainActor
    final class Coordinator: NSObject, UINavigationControllerDelegate {
        func navigationController(
            _ navigationController: UINavigationController,
            willShow viewController: UIViewController,
            animated: Bool
        ) {
            let hasToolbarItems = !(viewController.toolbarItems ?? []).isEmpty
            navigationController.setToolbarHidden(!hasToolbarItems, animated: animated)
        }
    }
}

#Preview {
    NavigationStack {
        BookSearchVIPERContainer(dependencies: .preview)
            .navigationTitle("Kitap Arama")
            .navigationBarTitleDisplayMode(.inline)
    }
}
