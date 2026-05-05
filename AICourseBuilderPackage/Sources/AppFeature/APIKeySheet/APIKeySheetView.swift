import ComposableArchitecture
import SwiftUI

public struct APIKeySheetView: View {
    @Bindable var store: StoreOf<APIKeySheetFeature>

    public init(store: StoreOf<APIKeySheetFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Anthropic API Key")
                    .font(.title2).bold()
                Text("Stored locally on this device under com.aicoursebuilder.provider-keys.anthropic.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            SecureField("sk-ant-…", text: $store.keyDraft)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .textContentType(.password)

            Link(
                "Get a key from console.anthropic.com",
                destination: URL(string: "https://console.anthropic.com/settings/keys")!
            )
            .font(.callout)

            if let message = store.errorMessage {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Button("Cancel") {
                    store.send(.cancelTapped)
                }
                .keyboardShortcut(.cancelAction)
                .disabled(store.isSaving)

                Spacer()

                Button(saveButtonLabel) {
                    store.send(.saveTapped)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(store.isSaving)
            }
        }
        .padding(28)
        .frame(minWidth: 440)
        .task { store.send(.onAppear) }
    }

    private var saveButtonLabel: String {
        store.keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Remove" : "Save"
    }
}
