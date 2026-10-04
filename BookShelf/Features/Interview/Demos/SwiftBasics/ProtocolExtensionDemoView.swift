import SwiftUI

/// "Protocol + extension" konusunun demosu, üç bölümde:
/// - **Dispatch:** Aynı dergiyi üç farklı derleme anı tipiyle oku; gereksinim ile extension'a özel üyenin farkını gör.
/// - **Varsayılan:** Varsayılan uygulamalar, protocol kalıtımı (`PagedReadingItem`), retroactive conformance (`Book`)
///   ve extension'ların ekleyemediği şeyler.
/// - **Koşullu:** `where` ile kısıtlanmış extension'lar.
///
/// Mantık `ProtocolExtensionExamples.swift` ve `ReadingItem.swift` içinde; bu view yalnızca gösterir.
/// Kendi `NavigationStack`'ini içermez.
struct ProtocolExtensionDemoView: View {
    enum Part: CaseIterable, Identifiable {
        case dispatch, defaults, constrained

        var id: Self { self }

        var label: String {
            switch self {
            case .dispatch: AccessibilityID.Fundamentals.ProtocolExtension.dispatchSegment
            case .defaults: AccessibilityID.Fundamentals.ProtocolExtension.defaultsSegment
            case .constrained: AccessibilityID.Fundamentals.ProtocolExtension.constrainedSegment
            }
        }
    }

    private typealias ID = AccessibilityID.Fundamentals.ProtocolExtension

    @State private var part: Part = .dispatch
    @State private var viewpoint: DispatchViewpoint = .concrete

