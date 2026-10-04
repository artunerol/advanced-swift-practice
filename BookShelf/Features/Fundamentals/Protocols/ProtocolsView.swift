import SwiftUI

/// Protocol'leri üç bölümde gösteren ekran:
/// - **Liste:** Farklı tiplerden oluşan `[any ReadingItem]`, sıralama ve toplam süre.
/// - **Raf:** `associatedtype`'lı `Shelf` protocol'ü, generic `ReadingShelf<Novel>` ve `Comparable` ile sıralama.
/// - **Dispatch:** Gereksinim ile extension'a özel üye arasındaki fark ve protocol ile bağımlılık enjeksiyonu.
///
/// Kendi `NavigationStack`'ini içermez; Mülakat merkezindeki konu ekranının (`InterviewTopicScreen`) içinde gösterilir.
struct ProtocolsView: View {
    enum Experiment: CaseIterable, Identifiable {
        case list, shelf, dispatch

        var id: Self { self }

        var label: String {
            switch self {
            case .list: AccessibilityID.Fundamentals.Protocols.listSegment
            case .shelf: AccessibilityID.Fundamentals.Protocols.shelfSegment
            case .dispatch: AccessibilityID.Fundamentals.Protocols.dispatchSegment
            }
        }
    }

    private typealias ID = AccessibilityID.Fundamentals.Protocols

    @State private var experiment: Experiment = .list
    @State private var sortOrder: ReadingSortOrder = .title
    @State private var shelf = ReadingShelf<Novel>()
    /// Bir sonraki "Rafa roman ekle" dokunuşunda denenecek romanın sırası. Tüm romanlar eklendikten sonra
    /// başa döner; böylece aynı romanı tekrar eklemeye çalışıp rafın bunu reddettiğini görebilirsin.
    @State private var nextNovelIndex = 0
    @State private var shelfMessage: String?

