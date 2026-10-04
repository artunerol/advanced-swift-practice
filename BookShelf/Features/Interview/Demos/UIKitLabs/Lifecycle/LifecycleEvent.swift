import Foundation

/// UIKit'in bir view controller'a "hayatının şu anındasın" diye haber verdiği çağrılar.
///
/// Günlükteki metin (`title`) bilerek metot adının kendisi: Ekranda "viewDidLayoutSubviews" görünce
/// koddaki override'ı doğrudan bulabilesin.
enum LifecycleEvent: Equatable, Sendable {
    case initialized
    case loadView
    case viewDidLoad
    case viewWillAppear
    case viewIsAppearing
    case viewWillLayoutSubviews
    case viewDidLayoutSubviews
    case viewDidAppear
    case viewWillDisappear
    case viewDidDisappear
    /// Child VC (containment) bildirimleri. Parametre: yeni üst VC'nin adı, çıkarılırken `nil`.
    case willMoveToParent(String?)
    case didMoveToParent(String?)
    /// Döndürme / pencere boyutu değişimi. Yeni boyut tam sayıya yuvarlanır.
    case viewWillTransition(width: Int, height: Int)
    /// iOS 17+ `registerForTraitChanges` ile yakalanan trait değişimi (ör. açık/koyu mod).
    case traitsChanged(String)
    case deinitialized

    var title: String {
        switch self {
        case .initialized: "init"
        case .loadView: "loadView"
        case .viewDidLoad: "viewDidLoad"
        case .viewWillAppear: "viewWillAppear"
        case .viewIsAppearing: "viewIsAppearing"
        case .viewWillLayoutSubviews: "viewWillLayoutSubviews"
        case .viewDidLayoutSubviews: "viewDidLayoutSubviews"
        case .viewDidAppear: "viewDidAppear"
        case .viewWillDisappear: "viewWillDisappear"
        case .viewDidDisappear: "viewDidDisappear"
        case .willMoveToParent(let parent): "willMove(toParent: \(parent ?? "nil"))"
        case .didMoveToParent(let parent): "didMove(toParent: \(parent ?? "nil"))"
        case .viewWillTransition(let width, let height): "viewWillTransition(to: \(width)×\(height))"
        case .traitsChanged(let description): "trait değişti: \(description)"
        case .deinitialized: "deinit"
        }
    }

    /// Yerleşim (layout) çağrısı mı? Bunlar sayısı belirsiz biçimde tekrar eder; testler ve özetler ayırt edebilsin diye.
    var isLayout: Bool {
        self == .viewWillLayoutSubviews || self == .viewDidLayoutSubviews
    }
}
