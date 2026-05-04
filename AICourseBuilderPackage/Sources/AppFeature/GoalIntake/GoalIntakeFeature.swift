import ComposableArchitecture
import Foundation
import LearningModels

/// Goal Intake form. Owns the form state and basic validation; the parent
/// `AppFeature` handles persistence in response to the `.delegate.submitTapped`
/// signal so the form stays focused on user input + render state.
@Reducer
public struct GoalIntakeFeature {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var goalText: String = ""
        public var startingLevel: String = LearnerProfile.StartingLevel.beginner
        public var weeklyTimeBudgetHours: Int = 5
        public var learningStyles: Set<String> = [
            LearnerProfile.LearningStyle.handsOn,
            LearnerProfile.LearningStyle.conceptual,
        ]
        public var targetOutcome: String = ""

        public init() {}

        /// Submit is disabled until the user gives the form *something*
        /// for the planner to anchor on. `goalText` is the only required
        /// field — every other field has a sensible default.
        public var canSubmit: Bool {
            !goalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case learningStyleToggled(String)
        case previewTapped
        case startLearningTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Form passed validation and the user committed. Parent
            /// `AppFeature` handles persistence + transition.
            case submitTapped
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .learningStyleToggled(let style):
                if state.learningStyles.contains(style) {
                    state.learningStyles.remove(style)
                } else {
                    state.learningStyles.insert(style)
                }
                return .none

            case .previewTapped:
                // Plan-preview is LLM-gated and ships with `PlanningEngine`
                // in the next pass. No-op for now — the button stays
                // visible so the affordance is in the muscle memory once
                // the real path arrives.
                return .none

            case .startLearningTapped:
                guard state.canSubmit else { return .none }
                return .send(.delegate(.submitTapped))

            case .delegate:
                return .none
            }
        }
    }
}
