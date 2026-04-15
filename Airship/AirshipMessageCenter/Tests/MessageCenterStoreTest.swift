/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore
@testable import AirshipMessageCenter

final class MessageCenterStoreTest: XCTestCase {
    private var dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config: RuntimeConfig = .testConfig()
        
    private lazy var store: MessageCenterStore = {
        let modelURL = AirshipMessageCenterResources.bundle
            .url(
                forResource: "UAInbox",
                withExtension: "momd"
            )
        if let modelURL = modelURL {
            let storeName = String(
                format: "Inbox-%@.sqlite",
                self.config.appCredentials.appKey
            )
            let coreData = UACoreData(
                name: "UAInbox",
                modelURL: modelURL,
                inMemory: true,
                stores: [storeName]
            )
            return MessageCenterStore(
                config: self.config,
                dataStore: self.dataStore,
                coreData: coreData
            )
        }
        return MessageCenterStore(
            config: self.config,
            dataStore: self.dataStore
        )
    }()

    func testMessageCenterStoreSaveAndResetUser() async throws {

        let expectedUser = MessageCenterUser(
            username: "AnyName",
            password: "AnyPassword"
        )

        // Save user
        await store.saveUser(expectedUser, channelID: "987654433")

        let user = await store.user
        XCTAssertNotNil(user)
        XCTAssertEqual(user!.username, expectedUser.username)
        XCTAssertEqual(user!.password, expectedUser.password)

        // Reset User
        await store.resetUser()

        let resetedUser = await store.user
        XCTAssertNil(resetedUser)
    }

    func testUserRequiredUpdate() async throws {
        // Set setUserRequireUpdate true
        await store.setUserRequireUpdate(true)
        var requiredUpdate = await store.userRequiredUpdate
        XCTAssertTrue(requiredUpdate)

        // Set Required update false
        await store.setUserRequireUpdate(false)
        requiredUpdate = await store.userRequiredUpdate
        XCTAssertFalse(requiredUpdate)
    }

    func testFetchMessages() async throws {
        let messages = MessageCenterMessage.generateMessages(3)

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )
    }

    func testUpdateAssociatedDataPersistsMutation() async throws {
        let messages = MessageCenterMessage.generateMessages(1)
        try await store.updateMessages(messages: messages, lastModifiedTime: "")

        let viewState = MessageCenterMessage.AssociatedData.ViewState(
            restoreID: "restore-1",
            state: Data("state".utf8)
        )
        try await store.updateAssociatedData(for: messages[0].id) { $0.viewState = viewState }

        let fetched = try await store.message(forID: messages[0].id)
        XCTAssertEqual(fetched?.associatedData.viewState, viewState)
    }

    func testUpdateAssociatedDataDoesNotAffectOtherMessages() async throws {
        let messages = MessageCenterMessage.generateMessages(3)
        try await store.updateMessages(messages: messages, lastModifiedTime: "")

        try await store.updateAssociatedData(for: messages[0].id) {
            $0.viewState = .init(restoreID: "only-first", state: nil)
        }

        let second = try await store.message(forID: messages[1].id)
        let third = try await store.message(forID: messages[2].id)
        XCTAssertNil(second?.associatedData.viewState)
        XCTAssertNil(third?.associatedData.viewState)
    }

    func testUpdateAssociatedDataThrowsForMissingMessage() async throws {
        do {
            try await store.updateAssociatedData(for: "nonexistent-id") { $0.viewState = nil }
            XCTFail("Expected an error to be thrown")
        } catch MessageCenterStoreError.coreDataError {
            // expected
        }
    }

    func testSyncMessages() async throws {
        let generated = MessageCenterMessage.generateMessages(5)
        var messages = Array(generated[0...2])

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        var fetchedMessage = await store.messages
        XCTAssertEqual(messages, fetchedMessage)

        messages.remove(at: 0)
        messages.append(contentsOf: generated[3...4])

        try await store.updateMessages(
            messages: messages,
            lastModifiedTime: ""
        )

        fetchedMessage = await store.messages
        XCTAssertEqual(messages, fetchedMessage)
    }
}

extension MessageCenterMessage {

    static func generateMessage(
        sentDate: Date = Date(),
        expiry: Date? = nil
    ) -> MessageCenterMessage {
        return MessageCenterMessage(
            title: UUID().uuidString,
            id: UUID().uuidString,
            contentType: .html,
            extra: [UUID().uuidString: UUID().uuidString],
            bodyURL: URL(
                string: "https://www.some-url.fr/\(UUID().uuidString)"
            )!,
            expirationDate: expiry,
            messageReporting: [UUID().uuidString: .string(UUID().uuidString)],
            unread: true,
            sentDate: sentDate,
            messageURL: URL(
                string: "https://some-url.fr/\(UUID().uuidString)"
            )!,
            rawMessageObject: [:]
        )
    }

    static func generateMessages(_ count: Int) -> [MessageCenterMessage] {
        // Sets the sent date to make the order predictable
        let date = Date()
        return (0..<count)
            .map { index in
                generateMessage(
                    sentDate: date.advanced(by: Double(-index))
                )
            }
    }

}
