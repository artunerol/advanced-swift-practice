import SwiftUI
import UIKit

/// Uygulamanın giriş noktası.
///
/// `@main` derleyiciye "program buradan başlar" der. `App` protokolü SwiftUI yaşam döngüsünü kullanır;
/// eski usul `AppDelegate` / `SceneDelegate` yazmamız gerekmez.
@main
struct BookShelfApp: App {
    /// Bağımlılıkları uygulama başlarken BİR kez oluşturup tüm ekranlara aynı örneği veriyoruz.
    /// Böylece favoriler actor'ü (`FavoritesStore`) hem SwiftUI hem UIKit ekranında ortak olur.
    private let dependencies: AppDependencies

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        dependencies = AppDependencies.makeForLaunch(arguments: arguments)

        // UI testlerinde animasyonları kapatmak testleri hem hızlandırır hem de kararlı hale getirir.
        if arguments.contains(LaunchArgument.uiTesting) {
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
        }
    }
}
