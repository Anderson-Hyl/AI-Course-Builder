import Foundation
import SQLiteData

/// A discrete learner-facing capability — e.g. "read a type signature",
/// "write a recursive function". The competency graph describes what the
/// learner can DO, distinct from `ConceptNode` which tracks what they've
/// been EXPOSED TO. Per `AGENTS.md §Learning logic`, both are tracked
/// independently because exposure ≠ competence.
@Table
public struct Competency: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var programID: ProgramBlueprint.ID
    public var title: String = ""
    public var competencyDescription: String?
    public var createdAt: Date = Date()
}
