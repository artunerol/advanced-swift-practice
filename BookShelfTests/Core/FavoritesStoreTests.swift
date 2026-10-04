import XCTest
@testable import BookShelf

/// `FavoritesStore` actor'ünün testleri.
///
/// Actor'ün her metodu dışarıdan `await` ile çağrılır; bu yüzden test metotları `async`.
/// `XCTAssertEqual(await ...)` yazamayız (XCTest'in doğrulama fonksiyonları senkron autoclosure alır);
/// önce değeri bir sabite alıp sonra doğruluyoruz.
final class FavoritesStoreTests: XCTestCase {
    // MARK: - Temel işlemler

    func testStartsWithInitialFavorites() async {
        let emptyStore = FavoritesStore()
        let seededStore = FavoritesStore(initialFavorites: [2, 4])

        let emptyIDs = await emptyStore.allIDs
        let seededIDs = await seededStore.allIDs
        XCTAssertEqual(emptyIDs, [])
        XCTAssertEqual(seededIDs, [2, 4])
    }

    func testToggleAddsThenRemovesAndReturnsNewState() async {
        let store = FavoritesStore()

        let afterFirstToggle = await store.toggle(7)
        let containsAfterFirst = await store.contains(7)
        let afterSecondToggle = await store.toggle(7)
        let containsAfterSecond = await store.contains(7)

        XCTAssertTrue(afterFirstToggle, "İlk toggle favoriye eklemeli ve true döndürmeli.")
        XCTAssertTrue(containsAfterFirst)
        XCTAssertFalse(afterSecondToggle, "İkinci toggle favoriden çıkarmalı ve false döndürmeli.")
        XCTAssertFalse(containsAfterSecond)
    }

    func testAddIsIdempotentAndRemoveDeletes() async {
        let store = FavoritesStore()

        await store.add(1)
        await store.add(1)
        await store.add(2)
        let afterAdds = await store.allIDs
        await store.remove(1)
        await store.remove(99) // Olmayan id'yi silmek sorun çıkarmamalı.
        let afterRemove = await store.allIDs

        XCTAssertEqual(afterAdds, [1, 2])
        XCTAssertEqual(afterRemove, [2])
    }

    func testContainsReflectsCurrentState() async {
        let store = FavoritesStore(initialFavorites: [3])

        let containsThree = await store.contains(3)
        let containsFour = await store.contains(4)

        XCTAssertTrue(containsThree)
        XCTAssertFalse(containsFour)
    }

    // MARK: - Eşzamanlılık

    /// 1000 farklı id'yi 1000 eşzamanlı child task'tan ekliyoruz. Actor erişimleri sıraya koyduğu için hiçbiri kaybolmaz.
    /// (Aynı şeyi kilitsiz bir `class` içindeki `Set` ile yapsaydık data race olurdu; `Set` çökebilirdi bile.)
    func testConcurrentAddsFromManyTasksAreAllRecorded() async {
        let store = FavoritesStore()

        await withTaskGroup(of: Void.self) { group in
            for id in 1...1000 {
                group.addTask { await store.add(id) }
            }
        }

        let allIDs = await store.allIDs
        XCTAssertEqual(allIDs, Set(1...1000))
    }

    /// `toggle` içinde oku-karar ver-yaz adımları arasında `await` yok; yani her toggle atomik.
    /// Aynı id'yi eşzamanlı olarak ÇİFT sayıda toggle edersek başlangıç durumuna dönmeliyiz.
    func testConcurrentTogglesAreAtomic() async {
        let store = FavoritesStore()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<1000 {
                group.addTask { await store.toggle(42) }
            }
        }

        let isFavorite = await store.contains(42)
        XCTAssertFalse(isFavorite, "1000 (çift sayıda) toggle sonunda favori olmamalı.")
    }

    // MARK: - changes() akışı

    func testChangesYieldsCurrentSetImmediatelyThenEachChange() async {
        let store = FavoritesStore(initialFavorites: [3])
        var iterator = await store.changes().makeAsyncIterator()

        let initial = await iterator.next()
        XCTAssertEqual(initial, [3], "Abone olunca mevcut durum hemen gelmeli.")

        await store.add(5)
        let afterAdd = await iterator.next()
        XCTAssertEqual(afterAdd, [3, 5])

        await store.toggle(3)
        let afterToggle = await iterator.next()
        XCTAssertEqual(afterToggle, [5])

        await store.remove(5)
        let afterRemove = await iterator.next()
        XCTAssertEqual(afterRemove, [])
    }

    func testEverySubscriberReceivesChanges() async {
        let store = FavoritesStore()
        var first = await store.changes().makeAsyncIterator()
        var second = await store.changes().makeAsyncIterator()
        _ = await first.next() // Başlangıç değerlerini tüket.
        _ = await second.next()

        await store.add(8)

        let firstValue = await first.next()
        let secondValue = await second.next()
        XCTAssertEqual(firstValue, [8])
        XCTAssertEqual(secondValue, [8])
    }

    /// Dinleyen task iptal edilince akış biter (`for await` döngüsü sonlanır); store ise çalışmaya devam eder
    /// ve yeni aboneler yine değer alır.
    func testCancellingConsumerEndsItsLoopAndStoreKeepsWorking() async {
        let store = FavoritesStore()
        let firstValueReceived = expectation(description: "Tüketici ilk değeri aldı")

        let consumer = Task {
            var receivedCount = 0
            for await _ in await store.changes() {
                receivedCount += 1
                if receivedCount == 1 {
                    firstValueReceived.fulfill()
                }
            }
            // Döngü ancak akış bittiğinde (burada: task iptal edilince) sona erer.
            return receivedCount
        }

        await fulfillment(of: [firstValueReceived], timeout: 5)
        consumer.cancel()
        let receivedCount = await consumer.value // Döngü bitmeseydi test burada takılırdı.
        XCTAssertGreaterThanOrEqual(receivedCount, 1)

        // Store iptalden etkilenmemeli.
        let isFavorite = await store.toggle(11)
        XCTAssertTrue(isFavorite)

        var iterator = await store.changes().makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial, [11], "Yeni abone mevcut durumu hemen almalı.")

        await store.add(12)
        let afterAdd = await iterator.next()
        XCTAssertEqual(afterAdd, [11, 12], "Yeni abone sonraki değişiklikleri de almalı.")
    }
}
