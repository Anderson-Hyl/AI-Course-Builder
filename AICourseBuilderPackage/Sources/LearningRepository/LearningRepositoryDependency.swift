import Dependencies

/// Dependency-injection key for `LearningRepository`. Lives in this
/// module (not in `AppFeature`) so engines and any consumer outside the
/// app feature target can resolve `@Dependency(\.learningRepository)`
/// without re-declaring the key.
private enum LearningRepositoryKey: DependencyKey {
    static let liveValue = LearningRepository()
    static let testValue = LearningRepository()
}

extension DependencyValues {
    public var learningRepository: LearningRepository {
        get { self[LearningRepositoryKey.self] }
        set { self[LearningRepositoryKey.self] = newValue }
    }
}
