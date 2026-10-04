import SwiftUI

/// Uygulamanın ana iskeleti: 4 sekme.
///
/// | Sekme        | Teknoloji                        | Öğrettiği konu                                  |
/// |--------------|----------------------------------|-------------------------------------------------|
/// | Kitaplar     | SwiftUI                          | async/await, `@Observable`, `async let`, actor  |
/// | Favoriler    | UIKit (SwiftUI içine gömülü)     | UIViewController, diffable data source, interop |
/// | Laboratuvar  | SwiftUI                          | Task, TaskGroup, actor vs data race, iptal      |
/// | Temeller     | SwiftUI + Objective-C            | struct vs class, protocol'ler, ObjC köprüsü     |
struct RootTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            BookListView(dependencies: dependencies)
                .tabItem { Label(AccessibilityID.Tab.books, systemImage: "books.vertical") }

            FavoritesView(dependencies: dependencies)
                .tabItem { Label(AccessibilityID.Tab.favorites, systemImage: "heart") }

            ConcurrencyLabView()
                .tabItem { Label(AccessibilityID.Tab.lab, systemImage: "flask") }

            FundamentalsView()
                .tabItem { Label(AccessibilityID.Tab.fundamentals, systemImage: "square.stack.3d.up") }
        }
    }
}

#Preview {
    RootTabView(dependencies: .preview)
}
