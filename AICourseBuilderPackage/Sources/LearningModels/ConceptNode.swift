import Foundation
import SQLiteData

/// One node in the program's concept graph — e.g. "type signatures",
/// "pattern matching", "algebraic data types". Used by `AdaptationEngine`
/// to decide review priority and dependency-aware sequencing.
///
/// `prerequisitesJSON` carries the dependency edges as a JSON array of
/// stringified `ConceptNode.id`s. Stored inline rather than as a separate
/// edges table because (a) the graph is small (tens to low-hundreds of
/// nodes per program), (b) it's read all-at-once during planning, and
/// (c) avoiding a join keeps `@FetchAll` queries simple.
@Table
public struct ConceptNode: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var programID: ProgramBlueprint.ID
    public var title: String = ""
    public var prerequisitesJSON: String = "[]"
    public var createdAt: Date = Date()
}

extension ConceptNode {
    /// Decode `prerequisitesJSON` into UUIDs. Returns empty on failure —
    /// adaptation degrades to "no known prereqs" rather than crashing.
    public var prerequisites: [UUID] {
        guard let data = prerequisitesJSON.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return strings.compactMap(UUID.init(uuidString:))
    }

    public static func encodePrerequisites(_ ids: [UUID]) -> String {
        let strings = ids.map { $0.uuidString }
        guard let data = try? JSONEncoder().encode(strings),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }
}
