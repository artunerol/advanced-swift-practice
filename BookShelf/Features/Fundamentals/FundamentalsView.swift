import SwiftUI

/// "Temeller" sekmesinin giriş ekranı: dil temellerini gösteren üç deneye bağlantı.
///
/// Bu view kendi `NavigationStack`'ine sahip. Alt ekranlar (`StructVsClassView`, `ProtocolsView`,
/// `ISBNCheckerView`) ise kendi yığınlarını içermez; buraya push edilir. Kural: Bir sekmede tek bir
/// `NavigationStack` olur ve onu sekmenin kök ekranı sahiplenir. İç içe yığınlar gezinmeyi bozar.
struct FundamentalsView: View {
    private typealias ID = AccessibilityID.Fundamentals

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        StructVsClassView()
                    } label: {
                        topicLabel(
                            title: "Struct vs Class",
                            subtitle: "Değer ve referans semantiği, copy-on-write, ARC",
                            systemImage: "square.on.square"
                        )
                    }
                    .accessibilityIdentifier(ID.structVsClassLink)

                    NavigationLink {
                        ProtocolsView()
                    } label: {
                        topicLabel(
                            title: "Protocol'ler",
                            subtitle: "Varsayılan uygulamalar, some vs any, associatedtype",
                            systemImage: "puzzlepiece.extension"
                        )
                    }
                    .accessibilityIdentifier(ID.protocolsLink)

                    NavigationLink {
                        ISBNCheckerView()
                    } label: {
                        topicLabel(
                            title: "Objective-C: ISBN Doğrulayıcı",
                            subtitle: "Bridging header, NSError → throws, nullability",
                            systemImage: "barcode.viewfinder"
                        )
                    }
                    .accessibilityIdentifier(ID.isbnCheckerLink)
                } footer: {
                    Text("Her ekranın ayrıntılı anlatımı docs/ klasöründeki derslerde.")
                }
            }
            .navigationTitle("Temeller")
        }
    }

    private func topicLabel(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

#Preview {
    FundamentalsView()
}
