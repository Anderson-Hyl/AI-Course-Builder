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
        public var baseURLDraft: String
        public var isSaving: Bool
        public var errorMessage: String?

        public init(
            keyDraft: String = "",
            baseURLDraft: String = "",
            isSaving: Bool = false,
            errorMessage: String? = nil
        ) {
            self.keyDraft = keyDraft
            self.baseURLDraft = baseURLDraft
            self.isSaving = isSaving
            self.errorMessage = errorMessage
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case loadedExistingSettings(key: String?, baseURL: String?)
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
                    let existingKey = (try? apiKeyStore.get(provider: .anthropic)) ?? nil
                    let existingBaseURL = (try? apiKeyStore.getBaseURL(provider: .anthropic)) ?? nil
                    await send(.loadedExistingSettings(key: existingKey, baseURL: existingBaseURL))
                }

            case let .loadedExistingSettings(key, baseURL):
                if state.keyDraft.isEmpty, let key, !key.isEmpty {
                    state.keyDraft = key
                }
                if state.baseURLDraft.isEmpty, let baseURL, !baseURL.isEmpty {
                    state.baseURLDraft = baseURL
                }
                return .none

            case .saveTapped:
                state.isSaving = true
                state.errorMessage = nil
                let rawKey = state.keyDraft
                let rawBaseURL = state.baseURLDraft
                return .run { [apiKeyStore] send in
                    do {
                        try apiKeyStore.set(.anthropic, rawKey)
                        try apiKeyStore.setBaseURL(.anthropic, rawBaseURL)
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