    var body: some View {
        List {
            Section {
                Picker("Bölüm", selection: $experiment) {
                    ForEach(Experiment.allCases) { experiment in
                        Text(experiment.label).tag(experiment)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(ID.experimentPicker)
            }

            switch experiment {
            case .list: listSections
            case .shelf: shelfSections
            case .dispatch: dispatchSections
            }
        }
        .navigationTitle("Protocol'ler")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Liste: [any ReadingItem]

    @ViewBuilder
    private var listSections: some View {
        // Her çizimde yeniden sıralamak burada sorun değil: 4 öğe var. Büyük listelerde sonucu saklardık.
        let items = sortOrder.sorted(ReadingSamples.mixedItems)

        Section {
            Picker("Sırala", selection: $sortOrder) {
                ForEach(ReadingSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(ID.sortPicker)

            // `any ReadingItem` `Identifiable` değil; satırları sıradaki konumlarıyla (index) ayırt ediyoruz.
            // Konuma göre kimlik UI testleri için de kullanışlı: "0. satırın başlığı X mi?"
            ForEach(items.indices, id: \.self) { index in
                readingRow(items[index], index: index)
            }

            Text(verbatim: "Toplam: \(formattedReadingDuration(minutes: totalReadingMinutes(ofMixed: items)))")
                .bold()
                .accessibilityIdentifier(ID.mixedTotal)
        } header: {
            Text("[any ReadingItem] — karışık liste")
                .textCase(nil)
        } footer: {
            Text("""
            Roman ve Kitap struct, Dergi struct, Sesli kitap ise final class; hepsi ReadingItem'a uyduğu için tek dizide duruyor. \
            Her eleman bir existential kutu (any): Tipi çalışma anında belli olur, çağrılar dinamik çözülür. \
            Toplam bu yüzden totalReadingMinutes(ofMixed:) ile hesaplanıyor; generic sürüm [any ReadingItem] kabul etmez.
            """)
        }
    }

    private func readingRow(_ item: any ReadingItem, index: Int) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(item.title)
                        .accessibilityIdentifier(ID.rowTitle(index: index))
                    Text(item.kindName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: item.symbolName)
            }
            Spacer()
            Text(item.formattedDuration)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(ID.rowDuration(index: index))
        }
    }

    // MARK: - Raf: associatedtype + generic

    @ViewBuilder
    private var shelfSections: some View {
        Section {
            Button("Rafa roman ekle", action: addNextNovel)
                .accessibilityIdentifier(ID.shelfAddButton)
            Text(verbatim: "Raftaki roman: \(shelf.items.count)")
                .accessibilityIdentifier(ID.shelfCount)
            Text(verbatim: "Raf toplamı: \(formattedReadingDuration(minutes: shelf.totalMinutes))")
                .accessibilityIdentifier(ID.shelfTotal)
            if let shelfMessage {
                Text(shelfMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(ID.shelfMessage)
            }
        } header: {
            Text("ReadingShelf<Novel>")
                .textCase(nil)
        } footer: {
            Text("""
            Shelf protocol'ünün associatedtype'ı var: Her raf tek bir tür tutar. ReadingShelf generic bir struct; \
            Item: ReadingItem & Identifiable kısıtı sayesinde aynı romanı iki kez eklemez. \
            Toplam süre generic totalReadingMinutes(of:) ile hesaplanır.
            """)
        }

        if !shelf.isEmpty {
            Section {
                // `sortedItems` yalnızca `Item: Comparable` olduğunda var (koşullu extension). `Novel` Comparable.
                ForEach(Array(shelf.sortedItems.enumerated()), id: \.element.id) { index, novel in
                    Text(novel.description)
                        .accessibilityIdentifier(ID.shelfRowTitle(index: index))
                }
            } header: {
                Text("Başlığa göre sıralı (Comparable)")
                    .textCase(nil)
            }
        }
    }

    private func addNextNovel() {
        let novels = ReadingSamples.shelfNovels
        let novel = novels[nextNovelIndex % novels.count]
        nextNovelIndex += 1
        // `"\(novel)"` → `CustomStringConvertible.description` kullanılır.
        shelfMessage = shelf.add(novel)
            ? "Eklendi: \(novel)"
            : "Zaten rafta, eklenmedi: \(novel)"
    }

    // MARK: - Dispatch

    @ViewBuilder
    private var dispatchSections: some View {
        Section {
            Text(verbatim: "Magazine olarak: \(ProtocolDispatchDemo.viaConcreteType)")
                .accessibilityIdentifier(ID.dispatchConcrete)
            Text(verbatim: "any ReadingItem olarak: \(ProtocolDispatchDemo.viaExistential)")
                .accessibilityIdentifier(ID.dispatchExistential)
            Text(verbatim: "Generic (some) içinde: \(ProtocolDispatchDemo.viaGeneric)")
                .accessibilityIdentifier(ID.dispatchGeneric)
            Text(verbatim: "Gereksinim, any üzerinden: \(ProtocolDispatchDemo.requirementViaExistential)")
                .accessibilityIdentifier(ID.dispatchRequirement)
        } header: {
            Text("Aynı dergi, dört farklı okuma")
                .textCase(nil)
        } footer: {
            Text("""
            shelfSection protokolde gereksinim değil, yalnızca extension'da var: Hangi uygulamanın çalışacağına derleme anındaki tip karar verir (statik dispatch). \
            Magazine'in kendi shelfSection'ı sadece değişkenin tipi Magazine iken görünür. symbolName ise gereksinim; her yerden Magazine'in değeri gelir (dinamik dispatch). \
            Kural: Tiplerin özelleştirmesini istediğin her şeyi gereksinim olarak tanımla.
            """)
        }

        Section {
            Text("""
            Kitaplar ekranı somut LocalBookService'e değil, BookServiceProtocol'e bağlı. \
            Uygulamada gerçek servis, testlerde ise anında cevap veren ya da bilerek hata fırlatan StubBookService verilir. \
            Ekran kodu hiç değişmez; çağrılar dinamik dispatch ile o an verilen tipe gider.
            """)
            .font(.callout)
        } header: {
            Text("Protocol ile bağımlılık enjeksiyonu")
                .textCase(nil)
        }
    }
}

#Preview {
    NavigationStack {
        ProtocolsView()
    }
}
