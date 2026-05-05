import ChatClients
import ComposableArchitecture
import Foundation

/// Modal sheet for entering / clearing the Anthropic API key. Reads any
/// existing key from `APIKeyStore` so the user can edit/clear what's
/// already saved instead of starting blank.
@Reducer
public struct APIKeySheetFeature {
    @ObservableState
    public struct State: Equatable {
        public var keyDraft: String
        public var isSaving: Bool
        public var errorMessage: String?

        public init(keyDraft: String = "", isSaving: Bool = false, errorMessage: String? = nil) {
            self.keyDraft = keyDraft
            self.isSaving = isSaving
            self.errorMessage = errorMessage
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case loadedExistingKey(String?)
        case saveTapped
        case cancelTapped
        case saveCompleted
        case saveFailed(String)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case saved
            case cancelled
        }
    }

    @Dependency(\.apiKeyStore) var apiKeyStore

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { [apiKeyStore] send in
                    let existing = (try? apiKeyStore.get(provider: .anthropic)) ?? nil
                    await send(.loadedExistingKey(existing))
                }

            case .loadedExistingKey(let value):
                if state.keyDraft.isEmpty, let value, !value.isEmpty {
                    state.keyDraft = value
                }
                return .none

            case .saveTapped:
                state.isSaving = true
                state.errorMessage = nil
                let raw = state.keyDraft
                return .run { [apiKeyStore] send in
                    do {
                        try apiKeyStore.set(.anthropic, raw)
                        await send(.saveCompleted)
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .saveCompleted:
                state.isSaving = false
                return .send(.delegate(.saved))

            case .saveFailed(let message):
                state.isSaving = false
                state.errorMessage = message
                return .none

            case .cancelTapped:
                return .send(.delegate(.cancelled))

            case .delegate:
                return .none
            }
        }
    }
}
