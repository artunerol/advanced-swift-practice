import SwiftUI
import UIKit

/// VIPER modülünü (UIKit) SwiftUI demosuna yerleştiren köprü.
///
/// Dışarıdan bakınca VIPER'ın beş parçası görünmez: sadece `NotesListRouter.build(repository:)` çağrılır ve bir
/// `UIViewController` gelir. Modülün tek dış sahibi bu köprüdür (SwiftUI, VC'yi view ağaçta kaldıkça saklar).
///
/// Depo değişince ne olur? Demo bu view'a `.id(...)` ile yeni bir kimlik verir; SwiftUI eskisini atar (modülün
/// tamamı serbest kalır) ve `makeUIViewController` yeni depoyla yeniden çağrılır. Modülün kodu hiç değişmez.
struct NotesListVIPERContainer: UIViewControllerRepresentable {
    let repository: any NotesRepository

    func makeUIViewController(context: Context) -> UIViewController {
        NotesListRouter.build(repository: repository)
    }

    /// Girdimiz (`repository`) yalnızca kimlik değişince değişiyor; o durumda zaten yeni bir VC kuruluyor.
    func updateUIViewController(_ viewController: UIViewController, context: Context) {}
}
