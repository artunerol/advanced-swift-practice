import SwiftUI

/// "Clean Architecture, VIPER ve MVVM" konusunun canlı demosu.
///
/// Aynı özellik (Okuma Notları) iki kez yazıldı: **VIPER + UIKit** ve **MVVM + SwiftUI**. İkisi de AYNI use case'leri
/// ve AYNI depoyu kullanır. Birinde not ekle, diğerine geç: not oradadır (geçişte ekran yeniden kurulur, depodan okur).
///
/// Depo seçici, Dependency Inversion'ın canlı kanıtı: depolama değişir, sunum kodu (VIPER modülü ve MVVM ekranı)
/// tek satır değişmeden çalışır; çünkü ikisi de somut bir sınıfa değil, domain'deki `NotesRepository`'ye bağlı.
struct ReadingNotesDemoView: View {
    private typealias ID = AccessibilityID.ReadingNotes

    enum Presentation: CaseIterable, Identifiable {
        case viper, mvvm, comparison

        var id: Self { self }

        // Not: Burada kısa `ID` adını kullanamayız; `Identifiable`'ın kendi `ID` tipi o adı gölgeler.
        var label: String {
            switch self {
            case .viper: AccessibilityID.ReadingNotes.viperSegment
            case .mvvm: AccessibilityID.ReadingNotes.mvvmSegment
            case .comparison: AccessibilityID.ReadingNotes.comparisonSegment
            }
        }
    }

    /// Depo seçeneği: uygulamanın composition root'unda seçilen depo ya da fabrikadan belirli bir tür.
    enum StorageOption: Hashable {
        case app
        case kind(NotesStorageKind)

        static var all: [StorageOption] { [.app] + NotesStorageKind.allCases.map(StorageOption.kind) }

        var title: String {
            switch self {
            case .app: "Varsayılan"
            case .kind(.inMemory): "Bellek"
            case .kind(.userDefaults): "UserDefaults"
            case .kind(.file): "Dosya (JSON)"
            case .kind(.coreData): "Core Data"
            case .kind(.swiftData): "SwiftData"
            }
        }
    }

    let dependencies: AppDependencies

    @State private var presentation: Presentation = .viper
    @State private var storage: StorageOption = .app
    /// Fabrikadan alınan depolar türüne göre saklanır: aynı tür tekrar seçilince yeni bir örnek (ör. ikinci bir
    /// Core Data yığını) oluşturulmaz, notlar da kaybolmaz.
    @State private var repositories: [NotesStorageKind: any NotesRepository] = [:]

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            switch presentation {
            case .viper:
                // `.id(storage)`: depo değişince SwiftUI eski modülü atar, yenisini yeni depoyla kurar.
                NotesListVIPERContainer(repository: repository).id(storage)
            case .mvvm:
                NotesListView(useCases: NotesUseCases(repository: repository)).id(storage)
            case .comparison:
                ArchitectureComparisonView()
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Sunum", selection: $presentation) {
                ForEach(Presentation.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(ID.presentationPicker)

            if presentation != .comparison {
                HStack {
                    Text("Depo")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Depo", selection: storageSelection) {
                        ForEach(StorageOption.all, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier(ID.storagePicker)
                }
                Text("İki ekran da aynı use case'leri ve aynı depoyu kullanır. Birinde not ekle, diğerine geç.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Seçili depo. `.app` = `AppDependencies`'in verdiği (composition root'un kararı).
    private var repository: any NotesRepository {
        switch storage {
        case .app: dependencies.notesRepository
        case .kind(let kind): repositories[kind] ?? dependencies.notesRepository
        }
    }

    /// Seçim değişirken depoyu da (gerekirse) oluşturan bağlantı. Oluşturmayı `body` içinde yapamayız:
    /// `body` hesaplanırken `@State` değiştirmek SwiftUI'da yasaktır. Kullanıcı eylemi (bu setter) ise uygun yerdir.
    private var storageSelection: Binding<StorageOption> {
        Binding(
            get: { storage },
            set: { newValue in
                if case .kind(let kind) = newValue, repositories[kind] == nil {
                    repositories[kind] = NotesRepositoryFactory.make(kind)
                }
                storage = newValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        ReadingNotesDemoView(dependencies: .preview)
    }
}
