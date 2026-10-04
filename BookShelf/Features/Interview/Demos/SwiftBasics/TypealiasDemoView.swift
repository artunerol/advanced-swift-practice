import SwiftUI

/// typealias konusunun demosu. Her bölüm bir kullanım yerini, en sondaki bölüm ise en önemli tuzağı gösterir:
/// typealias yeni bir tip OLUŞTURMAZ. "aslında: ..." satırları tipin çalışma anındaki adını yazdırır; alias'lar
/// orada hiç görünmez.
///
/// Örneklerin tanımları `TypealiasExamples.swift` içinde. Kendi `NavigationStack`'ini içermez.
struct TypealiasDemoView: View {
    private typealias ID = AccessibilityID.Fundamentals.Typealias
    private typealias Examples = TypealiasExamples

    @State private var filterName = Examples.filters[0].id

    var body: some View {
        List {
            closureSection
            compositionSection
            genericSection
            associatedTypeSection
            longGenericSection
            pitfallSection
        }
        .accessibilityIdentifier(ID.list)
        .navigationTitle("typealias")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Bölümler

    private var closureSection: some View {
        let filter = Examples.filters.first { $0.id == filterName } ?? Examples.filters[0]
        let titles = Examples.titles(of: Examples.sampleBooks, matching: filter.matches)

        return Section {
            code("typealias BookFilter = @Sendable (Book) -> Bool")
            Picker("Süzgeç", selection: $filterName) {
                ForEach(Examples.filters) { filter in
                    Text(filter.id).tag(filter.id)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(ID.filterPicker)
            Text(verbatim: "\(titles.count) kitap: \(titles.joined(separator: ", "))")
                .font(.callout)
                .accessibilityIdentifier(ID.filterResult)
        } header: {
            sectionTitle("1. Closure tipine isim")
        } footer: {
            Text("Her imzada uzun closure tipini tekrar yazmak yerine bir isim: Hem kısalır hem ne işe yaradığını anlatır.")
        }
    }

    private var compositionSection: some View {
        Section {
            code("public typealias Codable = Decodable & Encodable   // Swift'in kendisi")
            code("typealias ShelfItem = ReadingItem & Identifiable")
            code("func identifiers<Item: ShelfItem>(of items: [Item])")
        } header: {
            sectionTitle("2. Protocol birleşimine isim")
        } footer: {
            Text("Codable diye ayrı bir protocol yok: İki protocol'ün birleşimine verilmiş bir isim.")
        }
    }

    private var genericSection: some View {
        Section {
            code("typealias BookMap<Value> = [Book.ID: Value]")
            Text(verbatim: "BookMap<String> aslında: \(Examples.typeName(of: Examples.BookMap<String>.self))")
                .accessibilityIdentifier(ID.genericAliasType)
        } header: {
            sectionTitle("3. Generic alias")
        }
    }

    private var associatedTypeSection: some View {
        Section {
            code("struct ClassicsShelf: Shelf {\n    typealias Item = Novel\n    ...\n}")
            Text(verbatim: "ClassicsShelf.Item: \(Examples.typeName(of: Examples.ClassicsShelf.Item.self))")
                .accessibilityIdentifier(ID.associatedTypeResult)
        } header: {
            sectionTitle("4. associatedtype'ı karşılamak")
        } footer: {
            Text("Çoğu zaman derleyici bunu add(_ item: Novel) imzasından kendisi çıkarır; açık typealias okunabilirlik içindir.")
        }
    }

    private var longGenericSection: some View {
        Section {
            code("typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Book>")
            Text(verbatim: "Snapshot aslında: \(Examples.typeName(of: FavoritesViewController.Snapshot.self))")
                .accessibilityIdentifier(ID.snapshotType)
        } header: {
            sectionTitle("5. Uzun generic tipi kısaltmak")
        } footer: {
            Text("Gerçek kullanım: FavoritesViewController'daki Snapshot ve DataSource.")
        }
    }

    private var pitfallSection: some View {
        Section {
            code("typealias BookID = Int\ntypealias MemberID = Int\nlet book: BookID = member   // derlenir!")
            Text(verbatim: "BookID aslında: \(Examples.typeName(of: Examples.BookID.self))")
                .accessibilityIdentifier(ID.bookIDUnderlyingType)
            Text(verbatim: "BookID ile MemberID aynı tip mi? \(yesNo(Examples.BookID.self == Examples.MemberID.self))")
                .accessibilityIdentifier(ID.aliasesAreSameType)

            code("struct LibraryCardNumber { let rawValue: Int }\nlookUpCard(42)")
            Text(verbatim: "error: cannot convert value of type 'Int' to expected argument type 'LibraryCardNumber'")
                .font(.caption.monospaced())
                .foregroundStyle(.red)
            Text(verbatim: "LibraryCardNumber ile Int aynı tip mi? \(yesNo(Examples.LibraryCardNumber.self == Int.self))")
                .accessibilityIdentifier(ID.wrapperIsDistinctType)
        } header: {
            sectionTitle("Tuzak: yeni bir tip DEĞİL")
        } footer: {
            Text("""
            typealias yalnızca bir takma addır; BookID ve MemberID'yi karıştırırsan derleyici uyarmaz. Tip güvenliği \
            istiyorsan tek alanlı bir sarmalayıcı struct yaz: Ayrı bir tiptir, karıştırmak derleme hatasıdır ve bellekte \
            içindeki Int kadar (8 bayt) yer kaplar.
            """)
        }
    }

    // MARK: - Yardımcılar

    private func code(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.footnote.monospaced())
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .textCase(nil)
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Evet" : "Hayır"
    }
}

#Preview {
    NavigationStack {
        TypealiasDemoView()
    }
}
