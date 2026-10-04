import SwiftUI
import UIKit

/// SwiftUI → UIKit köprüsü: UIKit laboratuvarlarının view controller'larını konu ekranının "Demo" bölümüne gömer.
///
/// Dört lab'ın köprüsü birebir aynı olduğu için tek bir generic tip yeterli: VC'yi `makeUIViewController`'da
/// **bir kez** oluştur, sonra dokunma (`update` boş; lab'lar SwiftUI'dan sonradan veri almıyor).
///
/// Neden `UINavigationController` ile SARMIYORUZ? Konu ekranı zaten SwiftUI `NavigationStack` içinde ve kendi
/// navigasyon çubuğu var. Sarsaydık ekranda alt alta iki çubuk olurdu. (Favoriler sekmesi ise sarıyor, çünkü orada
/// SwiftUI tarafında bir yığın yok; bkz. `FavoritesView`.) Push gösteren yaşam döngüsü lab'ı, kendi
/// `UINavigationController`'ını çubuğu gizlenmiş bir child VC olarak kullanır.
///
/// `UIViewControllerRepresentable` bir `@MainActor` protokolü; bu struct ve kapanış da ana actor'de çalışır.
struct UIKitLabHost<Controller: UIViewController>: UIViewControllerRepresentable {
    let makeController: @MainActor () -> Controller

    init(_ makeController: @escaping @MainActor () -> Controller) {
        self.makeController = makeController
    }

    func makeUIViewController(context: Context) -> Controller {
        makeController()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}
}

/// Kitap kullanan lab'lar (dinamik hücreler, table vs collection) için küçük bir yükleyici.
///
/// View controller'lar servisi değil, `[Book]` dizisini `init` ile alır. Böylece birim testlerinde `Book.fixtures`
/// vermek yeterli; ağ, bekleme ya da sahte servis gerekmez. Servisle konuşmak bu ince SwiftUI katmanının işi.
struct UIKitLabBooksLoader<Content: View>: View {
    private enum Phase {
        case loading
        case loaded([Book])
        case failed(String)
    }

    let bookService: any BookServiceProtocol
    @ViewBuilder let content: ([Book]) -> Content

    @State private var phase: Phase = .loading

    var body: some View {
        switch phase {
        case .loading:
            ProgressView("Kitaplar yükleniyor…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await load() }
        case .loaded(let books):
            content(books)
        case .failed(let message):
            ContentUnavailableView(
                "Kitaplar yüklenemedi",
                systemImage: "wifi.slash",
                description: Text(message)
            )
        }
    }

    private func load() async {
        do {
            phase = .loaded(try await bookService.fetchBooks())
        } catch is CancellationError {
            // Kullanıcı yükleme bitmeden başka bölüme geçti; hata göstermeye gerek yok.
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
