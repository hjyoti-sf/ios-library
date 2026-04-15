// Copyright Urban Airship and Contributors

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

@MainActor
final class NativeLayoutPersistentDataStore: LayoutDataStorage {
    let messageID: String

    private var restoreID: String? = nil
    private var storage: [String: Data] = [:]

    private let save: @Sendable (MessageCenterMessage.AssociatedData.ViewState?) -> Void
    private let fetch: @Sendable () async -> MessageCenterMessage.AssociatedData.ViewState?

    init(
        messageID: String,
        onSave: @Sendable @escaping (MessageCenterMessage.AssociatedData.ViewState?) -> Void,
        onFetch: @Sendable @escaping () async -> MessageCenterMessage.AssociatedData.ViewState?
    ) {
        self.messageID = messageID
        self.save = onSave
        self.fetch = onFetch
    }

    func prepare(restoreID: String) async {
        self.restoreID = restoreID

        guard
            let saved = await fetch(),
            saved.restoreID == restoreID
        else {
            self.clear()
            return
        }

        if
            let data = saved.state,
            let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            self.storage = decoded
        }
    }

    func store(_ state: Data?, key: String) {
        guard let restoreID else { return }
        storage[key] = state
        save(makeViewState(restoreID: restoreID))
    }

    func retrieve(_ key: String) -> Data? {
        return storage[key]
    }

    func clear() {
        storage.removeAll()
        if let restoreID {
            save(.init(restoreID: restoreID))
        } else {
            save(nil)
        }
    }

    private func makeViewState(restoreID: String) -> MessageCenterMessage.AssociatedData.ViewState? {
        let data = try? JSONEncoder().encode(storage)
        return .init(restoreID: restoreID, state: data)
    }
}
