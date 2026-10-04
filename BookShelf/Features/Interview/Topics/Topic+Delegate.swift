import SwiftUI

// Sahibi: memory-delegate. Demo: Demos/Delegation/ (UIKit kontrol + sahiplik şeması). Ders: docs/12-arc-ve-delegate.md
extension InterviewTopic {
    static let delegate = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.delegate,
        section: .uikit,
        question: "Delegate pattern'de kim delegate olur, kim weak tutar? Bunu neye göre seçeriz?",
        shortAnswer: [
            "Delegate'te kalıtım (superclass) yoktur: Bir nesne olaylarını ve sorularını bir protokol üzerinden başka bir nesneye devreder. Bu kompozisyondur.",
            "Kimin delegate olacağını sahiplik ve ömür belirler: Sahip olan, daha uzun yaşayan taraf (VC, parent, presenter) delegate olur. Sahip olunan, daha kısa yaşayan nesne (kontrol, table view, child, interactor) protokolü tanımlar ve delegate'i weak tutar.",
            "Sahip aşağıyı zaten güçlü tutuyor (VC → view → kontrol). Kontrol de VC'yi güçlü tutsaydı retain cycle olurdu; bu yüzden geri ok weak.",
            "weak yazabilmek için protokol class'a bağlı olmalı: protocol XDelegate: AnyObject. Delegate ölebileceği için Optional'dır ve delegate?.method() ile çağrılır.",
            "Seçim: 1'e 1 ilişki ve birden çok ilişkili olay ya da değer döndüren sorular (should…, dataSource) → delegate; tek callback → closure; 1'e çok yayın → NotificationCenter; zaman içinde değer akışı → AsyncStream/Combine.",
        ],
        followUps: [
            FollowUp(
                question: "Mülakatçı \"hangisi superclass olur?\" diye sorarsa?",
                answer: "Kalıtım yok; kastedilen \"kim kimi tutar, kim kime haber verir\" sorusudur. Sahip delegate olur ve aşağıdakini strong tutar; aşağıdaki nesne weak delegate ile yukarıya haber verir. Bu aynı zamanda mimari bir karardır: Kontrol yeniden kullanılabilir kalsın diye \"ne yapılacağına\" sahibi karar verir; kontrol sahibinin tipini bilmez, sadece protokolü bilir."
            ),
            FollowUp(
                question: "Neden unowned değil de weak?",
                answer: "Delegate'in kontrolden önce ölmeyeceği genelde garanti değildir: kontrolü başka biri tutuyor olabilir, bir animasyon ya da async iş onu yaşatabilir. unowned ölmüş nesneye erişimde çöker; weak ise nil olur ve optional chaining ile güvenle atlanır. unowned yalnızca ömür garantiliyse (ör. iki nesne her zaman birlikte yok oluyorsa) uygundur."
            ),
            FollowUp(
                question: "Delegate mi, closure mı, NotificationCenter mı?",
                answer: "Delegate: 1'e 1, birbiriyle ilişkili birçok callback ve dönüş değeri isteyen sorular; sözleşme protokolde yazılı. Closure: tek olay ya da tek seferlik sonuç; kısa ve yerel, saklanıyorsa [weak self]. NotificationCenter: 1'e çok, birbirini tanımayan taraflar arasında yayın; dönüş değeri yok. Zaman içinde akan değerler için AsyncStream ya da Combine."
            ),
            FollowUp(
                question: "Swift'te isteğe bağlı (optional) delegate metodu nasıl yazılır?",
                answer: "İki yol var. @objc protocol + @objc optional func: yalnızca class'lar uygulayabilir ve Objective-C çalışma zamanına bağlıdır (UIKit protokolleri böyle). Saf Swift yolu: protokol extension'ında varsayılan implementasyon. Projede shouldChangeRatingTo varsayılan olarak true döner; isteyen delegate kendi cevabını yazar."
            ),
            FollowUp(
                question: "VIPER'da weak referanslar nerede?",
                answer: "View (VC) presenter'ı strong tutar, presenter view'u weak tutar. Presenter interactor'ı strong tutar, interactor sonucu bildirdiği output'u (presenter) weak tutar. Router da genellikle VC'yi weak tutar. Kural aynı: sahiplik zinciri strong, geri bildirim yolu weak."
            ),
        ],
        pitfalls: [
            "Delegate'i strong tanımlamak (var delegate: XDelegate?): VC → kontrol → VC döngüsü, ikisi de hiç ölmez.",
            "Protokolü AnyObject'e bağlamayı unutmak: derleyici \"'weak' must not be applied to non-class-bound 'any XDelegate'\" hatası verir.",
            "delegate = self atamasını unutmak: delegate?.method() nil üzerinde sessizce hiçbir şey yapmaz; callback'ler kaybolur, hata da görmezsin.",
            "Birden çok dinleyici gerekirken delegate kullanmak: delegate tek bir nesnedir, ikinci atama birinciyi ezer. 1'e çok için NotificationCenter, Combine ya da dinleyici başına ayrı AsyncStream.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Delegation/StarRatingControl.swift",
                symbol: "StarRatingControlDelegate",
                note: "Protokolü sahip olunan taraf tanımlar: AnyObject (weak için şart) ve @MainActor. shouldChange için varsayılan cevap protokol extension'ında."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Delegation/StarRatingControl.swift",
                symbol: "StarRatingControl.selectRating(_:)",
                note: "Önce delegate'e sorar (dönüş değeri!), sonra değiştirir, en son delegate, closure ve target-action ile haber verir."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Delegation/BookRatingViewController.swift",
                symbol: "BookRatingViewController.connectRatingControl()",
                note: "Üç bağlantı: delegate = self (weak), onRatingChange closure'ında [weak self], addTarget (UIControl hedefi retain etmez)."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Delegation/DelegateLifetimeExperiment.swift",
                symbol: "DelegateLifetimeExperiment.run()",
                note: "Sahip ölür, kontrol yaşar: weak delegate kendiliğinden nil olur ve kontrol çökmeden çalışmaya devam eder."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/Memory/LeakVictimViewController.swift",
                symbol: "LeakVictimViewControllerDelegate",
                note: "Modal kalıbı: Sunulan ekran kendini kapatmaz, onu sunan sahibe (laboratuvar) weak delegate ile \"işim bitti\" der."
            ),
            CodePointer(
                file: "BookShelf/Features/Favorites/FavoritesViewController.swift",
                symbol: "FavoritesViewController.configureTableView()",
                note: "UIKit'in kendi örneği: tableView.delegate = self. UITableView delegate ve dataSource'unu weak tutar."
            ),
        ],
        demo: { _ in AnyView(DelegationDemoView()) }
    )
}
