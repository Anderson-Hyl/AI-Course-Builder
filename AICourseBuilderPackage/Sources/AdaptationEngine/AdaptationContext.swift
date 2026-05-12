import Foundation
import LearningModels

/// In-memory snapshot of everything `AdaptationPrompt` needs to format
/// the LLM call. Composed by `AdaptationEngine.adapt` from a sequence
/// of repository fetches; nothing here is persisted on its own — the
/// prompt builder reads it once and the proposal applier never sees
/// it again. Kept value-typed and Sendable so it crosses concurrency
/// boundaries cleanly.
struct AdaptationContext: Sendable {
    let session: Session
    let sprint: Sprint
    let stage: Stage
    let program: ProgramBlueprint
    let goal: LearningGoal
    let profile: LearnerProfile
    /// Blocks for `session`, in order. `payloadJSON` is included verbatim
    /// so the prompt can show the model the exact text the learner saw.
    let blocks: [SessionBlock]
    /// Latest attempt per block. Missing entries mean the learner skipped
    /// (or the block was non-interactive); the prompt formats those as
    /// "no attempt".
    let attempts: [SessionBlock.ID: Attempt]
    /// Existing concept titles in this program — gives the LLM a hint
    /// about what's already in the graph so it picks consistent titles
    /// across sessions instead of inventing near-duplicates ("Pure
    /// functions" vs "Pure function" vs "Purity in functions").
    let knownConceptTitles: [String]
}
