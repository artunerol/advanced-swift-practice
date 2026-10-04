import SwiftUI

// GEÇİCİ İSKELET (çalışır durumda) — sahibi: hub. Görünümü geliştir; kimlikleri ve davranışı koru:
// - Liste kimliği AccessibilityID.Interview.hubList, her satır AccessibilityID.Interview.topicRow(topic.id)
// - Satıra dokununca InterviewTopicScreen push edilir.
struct InterviewHubView: View {
    let dependencies: AppDependencies

    var body: some View {
        NavigationStack {
            List {
                ForEach(InterviewTopic.Section.allCases, id: \.self) { section in
                    let topics = InterviewTopic.all.filter { $0.section == section }
                    if !topics.isEmpty {
                        Section(section.rawValue) {
                            ForEach(topics) { topic in
                                NavigationLink {
                                    InterviewTopicScreen(topic: topic, dependencies: dependencies)
                                } label: {
                                    Text(topic.question)
                                }
                                .accessibilityIdentifier(AccessibilityID.Interview.topicRow(topic.id))
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Interview.hubList)
            .navigationTitle(AccessibilityID.Tab.interview)
        }
    }
}
