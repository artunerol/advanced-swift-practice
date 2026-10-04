import XCTest
@testable import BookShelf

/// `FavoritesState`'in saf (pure) mantığının testleri.
///
/// UIKit yok, bekleme yok, actor yok: girdi ver, çıktıyı kontrol et. Mantığı view controller'dan ayırmanın
/// ("Massive View Controller"dan kaçınmanın) en somut faydası bu testlerin bu kadar basit olabilmesi.
final class FavoritesStateTests: XCTestCase {

    func testFromCatalogKeepsCatalogOrderRegardlessOfSetOrder() {
        // `Set` literal'inin yazılış sırası ([3, 1]) bir anlam taşımaz; sonuç kataloğun sırasını izlemeli.
        let state = FavoritesState.from(catalog: Book.fixtures, favoriteIDs: [3, 1])

        XCTAssertEqual(state.books.map(\.id), [1, 3])
    }

    func testFromCatalogIgnoresIDsMissingFromCatalog() {
        let state = FavoritesState.from(catalog: Book.fixtures, favoriteIDs: [2, 99])

        XCTAssertEqual(state.books.map(\.id), [2])
    }

    func testLoadedWithoutFavoritesShowsEmptyMessageAndCannotClear() {
        let state = FavoritesState.from(catalog: Book.fixtures, favoriteIDs: [])

        XCTAssertEqual(state, .loaded([]))
        XCTAssertTrue(state.isLoaded)
        XCTAssertTrue(state.showsEmptyMessage)
        XCTAssertFalse(state.canClearAll)
        XCTAssertNil(state.errorMessage)
    }

    func testLoadedWithFavoritesHidesEmptyMessageAndCanClear() {
        let state = FavoritesState.from(catalog: Book.fixtures, favoriteIDs: [2])

        XCTAssertFalse(state.showsEmptyMessage)
        XCTAssertTrue(state.canClearAll)
    }

    func testLoadingStateDoesNotClaimTheListIsEmpty() {
        // Yüklenirken "henüz favorin yok" demek yanlış olurdu; belki favorin var ama henüz gelmedi.
        let state = FavoritesState.loading

        XCTAssertTrue(state.isLoading)
        XCTAssertFalse(state.isLoaded)
        XCTAssertFalse(state.showsEmptyMessage)
        XCTAssertFalse(state.canClearAll)
        XCTAssertEqual(state.books, [])
    }

    func testFailedStateExposesMessageAndNoBooks() {
        let state = FavoritesState.failed(message: "Bağlantı yok")

        XCTAssertEqual(state.errorMessage, "Bağlantı yok")
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.showsEmptyMessage)
        XCTAssertEqual(state.books, [])
    }
}
