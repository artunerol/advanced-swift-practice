import Foundation

extension InterviewTopic {
    /// Merkezde gösterilen tüm konular, ekrandaki sırayla. Bölüm başlıkları `section` alanından gelir.
    static let all: [InterviewTopic] = [
        .protocolExtension,
        .protocolAsType,
        .structVsClass,
        .typealiasTopic,
        .arcRetainCycle,
        .vcLifecycle,
        .dynamicCells,
        .frameVsBounds,
        .tableVsCollection,
        .delegate,
        .architecture,
        .dipVsDi,
        .persistence,
        .cicd,
        .concurrency,
        .objcInterop,
    ]
}
