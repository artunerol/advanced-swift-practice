import SwiftUI

/// Kitap listesindeki tek bir satır.
///
/// Durumu yoktur (stateless): gösterdiği her şey dışarıdan parametre olarak gelir. Bu tür küçük,
/// "aptal" (dumb) view'ler hem önizlemede hem yeniden kullanımda en kolay parçalardır.
///
/// Ad neden `BookRow` değil de `BookListRow`? Tüm özellikler aynı modülde (uygulama hedefi) derleniyor;
/// başka bir ekranın da `BookRow` adında bir tip tanımlaması derleme hatası olurdu.
struct BookListRow: View {
    let book: Book
    let isFavorite: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                // `String(book.year)` bilinçli: `Text("\(book.year)")` yazsaydık SwiftUI sayıyı cihaz diline
                // göre biçimlendirirdi ve Türkçe'de "1.972" gibi binlik ayırıcılı bir yıl görürdük.
                Text("\(book.author) · \(String(book.year))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if isFavorite {
                // Görsel bir işaret. VoiceOver ve UI testleri için favori bilgisi satırın
                // `accessibilityValue`'sunda (BookListView), bu yüzden resmi erişilebilirlikten gizliyoruz.
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        BookListRow(
            book: Book(id: 1, title: "Tutunamayanlar", author: "Oğuz Atay", year: 1972,
                       isbn: "978-605-000-001-6", pageCount: 724, summary: ""),
            isFavorite: true
        )
        BookListRow(
            book: Book(id: 2, title: "Kürk Mantolu Madonna", author: "Sabahattin Ali", year: 1943,
                       isbn: "978-605-000-002-3", pageCount: 160, summary: ""),
            isFavorite: false
        )
    }
}
