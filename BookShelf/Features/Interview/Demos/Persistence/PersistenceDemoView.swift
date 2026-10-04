import SwiftUI

/// Kalıcılık demosu: "iOS'ta veriyi nerede saklarsın?" sorusunun canlı hali. Üç bölüm:
/// 1. **Ayar & Sır:** Okuma hızı `@AppStorage` (UserDefaults) ile, sahte bir token Keychain ile saklanır.
/// 2. **Notlar:** Aynı `NotesRepository` sözleşmesinin beş uygulaması yan yana: bellek, UserDefaults, dosya,
///    Core Data, SwiftData. Not ekle, "yeniden aç" ve hangisinin kalıcı olduğunu gör.
/// 3. **Karşılaştır:** UserDefaults'tan CloudKit'e seçeneklerin tablosu.
///
/// Kendi `NavigationStack`'ini içermez; Mülakat konusu ekranının (`InterviewTopicScreen`) "Demo" bölümünde gösterilir.
struct PersistenceDemoView: View {
    enum Part: CaseIterable, Identifiable {
        case settings, notes, comparison

        var id: Self { self }

        /// Etiketler `Shared/` altındaki sabitlerden gelir; UI testleri bölümleri bu metinlerle seçer.
        var label: String {
            switch self {
            case .settings: AccessibilityID.Persistence.settingsSegment
            case .notes: AccessibilityID.Persistence.notesSegment
            case .comparison: AccessibilityID.Persistence.comparisonSegment
            }
        }
    }

    /// Verinin yazılacağı konum. Uygulamada `PersistenceLocation.current`; UI testlerinde her açılışta sıfırlanan alan.
    private let location: PersistenceLocation

    @State private var part: Part = .settings
    /// Not denetçisi bölüm değiştirince kaybolmasın diye burada, üst view'da tutuluyor.
    @State private var inspector: NotesStorageInspector

    init(location: PersistenceLocation = .current) {
        self.location = location
        _inspector = State(initialValue: NotesStorageInspector(location: location))
    }

    var body: some View {
        List {
            Section {
                Picker("Bölüm", selection: $part) {
                    ForEach(Part.allCases) { part in
                        Text(part.label).tag(part)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityID.Persistence.sectionPicker)
            }

            switch part {
            case .settings: PersistenceSettingsSections(location: location)
            case .notes: NotesStorageInspectorSections(inspector: inspector)
            case .comparison: StorageComparisonSections()
            }
        }
        .accessibilityIdentifier(AccessibilityID.Persistence.list)
    }
}

#Preview {
    NavigationStack {
        PersistenceDemoView(location: .isolated(name: "BookShelf-Preview"))
    }
}
