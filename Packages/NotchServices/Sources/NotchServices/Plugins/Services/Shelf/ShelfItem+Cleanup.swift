import Foundation
import NotchCore

public extension ShelfItem {
    @MainActor
    func cleanupStoredData(storage: any TemporaryFileStorageServiceProtocol) {
        guard case let .file(bookmarkData) = kind,
            let url = Bookmark(data: bookmarkData).resolvedURL
        else { return }

        // Handle temporary files
        if isTemporary {
            storage.removeTemporaryFileIfNeeded(at: url)
            return
        }
    }
}
