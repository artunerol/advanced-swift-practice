import SwiftUI
import UIKit

/// Konu ekranının "Kod" bölümü: "Bu projede nerede?" sorusunun cevabı.
///
/// Mülakatta "bunu gerçek bir projede nasıl kullandın?" sorusu çok gelir. Her yönlendirme bir dosyayı, o dosyada
/// bakılacak sembolü ve neye dikkat edileceğini söyler. Dosya adını kopyalayıp Xcode'da hemen açabilirsin.
struct TopicCodePane: View {
    private typealias ID = AccessibilityID.Interview

    let pointers: [InterviewTopic.CodePointer]

    /// Son kopyalanan satır. Simgesi kısa bir süre "✓" olur; geri bildirim için.
    @State private var copiedIndex: Int?

    var body: some View {
        List {
            Section {
                if pointers.isEmpty {
                    Text("Bu konu için henüz kod yönlendirmesi yok.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(pointers.enumerated()), id: \.offset) { index, pointer in
                    row(pointer, index: index)
                }
            } header: {
                Text("Projede bak")
            } footer: {
                Text("Kopyala düğmesi dosya adını panoya alır; simülatörün panosu Mac'inkiyle eşitlenir. Xcode'da Cmd+Shift+O ile dosya adını yapıştır ve Enter'a bas. Dosya açılınca Ctrl+6 ile sembolü ara. Satıra uzun basarak sembolü ya da tam yolu da kopyalayabilirsin.")
                    .accessibilityIdentifier(ID.codeHint)
            }
        }
        .accessibilityIdentifier(ID.codeList)
        // Kopyalandı işareti 2 sn sonra kaybolur. `.task(id:)` her `copiedIndex` değişiminde öncekini İPTAL edip
        // yeniden başlar: Art arda iki satır kopyalanırsa ilk zamanlayıcı ikinci işareti silemez.
        // View kaybolunca task da otomatik iptal edilir (yapılandırılmış concurrency).
        .task(id: copiedIndex) {
            guard copiedIndex != nil else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                copiedIndex = nil
            } catch {
                // İptal edildi: yerine yeni bir kopyalama geldi ya da ekran kapandı. Yapılacak bir şey yok.
            }
        }
    }

    private func row(_ pointer: InterviewTopic.CodePointer, index: Int) -> some View {
        let isCopied = copiedIndex == index
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pointer.symbol)
                    .font(.body.monospaced().weight(.semibold))
                Text(pointer.file)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(interviewMarkdown: pointer.note)
                    .font(.callout)
            }
            // Üç metni tek bir erişilebilirlik öğesinde birleştiriyoruz: VoiceOver satırı tek seferde okur,
            // UI testi de satırı tek bir kimlikle bulur.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(ID.codePointer(index))

            Spacer(minLength: 0)

            Button {
                copy(pointer.fileName, index: index)
            } label: {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            // Liste satırındaki düğme varsayılan stille TÜM satırı dokunulabilir yapar. `.borderless` dokunma
            // alanını düğmenin kendisiyle sınırlar.
            .buttonStyle(.borderless)
            .accessibilityLabel(isCopied ? "Kopyalandı" : "Dosya adını kopyala: \(pointer.fileName)")
            .accessibilityIdentifier(ID.copyFileNameButton(index))
        }
        .contextMenu {
            Button("Dosya adını kopyala", systemImage: "doc.on.doc") { copy(pointer.fileName, index: index) }
            Button("Sembolü kopyala", systemImage: "curlybraces") { copy(pointer.symbol, index: index) }
            Button("Tam yolu kopyala", systemImage: "folder") { copy(pointer.file, index: index) }
        }
    }

    private func copy(_ text: String, index: Int) {
        UIPasteboard.general.string = text
        copiedIndex = index
    }
}

extension InterviewTopic.CodePointer {
    /// Yolun son parçası: "BookShelf/Core/Stores/FavoritesStore.swift" → "FavoritesStore.swift".
    /// Xcode'un Open Quickly (Cmd+Shift+O) penceresi dosyayı en hızlı bu adla bulur.
    var fileName: String {
        file.split(separator: "/").last.map(String.init) ?? file
    }
}

#Preview {
    NavigationStack {
        TopicCodePane(pointers: InterviewTopic.concurrency.codePointers)
    }
}
