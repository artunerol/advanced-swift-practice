import SwiftUI

/// "Notlar" bölümü: beş `NotesRepository` uygulaması, tek ekran. Mantık `NotesStorageInspector`'da.
struct NotesStorageInspectorSections: View {
    private typealias ID = AccessibilityID.Persistence

    /// Üst view'un `@State`'inde yaşayan `@Observable` model. Burada sadece okunuyor ve metotları çağrılıyor;
    /// bağlama (binding) gerekmediği için `@Bindable` değil, düz bir `let`.
    let inspector: NotesStorageInspector

    var body: some View {
        kindsSection
            // Bölüm göründüğünde sayıları yükle. Görev, her zaman ekranda olan ilk bölüme bağlı: `List` tembel
            // olduğu için alttaki bölümler kaydırılana kadar "görünmeyebilir". Bölümden çıkılınca SwiftUI görevi iptal eder.
            .task { await inspector.load() }
        selectedSection
        notesSection
    }

    // MARK: - Tür listesi (sayı + kalıcılık)

    private var kindsSection: some View {
        Section {
            ForEach(NotesStorageKind.allCases) { kind in
                Button {
                    Task { await inspector.select(kind) }
                } label: {
                    kindRow(kind)
                        // `.plain` stilde yalnızca çizilen kısım dokunulabilir olur; satırın tamamı dokunulsun.
                        .contentShape(Rectangle())
                }
                // `.plain`: List içindeki düğmeler bütün metni vurgu rengine (tint) boyar; satır bir tablo gibi okunsun.
                .buttonStyle(.plain)
                .disabled(inspector.isWorking)
                .accessibilityIdentifier(ID.kindRow(kind.rawValue))
                .accessibilityValue(kind == inspector.selectedKind ? "Seçili" : "")
            }
        } header: {
            Text("Aynı protokol, beş depo")
                .textCase(nil)
        } footer: {
            Text("Sağdaki sayı o depodaki not sayısı. Disk simgesi: veri diskte, uygulama kapanıp açılınca kalır. Çip simgesi: yalnızca bellekte.")
        }
    }

    private func kindRow(_ kind: NotesStorageKind) -> some View {
        HStack {
            Image(systemName: kind == inspector.selectedKind ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.storageTitle)
                    .foregroundStyle(.primary)
                Text(kind.storageDescription(in: inspector.location))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: kind.survivesRelaunch ? "internaldrive" : "memorychip")
                .foregroundStyle(.secondary)
                .accessibilityLabel(kind.survivesRelaunch ? "Kalıcı" : "Kalıcı değil")
            Text(inspector.counts[kind].map(String.init) ?? "–")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Seçili tür

    private var selectedSection: some View {
        let kind = inspector.selectedKind
        return Section {
            Text(verbatim: "Not sayısı: \(inspector.counts[kind] ?? 0)")
                .accessibilityIdentifier(ID.selectedCount)
            Text(verbatim: "Kapatıp açınca kalır mı? \(kind.survivesRelaunch ? "Evet" : "Hayır")")
                .accessibilityIdentifier(ID.selectedSurvivesRelaunch)

            Button("Örnek not ekle") {
                Task { await inspector.addSample() }
            }
            .accessibilityIdentifier(ID.addSampleButton)

            Button("Yeni örnekle yeniden aç") {
                Task { await inspector.reopen() }
            }
            .accessibilityIdentifier(ID.reopenButton)

            Button("Bu depodaki notları sil", role: .destructive) {
                Task { await inspector.deleteAll() }
            }
            .accessibilityIdentifier(ID.deleteAllButton)

            if let message = inspector.message {
                Text(verbatim: message)
                    .font(.callout)
                    .accessibilityIdentifier(ID.notesMessage)
            }
        } header: {
            Text(verbatim: "Seçili: \(kind.storageTitle)")
                .textCase(nil)
        } footer: {
            Text("""
            "Yeniden aç" aynı depoya YENİ bir repository örneğiyle bağlanıp tekrar okur: uygulamayı kapatıp açmanın \
            küçük bir benzetimi. Bu ekranın kodu yalnızca `any NotesRepository` görür; hangi sınıfın oluşturulacağına \
            NotesRepositoryFactory karar verir.
            """)
        }
        .disabled(inspector.isWorking)
    }

    // MARK: - Notlar

    private var notesSection: some View {
        Section("Depodaki notlar (en yeni üstte)") {
            if inspector.selectedNotes.isEmpty {
                Text("Henüz not yok.")
                    .foregroundStyle(.secondary)
            }
            ForEach(inspector.selectedNotes) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.text)
                    Text(note.createdAt, format: .dateTime.hour().minute().second())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