    var body: some View {
        List {
            Section {
                Picker("Bölüm", selection: $part) {
                    ForEach(Part.allCases) { part in
                        Text(part.label).tag(part)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(ID.sectionPicker)
            }

            switch part {
            case .dispatch: dispatchSections
            case .defaults: defaultsSections
            case .constrained: constrainedSections
            }
        }
        .navigationTitle("Protocol + extension")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Dispatch

    @ViewBuilder
    private var dispatchSections: some View {
        let observation = ProtocolDispatchDemo.observe(from: viewpoint)

        Section {
            Picker("Derleme anındaki tip", selection: $viewpoint) {
                ForEach(DispatchViewpoint.allCases) { viewpoint in
                    Text(viewpoint.label).tag(viewpoint)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(ID.viewpointPicker)

            Text(viewpoint.declaration)
                .font(.footnote.monospaced())
                .accessibilityIdentifier(ID.viewpointDeclaration)
            Text(verbatim: "symbolName (gereksinim): \(observation.requirement)")
                .accessibilityIdentifier(ID.requirementResult)
            Text(verbatim: "shelfSection (yalnız extension): \(observation.extensionOnly)")
                .foregroundStyle(observation.extensionOnly == "Genel raf" ? Color.orange : Color.primary)
                .accessibilityIdentifier(ID.extensionOnlyResult)
        } header: {
            Text("Aynı dergi, değişkenin tipi değişiyor")
                .textCase(nil)
        } footer: {
            Text("""
            symbolName protocol'de bir gereksinim: Çağrı witness table üzerinden gerçek tipe gider, hep "newspaper". \
            shelfSection ise yalnızca extension'da: Hangi gövdenin çalışacağına derleyici, değişkenin derleme anındaki \
            tipine bakarak karar verir. Magazine'in kendi shelfSection'ı yalnızca tip Magazine iken görünür; \
            any ya da some üzerinden extension'daki "Genel raf" çalışır. Magazine'deki üye extension'dakini ezmez, gölgeler.
            """)
        }

        Section {
            Text("""
            Tiplerin özelleştirebilmesini istediğin her şeyi protocol'e GEREKSİNİM olarak yaz, varsayılanı extension'da ver. \
            Yalnızca extension'da duran üyeler, kimsenin özelleştirmeyeceği yardımcılar (ör. formattedDuration) içindir.
            """)
            .font(.callout)
        } header: {
            Text("Kural")
                .textCase(nil)
        }
    }

    // MARK: - Varsayılan uygulamalar

    @ViewBuilder
    private var defaultsSections: some View {
        Section {
            ForEach(ProtocolDefaultsDemo.summaries) { summary in
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.declaration)
                        .font(.footnote.monospaced())
                    Text(verbatim: "symbolName: \(summary.symbolName) · \(summary.symbolSource)")
                        .font(.caption)
                    Text(verbatim: "estimatedMinutes: \(summary.minutes) · \(summary.minutesSource)")
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(ID.conformanceRow(summary.id))
            }
        } header: {
            Text("Üyeler nereden geliyor?")
                .textCase(nil)
        } footer: {
            Text("""
            Bir gereksinime extension'da gövde yazmak, onun varsayılan uygulamasıdır; tip isterse kendi uygulamasını yazar. \
            PagedReadingItem, ReadingItem'ı miras alır (protocol kalıtımı) ve onun estimatedMinutes gereksinimini kendi \
            extension'ında karşılar. Book Core'da tanımlı; uygunluk sonradan, kaynağına dokunmadan eklendi (retroactive conformance).
            """)
        }

        Section {
            limitRow(
                code: "extension Novel { var rating = 0 }",
                message: "error: extensions must not contain stored properties"
            )
            limitRow(
                code: "class Base {}\nextension Base { func greet() {} }\nclass Sub: Base { override func greet() {} }",
                message: "error: non-'@objc' instance method 'greet()' is declared in extension of 'Base' and cannot be overridden"
            )
            limitRow(
                code: "extension ReadingItem: CustomStringConvertible {}",
                message: "error: extension of protocol 'ReadingItem' cannot have an inheritance clause"
            )
        } header: {
            Text("Extension ne ekleyemez?")
                .textCase(nil)
        } footer: {
            Text("""
            Extension; computed property, metot, init, iç içe tip ve protocol uygunluğu ekleyebilir. Saklanan özellik \
            ekleyemez (tipin bellek düzeni tanımında sabitlenir), Objective-C'ye açık olmayan bir metodu alt sınıfta ezdirmez. \
            Bir protocol'ün başka bir protocol'e uymasını ise protocol'ün kendi tanımında yazarsın (protocol P: Q).
            """)
        }
    }

    private func limitRow(code: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(code)
                .font(.footnote.monospaced())
            Text(message)
                .font(.caption.monospaced())
                .foregroundStyle(.red)
        }
    }

    // MARK: - Koşullu extension

    @ViewBuilder
    private var constrainedSections: some View {
        Section {
            Text(verbatim: "extension Sequence where Element: PagedReadingItem {\n    var totalPageCount: Int { ... }\n}")
                .font(.footnote.monospaced())
            Text(verbatim: "[Novel] → toplam \(ConstrainedExtensionDemo.novelPages) sayfa")
                .accessibilityIdentifier(ID.novelPagesResult)
        } header: {
            Text("Yalnızca sayfalı öğelerin dizisinde")
                .textCase(nil)
        } footer: {
            Text("""
            [Novel] ve [Book] bu üyeyi alır. [Magazine] almaz (dergi sayfalı değil); [any ReadingItem] de almaz, çünkü \
            kutunun kendisi protocol'e uymaz. Koşul derleme anında denetlenir: Uymayan dizide totalPageCount yazmak derleme hatasıdır.
            """)
        }

        Section {
            Text(verbatim: "extension Shelf where Item: Comparable {\n    var sortedItems: [Item] { items.sorted() }\n}")
                .font(.footnote.monospaced())
            Text(verbatim: "Sıralı raftaki ilk roman: \(ConstrainedExtensionDemo.firstNovelOnSortedShelf ?? "-")")
                .accessibilityIdentifier(ID.sortedShelfResult)
        } header: {
            Text("Yalnızca Comparable öğeli raflarda")
                .textCase(nil)
        } footer: {
            Text("ReadingShelf<Novel>'da sortedItems var (Novel Comparable). ReadingShelf<Book>'ta yok: Book Comparable değil.")
        }
    }
}

#Preview {
    NavigationStack {
        ProtocolExtensionDemoView()
    }
}
