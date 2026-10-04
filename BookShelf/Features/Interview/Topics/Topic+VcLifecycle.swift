import SwiftUI

extension InterviewTopic {
    static let vcLifecycle = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.vcLifecycle,
        section: .uikit,
        question: "UIViewController yaşam döngüsünü anlatır mısın? viewDidLayoutSubviews ne zaman çağrılır?",
        shortAnswer: [
            "Sıra: init → loadView → viewDidLoad → viewWillAppear → viewIsAppearing → viewWillLayoutSubviews / viewDidLayoutSubviews → viewDidAppear. Kaybolurken viewWillDisappear → viewDidDisappear; en son deinit.",
            "viewDidLoad view belleğe yüklenince BİR kez çalışır: alt view'lar, constraint'ler, delegate'ler gibi tek seferlik kurulum. Burada boyutlar henüz kesin değildir.",
            "viewWillLayoutSubviews / viewDidLayoutSubviews, kök view'ın layoutSubviews'u her çalıştığında gelir: ilk yerleşim, döndürme, boyut değişimi, setNeedsLayout, alt view eklenmesi... Kaç kez geleceği belli değildir. viewDidLayoutSubviews'ta kök view'ın bounds'u ve doğrudan alt view'larının frame'leri kesindir (daha derindekiler kendi layoutSubviews'unda yerleşir); buraya ucuz ve tekrar çalıştırılabilir geometri işi konur.",
            "viewIsAppearing (iOS 17 SDK, iOS 13'e kadar geriye dönük) her görünüşte gelir ve o anda trait'ler ile geometri geçerlidir; görünüşe bağlı UI güncellemesi için viewWillAppear'dan daha doğru yerdir.",
            "Appear/disappear çifti her görünüşte tekrarlanır: dinleyicileri, zamanlayıcıları viewWillAppear'da başlat, viewDidDisappear'da durdur.",
            "Tuzak: Sheet (.pageSheet/.formSheet, iOS 13+ varsayılanı) ve .overFullScreen, alttaki ekranın viewWillDisappear/viewDidDisappear'ını tetiklemez, çünkü alttaki view pencerede kalır. .fullScreen sunum bitince alttakini kaldırır ve tetikler; kapanışta alttaki ekran yeniden appear alır.",
        ],
        followUps: [
            FollowUp(
                question: "loadView ile viewDidLoad arasındaki fark nedir?",
                answer: "loadView kök view'ı OLUŞTURUR; override edersen super çağırmadan view = ... atarsın (storyboard/XIB yoksa varsayılanı boş bir UIView yaratır). viewDidLoad, view oluştuktan sonra kurulum içindir. vc.view'a ilk erişim (veya loadViewIfNeeded) yüklemeyi tetikler; init içinde view'a dokunmak onu erkenden yükler."
            ),
            FollowUp(
                question: "viewDidLayoutSubviews içinde neyi yapmamalıyım?",
                answer: "Ağır hesap, ağ isteği ya da yalnızca bir kez yapılacak kurulum. Yeniden layout tetikleyen bir değişiklik (constraint eklemek, sürekli farklı değer atamak) sonsuz layout döngüsüne yol açabilir. Değer gerçekten değiştiyse güncelle; metot defalarca çağrılsa da sonucu aynı olmalı (idempotent)."
            ),
            FollowUp(
                question: "Sheet kapanınca alttaki ekranın verisini nasıl tazelersin? viewWillAppear çağrılmıyor.",
                answer: "pageSheet/formSheet'te alttaki ekran hiç kaybolmadığı için görünüş bildirimi gelmez. Sunulan ekran bir delegate ya da closure ile haber verir. Kullanıcının kaydırarak kapatmasını yakalamak için presentationController?.delegate ile presentationControllerDidDismiss(_:) kullanılır; bu metot programatik dismiss sonrası çağrılmaz."
            ),
            FollowUp(
                question: "Döndürme ve trait değişimlerini nerede yakalarsın?",
                answer: "Boyut değişimi için viewWillTransition(to:with:) (coordinator ile animasyona eşlik edilir). Trait'ler (koyu mod, size class, yazı boyutu) için iOS 17+ registerForTraitChanges(_:handler:); traitCollectionDidChange iOS 17'de deprecated oldu. Kapanış self'i parametre olarak aldığı için yakalama gerekmez."
            ),
            FollowUp(
                question: "Child view controller nasıl eklenir ve çıkarılır?",
                answer: "Ekleme: addChild(child) → view.addSubview(child.view) + constraint → child.didMove(toParent: self). Çıkarma: child.willMove(toParent: nil) → child.view.removeFromSuperview() → child.removeFromParent(). addChild willMove'u, removeFromParent didMove'u kendisi çağırır; görünüş bildirimleri child'a otomatik iletilir."
            ),
        ],
        pitfalls: [
            "Boyuta bağlı hesapları (köşe yarıçapı, frame'e göre konum) viewDidLoad'da yapmak: bounds henüz son halinde değil.",
            "viewDidLayoutSubviews'a bir kez yapılacak işi ya da yeniden layout tetikleyen kodu koymak: çok kez çağrılır, döngüye girebilir.",
            "Override ederken super'i çağırmamak (istisna: kendi kök view'ını kuran loadView). Örneğin viewWillAppear'da super atlanırsa child VC'lere bildirim gitmeyebilir.",
            "Sheet kapanınca alttaki ekranın viewWillAppear'ının çalışacağını varsaymak: Alttaki view hiç kaldırılmadığı için çalışmaz; ancak .fullScreen gibi alttakini kaldıran bir sunumdan dönüşte çalışır.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LoggingViewController.swift",
                symbol: "LoggingViewController",
                note: "Her override önce super'i çağırıp olayı yazıyor; loadView'da super yok, deinit nonisolated olduğu için günlüğe Task ile yazıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LifecycleSubjectViewController.swift",
                symbol: "makeModal(style:)",
                note: "Sunum stili sunulan VC'ye verilir; .pageSheet ile .fullScreen arasındaki tek fark bu satır, günlükteki fark ise Ana'nın disappear çağrıları."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LifecycleSubjectViewController.swift",
                symbol: "toggleChild()",
                note: "Containment sırası: addChild → addSubview → didMove; çıkarırken willMove(nil) → removeFromSuperview → removeFromParent."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/Lifecycle/LifecycleSubjectViewController.swift",
                symbol: "relayout()",
                note: "setNeedsLayout + layoutIfNeeded yalnızca layout çiftini tetikler; viewDidLoad tekrar çalışmaz."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift",
                symbol: "viewDidLayoutSubviews()",
                note: "Geometriye bağlı iş burada: convert(_:to:) doğru sonucu ancak yerleşimden sonra verir; aynı metni tekrar yazmayarak idempotent kalıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Favorites/FavoritesViewController.swift",
                symbol: "viewWillAppear(_:) / viewDidDisappear(_:)",
                note: "Gerçek kullanım: dinlemeyi görünüşte başlat, ekran gerçekten kaybolunca durdur."
            ),
        ],
        demo: { _ in AnyView(UIKitLabHost { LifecycleLabViewController() }) }
    )
}
