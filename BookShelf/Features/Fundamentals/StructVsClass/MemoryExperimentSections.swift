import SwiftUI

/// "Struct vs Class" ekranının "Bellek" deneyi: adres karşılaştırmaları ve `MemoryLayout` tablosu.
///
/// `StructVsClassView`'un `List`'i içinde birkaç `Section` olarak çizilir. Kendi `@State`'i var: Bölüm seçicide
/// başka bir deneye geçip geri dönünce view yeniden oluşur ve adresler yeniden ölçülür.
struct MemoryExperimentSections: View {
    private typealias ID = AccessibilityID.Fundamentals.StructVsClass

    @State private var report = MemoryAddressReport.measure()

    var body: some View {
        Section {
            addressRow("struct · var copy = original", report.structCopies, verdictID: ID.structCopiesVerdict)
            addressRow("class · let copy = original", report.sharedReference, verdictID: ID.sharedReferenceVerdict)
            addressRow("class · içeriği aynı iki ayrı nesne", report.separateObjects, verdictID: ID.separateObjectsVerdict)
            Button("Yeniden ölç") {
                report = MemoryAddressReport.measure()
            }
            .accessibilityIdentifier(ID.remeasureButton)
        } header: {
            Text("Adresler: kopya mı, aynı nesne mi?")
                .textCase(nil)
        } footer: {
            Text("""
            Struct kopyası iki bağımsız değerdir: iki ayrı adres. Class'ta kopyalanan şey adrestir: iki değişken heap'teki \
            AYNI nesneyi gösterir (=== true). İçeriği aynı iki ayrı nesne ise == anlamında eşit olabilir, ama kimlikleri \
            (adresleri) farklıdır. Adreslerin kendisi her ölçümde değişir; değişmeyen, "aynı mı?" sorusunun cevabıdır.

            Adreslere dikkatli bak: Simülatörde yerel iki struct kopyası genelde yan yana (8 bayt arayla) durur, class \
            nesneleri ise bambaşka bir bölgede (heap). Bu bir gözlem, garanti değil: Swift depolama yerini garanti etmez.
            """)
        }

        Section {
            ForEach(MemoryLayoutDemo.rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(row.typeName)
                            .font(.subheadline.monospaced())
                        Spacer()
                        Text(verbatim: "size \(row.size) · stride \(row.stride)")
                            .font(.subheadline.monospacedDigit())
                            .accessibilityIdentifier(ID.layoutRow(row.id))
                    }
                    Text(row.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("MemoryLayout<T> — satır içi boyut (bayt, 64-bit)")
                .textCase(nil)
        } footer: {
            Text("""
            size: bir değerin kapladığı bayt; stride: dizide ardışık iki eleman arasındaki mesafe. Class referansı her \
            zaman 8 bayttır: Nesne ne kadar büyük olursa olsun değişkende yalnızca adresi durur.

            "Struct stack'te, class heap'te" yarım bir cevaptır. Struct değeri BULUNDUĞU YERDE saklanır: yerel değişkense \
            genelde stack'te ya da register'da; bir class'ın alanıysa o nesnenin içinde (heap); bir dizinin elemanıysa \
            dizinin heap'teki deposunda. Kaçan bir closure'ın yakaladığı var ve any kutusuna sığmayan değerler de heap'e \
            taşınır. Class örnekleri heap'te ayrılır ve referans sayılır: ayırma maliyeti, atomik retain/release ve dolaylı \
            erişim class'ı daha pahalı yapar. Swift'in garantisi depolama yeri değil, semantiktir.
            """)
        }
    }

    private func addressRow(_ title: String, _ comparison: AddressComparison, verdictID: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.monospaced())
            Text(verbatim: "\(AddressComparison.hex(comparison.first))  ·  \(AddressComparison.hex(comparison.second))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(verbatim: "Aynı adres mi? \(comparison.isSameAddress ? "Evet" : "Hayır")")
                .bold()
                .accessibilityIdentifier(verdictID)
        }
    }
}
