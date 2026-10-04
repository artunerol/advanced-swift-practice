import SwiftUI

/// "Karşılaştır" bölümü: `StorageComparisonItem.all` tablosu. Telefon ekranında geniş bir tablo okunmaz; bu yüzden her
/// seçenek açılır kapanır bir satır (`DisclosureGroup`): kapalıyken "ne için?", açınca altı eksenin hepsi.
struct StorageComparisonSections: View {
    var body: some View {
        Section {
            ForEach(StorageComparisonItem.all) { option in
                DisclosureGroup {
                    StorageComparisonDetail(title: "Boyut", text: option.capacity)
                    StorageComparisonDetail(title: "Thread güvenliği", text: option.threading)
                    StorageComparisonDetail(title: "Şifreleme", text: option.encryption)
                    StorageComparisonDetail(title: "Sorgu", text: option.querying)
                    StorageComparisonDetail(title: "Şema değişince", text: option.migration)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.name)
                            .font(.headline)
                        Text(option.useCase)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Persistence.comparisonRow(option.id))
            }
        } header: {
            Text("Hangisi ne zaman?")
                .textCase(nil)
        } footer: {
            Text("Kural: Önce verinin türüne bak (tercih mi, sır mı, belge mi, sorgulanan bir grafik mi, önbellek mi), sonra boyutuna.")
        }
    }
}

/// Açılan satırdaki tek bir eksen: başlık + açıklama.
private struct StorageComparisonDetail: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
        }
        .accessibilityElement(children: .combine)
    }
}
