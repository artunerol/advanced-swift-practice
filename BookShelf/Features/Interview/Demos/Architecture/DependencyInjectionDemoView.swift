import SwiftUI

/// "Dependency Inversion ile Dependency Injection aynı şey mi?" konusunun canlı demosu.
///
/// 1. Üç sayaç: sıkı bağlı (ne DI ne DIP), somut tip enjekte (DI var, DIP yok), protokol enjekte (DI + DIP).
/// 2. Strateji enjeksiyonu: seçilen biçimlendirici SwiftUI `Environment`'ı ile alt view'a, oradan da metoda
///    parametre olarak (method injection) geçer; çıktı canlı değişir.
/// 3. DI teknikleri ve sık karıştırılanlar, projedeki yerleriyle.
struct DependencyInjectionDemoView: View {
    private typealias ID = AccessibilityID.ReadingNotes.DependencyDemo

    enum RepositoryChoice: CaseIterable, Identifiable {
        case filled, empty

        var id: Self { self }

        var label: String {
            switch self {
            case .filled: AccessibilityID.ReadingNotes.DependencyDemo.filledRepositorySegment
            case .empty: AccessibilityID.ReadingNotes.DependencyDemo.emptyRepositorySegment
            }
        }

        func makeRepository() -> InMemoryNotesRepository {
            switch self {
            case .filled: DependencyDemoSamples.filledRepository()
            case .empty: InMemoryNotesRepository()
            }
        }
    }

    enum FormatterChoice: CaseIterable, Identifiable {
        case date, length

        var id: Self { self }

        var label: String {
            switch self {
            case .date: AccessibilityID.ReadingNotes.DependencyDemo.dateFormatterSegment
            case .length: AccessibilityID.ReadingNotes.DependencyDemo.lengthFormatterSegment
            }
        }

        var formatter: any NoteFormatter {
            switch self {
            case .date: DateNoteFormatter()
            case .length: LengthNoteFormatter()
            }
        }
    }

    @State private var repositoryChoice: RepositoryChoice = .filled
    @State private var formatterChoice: FormatterChoice = .date
    @State private var counts = CounterResults()

    var body: some View {
        List {
            countersSection
            strategySection
            techniquesSection
            confusionsSection
        }
        .accessibilityIdentifier(ID.list)
        // Seçim her değiştiğinde (ve ilk açılışta) sayaçları yeniden çalıştırır; eski görev otomatik iptal edilir.
        .task(id: repositoryChoice) {
            counts = await CounterResults.measure(with: repositoryChoice.makeRepository())
        }
    }

    // MARK: - 1. Sayaçlar

