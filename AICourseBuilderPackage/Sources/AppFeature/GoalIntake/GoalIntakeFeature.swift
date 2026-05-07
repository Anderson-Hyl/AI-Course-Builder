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
        /// Header gear icon — opens the API key sheet via the parent.
        case gearTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// User tapped "Start Learning" — parent persists the goal
            /// and routes through full blueprint generation.
            case submitTapped
            /// User tapped "Preview Plan" — parent persists the goal
            /// and routes through the fast outline call before the
            /// Program Preview screen.
            case previewSubmitted
            /// User tapped the gear icon — parent presents the API key sheet.
            case openAPIKeySheet
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
                guard state.canSubmit else { return .none }
                return .send(.delegate(.previewSubmitted))

            case .startLearningTapped:
                guard state.canSubmit else { return .none }
                return .send(.delegate(.submitTapped))

            case .gearTapped:
                return .send(.delegate(.openAPIKeySheet))

            case .delegate:
                return .none
            }
        }
    }
}
