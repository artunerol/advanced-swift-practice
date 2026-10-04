import SwiftUI

/// UIKit sızıntı laboratuvarını mülakat konusunun "Demo" bölümüne yerleştiren köprü.
///
/// Bir `UINavigationController` ile sarmalamıyoruz: Konu ekranı zaten SwiftUI `NavigationStack` içinde ve
/// laboratuvar push değil modal (`present`) kullanıyor. Modal sunum için navigasyon yığını gerekmez.
struct MemoryLeakLabView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MemoryLeakLabViewController {
        MemoryLeakLabViewController()
    }

    func updateUIViewController(_ viewController: MemoryLeakLabViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        MemoryLeakLabView()
            .navigationTitle("Sızıntı laboratuvarı")
            .navigationBarTitleDisplayMode(.inline)
    }
}
