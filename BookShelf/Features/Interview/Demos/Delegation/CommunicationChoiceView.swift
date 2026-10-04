import SwiftUI

/// "Delegate mi, closure mı, NotificationCenter mı, AsyncStream mi?" sorusunun özet tablosu.
///
/// Ayrım iki soruya dayanır: **Kaç dinleyici var?** (1'e 1 mi, 1'e çok mu) ve **kaç çeşit olay/soru var?**
/// (tek callback mı, birbiriyle ilişkili birçok callback ve dönüş değeri isteyen sorular mı).
struct CommunicationChoiceView: View {
    var body: some View {
        List {
            ForEach(CommunicationOption.all) { option in
                Section {
                    row("Ne zaman?", option.whenToUse)
                    row("Bellek", option.memory)
                    row("Bu projede", option.example)
                } header: {
                    Text(verbatim: option.title)
                        .textCase(nil)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Delegation.choiceList)
    }

    private func row(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: text)
                .font(.subheadline)
        }
    }
}

private struct CommunicationOption: Identifiable {
    let title: String
    let whenToUse: String
    let memory: String
    let example: String
    var id: String { title }

    static let all: [CommunicationOption] = [
        CommunicationOption(
            title: "Delegate (protokol)",
            whenToUse: "1'e 1 ilişki; birbiriyle ilişkili birçok olay ve dönüş değeri isteyen sorular (should…, numberOfRows…). Sözleşme protokolde yazılı, derleyici denetler.",
            memory: "Sahip olunan taraf delegate'i weak tutar; protokol AnyObject'e bağlı olmalı.",
            example: "StarRatingControlDelegate, UITableViewDelegate (FavoritesViewController)"
        ),
        CommunicationOption(
            title: "Closure (callback)",
            whenToUse: "1'e 1, tek bir olay ya da tek seferlik sonuç (completion). Kısa ve yerel; ayrı bir tip gerekmez.",
            memory: "Saklanan closure self'i yakalarsa döngü: [weak self]. Kaçmayan (non-escaping) closure'lar döngü kuramaz.",
            example: "StarRatingControl.onRatingChange, UIAction"
        ),
        CommunicationOption(
            title: "Target-action",
            whenToUse: "UIControl olayları (dokunma, değer değişimi). Birden çok hedef eklenebilir.",
            memory: "addTarget hedefi retain etmez. addAction(UIAction) ise closure'ı tutar: [weak self].",
            example: "BookRatingViewController.ratingControlValueChanged(_:)"
        ),
        CommunicationOption(
            title: "NotificationCenter",
            whenToUse: "1'e çok yayın; gönderen dinleyenleri tanımaz (klavye, uygulama yaşam döngüsü). Dönüş değeri yok, sözleşme gevşek (userInfo).",
            memory: "Block tabanlı gözlemci removeObserver'a kadar tutulur; block'ta [weak self]. Selector tabanlıda iOS 9'dan beri kaldırma zorunlu değil.",
            example: "Sızıntı laboratuvarı → Bildirim senaryosu"
        ),
        CommunicationOption(
            title: "AsyncStream / Combine",
            whenToUse: "Zaman içinde akan değerler (durum değişiklikleri). AsyncStream: for await ile tüketilir, tek tüketici içindir (FavoritesStore her dinleyiciye ayrı akış verir), Task iptal edilince biter. Combine: bir publisher'a birden çok abone, hazır operatörler (map, debounce).",
            memory: "Dinleyen Task'ı sakla ve iptal et; Combine'da AnyCancellable'ı sakla, sink closure'ında [weak self].",
            example: "FavoritesStore.changes() → FavoritesViewController"
        ),
    ]
}

#Preview {
    CommunicationChoiceView()
}