    private var countersSection: some View {
        Section {
            Picker("Enjekte edilen depo", selection: $repositoryChoice) {
                ForEach(RepositoryChoice.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(ID.repositoryPicker)

            counterRow(
                "(a) Sıkı bağlı",
                detail: "Deposunu kendisi oluşturur. Seçimi hiç duymaz.",
                value: counts.tightlyCoupled,
                identifier: ID.tightlyCoupledCount
            )
            counterRow(
                "(b) Somut tip enjekte",
                detail: "DI var, DIP yok: sadece InMemoryNotesRepository kabul eder.",
                value: counts.concreteInjected,
                identifier: ID.concreteInjectedCount
            )
            counterRow(
                "(c) Protokol enjekte",
                detail: "DI + DIP: NotesRepository'yi uygulayan her depo olur.",
                value: counts.injected,
                identifier: ID.injectedCount
            )
        } header: {
            Text("1 · Kim oluşturuyor, neye bağlı?")
        } footer: {
            Text("""
            Seçimi değiştir: (b) ve (c) değişir, (a) hep 0. (b)'ye bir Core Data deposu vermek derleme hatası olurdu; \
            (c) hiç değişmeden kabul eder. Kod: DependencyExamples.swift
            """)
        }
    }

    private func counterRow(_ title: String, detail: String, value: String, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .monospacedDigit()
                .accessibilityIdentifier(identifier)
        }
    }

    // MARK: - 2. Strateji

    private var strategySection: some View {
        Section {
            Picker("Biçimlendirici", selection: $formatterChoice) {
                ForEach(FormatterChoice.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(ID.formatterPicker)

            FormattedNotesPreview()
                // SwiftUI'ın kendi DI'ı: değer ağaç boyunca aşağı akar; alt view'lar `@Environment` ile okur.
                .environment(\.noteFormatter, formatterChoice.formatter)
        } header: {
            Text("2 · Strateji enjeksiyonu")
        } footer: {
            Text("""
            Seçim → .environment(\\.noteFormatter) → alt view @Environment ile okur → \
            NotesPlainTextExporter.export(_:using:) metoduna parametre olarak verir (method injection).
            """)
        }
    }

    // MARK: - 3. Teknikler

    private var techniquesSection: some View {
        Section("3 · DI teknikleri, projede nerede?") {
            techniqueRow(
                "Constructor injection",
                where: "AddNoteUseCase(repository:now:), NotesListViewModel(useCases:formatter:)",
                note: "Varsayılan tercih. Zorunlu bağımlılık eksik bırakılamaz, let ile değişmez."
            )
            techniqueRow(
                "Property injection",
                where: "NotesListRouter.build: presenter.view, interactor.output, router.viewController",
                note: "Geri (weak) referanslar ve storyboard VC'leri için. Atanmayı unutmak mümkün; dikkat."
            )
            techniqueRow(
                "Method injection",
                where: "NotesPlainTextExporter.export(_:using:)",
                note: "Çağrıya özel strateji. Standart kütüphanede: sorted(by:)."
            )
            techniqueRow(
                "SwiftUI Environment",
                where: "@Environment(\\.noteFormatter), .environment(\\.noteFormatter, ...)",
                note: "Ağaç boyunca örtük DI. Değer verilmezse varsayılan sessizce kullanılır."
            )
            techniqueRow(
                "Composition root",
                where: "AppDependencies.makeForLaunch(arguments:)",
                note: "Somut tiplerin seçilip bağlandığı TEK yer. Geri kalan kod protokolleri görür."
            )
        }
    }

    private func techniqueRow(_ title: String, where location: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(location).font(.caption.monospaced())
            Text(note).font(.callout).foregroundStyle(.secondary)
        }
    }

    // MARK: - 4. Karıştırılanlar

    private var confusionsSection: some View {
        Section("4 · Sık karıştırılanlar") {
            techniqueRow(
                "DI ≠ DIP",
                where: "ConcreteInjectedNoteCounter",
                note: "Somut bir sınıfı enjekte etmek DI'dır ama bağımlılığın yönünü çevirmez; DIP yoktur."
            )
            techniqueRow(
                "DIP için container gerekmez",
                where: "AppDependencies (elle DI)",
                note: "Swinject gibi bir kap kolaylık sağlar, şart değildir. Bu projede hiç yok."
            )
            techniqueRow(
                "Service locator (anti-kalıp)",
                where: "Locator.shared.resolve(NotesRepository.self)",
                note: """
                Bağımlılık imzada görünmez, global durumdur; eksik kayıt ancak çalışma anında patlar. \
                Bilerek projede yok.
                """
            )
        }
    }
}

/// Seçilen stratejiyi `Environment`'tan okuyup örnek notları dışa aktaran alt view.
private struct FormattedNotesPreview: View {
    @Environment(\.noteFormatter) private var formatter

    var body: some View {
        Text(NotesPlainTextExporter.export(DependencyDemoSamples.notes, using: formatter))
            .font(.callout.monospaced())
            .accessibilityIdentifier(AccessibilityID.ReadingNotes.DependencyDemo.formatterOutput)
    }
}

/// Üç sayacın sonuçları (ekranda gösterilecek metin olarak).
private struct CounterResults {
    var tightlyCoupled = "…"
    var concreteInjected = "…"
    var injected = "…"

    /// Aynı depo örneği (b) ve (c)'ye verilir; (a) kendi deposunu kendisi oluşturur.
    static func measure(with repository: InMemoryNotesRepository) async -> CounterResults {
        let tight = await TightlyCoupledNoteCounter().count()
        let concrete = await ConcreteInjectedNoteCounter(repository: repository).count()
        let injected = try? await InjectedNoteCounter(repository: repository).count()
        return CounterResults(
            tightlyCoupled: "\(tight) not",
            concreteInjected: "\(concrete) not",
            injected: injected.map { "\($0) not" } ?? "hata"
        )
    }
}

extension EnvironmentValues {
    /// Notların ikincil satırını üreten strateji. `@Entry` makrosu `EnvironmentKey` tipini ve erişimcileri üretir.
    /// Varsayılan değer, hiçbir üst view bir değer vermediğinde kullanılır.
    @Entry var noteFormatter: any NoteFormatter = DateNoteFormatter()
}

#Preview {
    NavigationStack {
        DependencyInjectionDemoView()
    }
}
