import Foundation

enum HomeSelectors {
    static let categoryTilePrefix = "id_category_tile_"
    static let categoryTilePredicate = NSPredicate(
        format: "identifier BEGINSWITH '\(categoryTilePrefix)'"
    )
}
