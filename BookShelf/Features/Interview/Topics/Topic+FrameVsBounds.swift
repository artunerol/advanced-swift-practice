import SwiftUI

extension InterviewTopic {
    static let frameVsBounds = InterviewTopic(
        id: AccessibilityID.Interview.TopicID.frameVsBounds,
        section: .uikit,
        question: "frame ile bounds arasındaki fark nedir?",
        shortAnswer: [
            "frame: view'ın ÜST view'ın (superview) koordinat sistemindeki dikdörtgeni. \"Ben babamın içinde neredeyim, ne kadar yer kaplıyorum?\"",
            "bounds: view'ın KENDİ koordinat sistemindeki dikdörtgeni. origin genellikle (0, 0), size view'ın kendi boyutu (transform yoksa frame.size ile aynı). \"Benim içim nasıl?\" Alt view'lar bu sisteme göre konumlanır.",
            "transform (döndürme/ölçek) bounds'u ve center'ı değiştirmez; frame ise pratikte dönüşmüş view'ı saran eksen hizalı kutuya döner. Apple dönüşmüş view'da frame'i tanımsız sayar: ona güvenme, atama yapma; bounds + center kullan.",
            "bounds.origin'i değiştirmek alt view'ları ekranda kaydırır ama frame'leri aynı kalır. UIScrollView böyle kaydırır: contentOffset == bounds.origin.",
            "Koordinat sistemleri arasında geçiş: convert(_:to:) / convert(_:from:).",
        ],
        followUps: [
            FollowUp(
                question: "100×100'lük bir view'ı 45° döndürürsen frame ve bounds ne olur?",
                answer: "bounds 100×100 kalır, center değişmez. frame yaklaşık 141×141 olur (100·√2): dönmüş kareyi saran eksen hizalı kutu. Dikdörtgende genişlik ve yükseklik (w + h)·√2/2 olur."
            ),
            FollowUp(
                question: "UIScrollView aslında nasıl kaydırır?",
                answer: "Kaydırdıkça contentOffset değişir; bu doğrudan scroll view'ın bounds.origin'idir. Alt view'ların frame'i değişmez; değişen, içeriğe bakan \"pencerenin\" konumudur. contentSize kaydırılabilir alanın boyutunu belirler."
            ),
            FollowUp(
                question: "center neye göre? transform hangi nokta etrafında uygulanır?",
                answer: "center üst view'ın koordinatlarındadır. transform, katmanın anchorPoint'i (varsayılan (0.5, 0.5), yani orta nokta) etrafında uygulanır; bu yüzden döndürünce center yerinde kalır."
            ),
            FollowUp(
                question: "Bir view'ın ekrandaki (pencere) konumunu nasıl bulursun?",
                answer: "view.convert(view.bounds, to: nil) pencere koordinatlarını verir. İki view arasında ise a.convert(rect, to: b). Bunu yerleşim bittikten sonra (ör. viewDidLayoutSubviews) yap; öncesinde frame'ler kesin değildir."
            ),
            FollowUp(
                question: "Auto Layout kullanan bir view'ın frame'ini elle değiştirirsem ne olur?",
                answer: "Bir sonraki layout geçişinde constraint'ler frame'i yeniden hesaplar ve değişikliğin kaybolur. Constraint'in sabitini değiştir ya da view'ı Auto Layout'a bağlama (translatesAutoresizingMaskIntoConstraints = true, frame tabanlı yerleşim)."
            ),
        ],
        pitfalls: [
            "Döndürülmüş/ölçeklenmiş bir view'ın frame'ine güvenmek ya da frame'e değer atamak: Apple bu durumda frame'i tanımsız sayar (UIView.h: \"do not use frame if view is transformed\"). bounds + center kullan.",
            "Alt view'ı yerleştirirken üst view'ın frame'ini kullanmak: alt view'ın frame'i üstün BOUNDS'una göredir. child.frame = parent.frame çoğu zaman yanlıştır; parent.bounds olmalı.",
            "frame/bounds değerlerine viewDidLoad'da güvenmek: boyutlar viewDidLayoutSubviews'ta kesinleşir.",
        ],
        codePointers: [
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift",
                symbol: "configureGeometry()",
                note: "child Auto Layout kullanmıyor; bounds + center ile konumlanıyor, frame ile değil."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift",
                symbol: "apply()",
                note: "transform değişince frame büyüyor, bounds/center aynı kalıyor; container.bounds.origin değişince child kayıyor ama frame'i değişmiyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift",
                symbol: "updateReadouts()",
                note: "Kesikli çerçeve child.frame'i container'ın koordinatlarında çiziyor; convert(_:to:) ile ekrandaki yer hesaplanıyor."
            ),
            CodePointer(
                file: "BookShelf/Features/Interview/Demos/UIKitLabs/FrameBounds/FrameBoundsViewController.swift",
                symbol: "scrollViewDidScroll(_:)",
                note: "Sayfanın kendi scroll view'ı: kaydırdıkça contentOffset.y ile bounds.origin.y hep eşit."
            ),
            CodePointer(
                file: "BookShelfTests/UIKitLabs/FrameBoundsTests.swift",
                symbol: "testRotating45DegreesGrowsFrameButNotBounds()",
                note: "√2 hesabının ve contentOffset == bounds.origin'in testle kanıtı."
            ),
        ],
        demo: { _ in AnyView(UIKitLabHost { FrameBoundsViewController() }) }
    )
}
