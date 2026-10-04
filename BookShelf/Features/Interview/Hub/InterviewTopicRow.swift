import SwiftUI

/// Merkez listesindeki bir konu satırının görünümü: simge, soru, demo ipucu ve "çalışıldı" işareti.
///
/// Yalnızca görünüm; dokunma ve gezinme `InterviewHubView`'daki `NavigationLink`'te. Böylece satır,
/// Preview'da ve başka listelerde de aynen kullanılabilir.
struct InterviewTopicRow: View {
    let topic: InterviewTopic
    let isStudied: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: topic.hubInfo.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(topic.question)
                Text(topic.hubInfo.demoHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isStudied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    // Durum, satırın erişilebilirlik değeriyle ("Çalışıldı") söyleniyor; simgeyi ayrıca okutmuyoruz.
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    List {
        InterviewTopicRow(topic: .concurrency, isStudied: true)
        InterviewTopicRow(topic: .objcInterop, isStudied: false)
    }
}
