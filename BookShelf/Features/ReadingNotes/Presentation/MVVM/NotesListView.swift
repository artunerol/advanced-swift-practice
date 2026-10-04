import SwiftUI

/// **MVVM → View.** Okuma notları listesinin SwiftUI hali: durumu `NotesListViewModel`'den okur, eylemleri ona iletir.
///
/// VIPER tarafındaki `NotesListViewController` ile aynı işi yapar (listele, ekle, kaydırarak sil, boş durum) ve
/// aynı use case'leri kullanır. Fark sadece sunum kalıbında.
///
/// Kendi `NavigationStack`'ini içermez: bir konu ekranının (zaten bir yığının içinde) parçası olarak gösterilir.
struct NotesListView: View {
    private typealias ID = AccessibilityID.ReadingNotes.MVVM

    /// `@State` burada **sahiplik** içindir: SwiftUI view model'i view'ın kimliği boyunca saklar.
    /// Değişiklik takibini `@Observable` sağlar.
    @State private var viewModel: NotesListViewModel
    /// Editörün açık olup olmadığı saf bir arayüz durumu; view model'e taşımaya gerek yok.
    @State private var isEditorPresented = false

    init(useCases: NotesUseCases, formatter: any NoteFormatter = DateNoteFormatter()) {
        _viewModel = State(initialValue: NotesListViewModel(useCases: useCases, formatter: formatter))
    }

    var body: some View {
        content
            .task { await viewModel.load() }
            .sheet(isPresented: $isEditorPresented) {
                NoteEditorSheet(viewModel: viewModel)
            }
            .alert("Not silinemedi", isPresented: isAlertPresented) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Notlar yükleniyor…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Notlar yüklenemedi", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Tekrar dene") { Task { await viewModel.load() } }
            }
        case .loaded(let rows):
            list(rows)
        }
    }

    private func list(_ rows: [NoteRow]) -> some View {
        List {
            Section {
                Button {
                    viewModel.startNewNote()
                    isEditorPresented = true
                } label: {
                    Label("Not ekle", systemImage: "plus")
                }
                .accessibilityIdentifier(ID.addButton)
            }

            if rows.isEmpty {
                emptyState
            } else {
                Section {
                    // Satır yüksekliği: SwiftUI `List` satırları içeriğe göre kendiliğinden boyutlanır;
                    // UIKit'teki `automaticDimension` ayarının karşılığına gerek yok.
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.text)
                            Text(row.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(
                                AccessibilityID.ReadingNotes.deleteActionTitle,
                                systemImage: "trash",
                                role: .destructive
                            ) {
                                Task { await viewModel.delete(row) }
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(ID.list)
    }

    /// Boş durum, listenin içinde bir bölüm: "Not ekle" düğmesi hep üstte ve dokunulabilir kalır.
    /// Metin VIPER tarafındaki boş durum mesajıyla aynı.
    private var emptyState: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Henüz not yok. İlk notunu eklemek için \"Not ekle\"ye dokun.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(ID.emptyState)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    /// `alertMessage` (String?) ile alert'in `Bool` bağlantısı arasındaki köprü. Kapatınca mesaj temizlenir.
    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.alertMessage = nil }
            }
        )
    }
}
