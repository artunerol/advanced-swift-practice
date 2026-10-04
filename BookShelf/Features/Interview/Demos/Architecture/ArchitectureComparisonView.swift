import SwiftUI

/// Bu projedeki üç sunum kalıbının kısa karşılaştırması. Rakamlar ve örnekler projenin kendi dosyalarından.
struct ArchitectureProfile: Identifiable, Sendable {
    let name: String
    /// Projede nerede görülür?
    let example: String
    let files: String
    let testability: String
    let boilerplate: String
    let chooseWhen: String

    var id: String { name }

    static let all: [ArchitectureProfile] = [
        ArchitectureProfile(
            name: "MVC",
            example: "Favoriler sekmesi (FavoritesViewController, MVC'ye yakın)",
            files: "1 view controller (+ küçük bir durum enum'u)",
            testability: "Zor: mantık VC'nin içinde; test için VC kurup yaşam döngüsünü taklit etmek gerekir.",
            boilerplate: "En az. Hızlı başlar, büyüyünce \"Massive View Controller\" olur.",
            chooseWhen: "Küçük, az mantıklı ekranlar; prototipler."
        ),
        ArchitectureProfile(
            name: "MVVM",
            example: "Bu demo: NotesListView + NotesListViewModel",
            files: "2-3 (View, ViewModel, editör)",
            testability: "İyi: ViewModel UI'sız test edilir (await viewModel.load()).",
            boilerplate: "Orta. View, ViewModel'i gözlemler; geri referans yok.",
            chooseWhen: "SwiftUI ekranlarının çoğu; UIKit'te Combine/closure bağlamasıyla da olur."
        ),
        ArchitectureProfile(
            name: "VIPER",
            example: "Bu demo: NotesListContracts + 4 sınıf",
            files: "5 (sözleşmeler, View, Presenter, Interactor, Router)",
            testability: "Çok iyi: her parça protokolle ayrılmış, sahtesiyle tek başına test edilir.",
            boilerplate: "Çok: protokoller, bağlama (build), weak referanslar.",
            chooseWhen: "Büyük UIKit ekipleri, karmaşık akışlar, modüller arasında sıkı sınırlar."
        ),
    ]
}

/// Demo'nun "Kıyas" bölümü.
struct ArchitectureComparisonView: View {
    var body: some View {
        List {
            ForEach(ArchitectureProfile.all) { profile in
                Section {
                    row("Projede", profile.example)
                    row("Dosya", profile.files)
                    row("Test edilebilirlik", profile.testability)
                    row("Tören (boilerplate)", profile.boilerplate)
                    row("Ne zaman?", profile.chooseWhen)
                } header: {
                    Text(profile.name)
                }
            }

            Section {
                Text("""
                Clean Architecture bunlara rakip değil. MVC/MVVM/VIPER sunum katmanını böler; Clean Architecture \
                tüm uygulamanın katmanlarını ve bağımlılık yönünü (oklar içeri, domain'e) belirler. Bu demoda iki \
                sunum kalıbı da aynı Domain'i (use case'ler + NotesRepository) kullanıyor.
                """)
                .font(.callout)
            } header: {
                Text("Clean Architecture nerede?")
            }
        }
        .accessibilityIdentifier(AccessibilityID.ReadingNotes.comparisonList)
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}
