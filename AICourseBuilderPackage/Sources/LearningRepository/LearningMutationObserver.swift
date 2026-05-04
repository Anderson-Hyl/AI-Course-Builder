import Dependencies
import Foundation

/// Host-side hooks `LearningRepository` fires after a mutation commits. Lets
/// UI layers — the `AppFeature` reducer, dashboard widgets, the tutor panel
/// — react to learning-state writes that originated ANYWHERE: engine calls
/// (Planning / Evaluation / Adaptation / Tutor), UI handlers, future MCP /
/// CLI tool calls, or test harnesses.
///
/// Wired through `@Dependency` so every `LearningRepository` instance picks
/// up the same observer without parameter threading. Default is a no-op so
/// tests, smoke harnesses, and anything that instantiates a repository in
/// isolation just works.
///
/// **Discipline**: every mutation method on `LearningRepository` MUST fire
/// the appropriate hook AFTER the DB write commits. Default-impl new
/// protocol methods so `NoOpLearningMutationObserver` keeps compiling
/// without forcing every host to opt in.
public protocol LearningMutationObserver: Sendable {
    /// A new `LearningGoal` was persisted. Host typically transitions
    /// the root view from Goal Intake to a placeholder Home until the
    /// real Home Dashboard ships.
    func didCreateGoal(_ id: UUID) async

    /// An existing `LearningGoal` was deleted. Host typically returns
    /// the user to Goal Intake (Reset action this pass; future passes
    /// might surface "pick another goal" instead).
    func didDeleteGoal(_ id: UUID) async

    /// A new `ProgramBlueprint` finished generating. Default no-op.
    func didCreateProgram(_ id: UUID, goalID: UUID) async

    /// One or more sessions in a program changed (created, reordered,
    /// status updated). Default no-op.
    func didChangeSessions(programID: UUID) async

    /// A new attempt was recorded. Default no-op — `EvaluationEngine`
    /// owns the immediate scoring path; this hook is for UI signals
    /// like "tutor reviewing your answer".
    func didRecordAttempt(_ id: UUID, blockID: UUID) async
}

extension LearningMutationObserver {
    public func didCreateProgram(_ id: UUID, goalID: UUID) async {}
    public func didChangeSessions(programID: UUID) async {}
    public func didRecordAttempt(_ id: UUID, blockID: UUID) async {}
}

public struct NoOpLearningMutationObserver: LearningMutationObserver {
    public init() {}
    public func didCreateGoal(_ id: UUID) async {}
    public func didDeleteGoal(_ id: UUID) async {}
}

private enum LearningMutationObserverKey: DependencyKey {
    static let liveValue: any LearningMutationObserver = NoOpLearningMutationObserver()
    static let testValue: any LearningMutationObserver = NoOpLearningMutationObserver()
}

extension DependencyValues {
    public var learningMutationObserver: any LearningMutationObserver {
        get { self[LearningMutationObserverKey.self] }
        set { self[LearningMutationObserverKey.self] = newValue }
    }
}
