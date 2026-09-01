import Foundation
import SwiftData

/// `PersistentIdentifier` doesn't conform to `EntityIdentifierConvertible`, so App Intents
/// can't use it directly as an `AppEntity.ID`. Round-trip it through a `String` instead.
extension PersistentIdentifier {
    var appEntityID: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return data.base64EncodedString()
    }

    static func from(appEntityID: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: appEntityID) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }
}
