/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasAutomatedActionOutcomeTest {

    private let decoder = JSONDecoder()

    @Test
    func preparedOutcomesReturnsOutcomesWhenPresent() throws {
        let list: [ThomasOutcome] = [.dismiss(.init(cancel: false))]
        let emptyPayload = ThomasActionsPayload(value: try AirshipJSON.from(json: "{}"))
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: [emptyPayload],
            behaviors: [.dismiss],
            reportingMetadata: nil,
            outcomes: list
        )
        #expect(action.preparedOutcomes() == list)
    }

    @Test
    func preparedOutcomesMapsBehaviorsAndActionsWhenOutcomesNil() throws {
        let payload = ThomasActionsPayload(value: try AirshipJSON.from(json: #"{"x":1}"#))
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: [payload],
            behaviors: [.pagerNext, .pagerPrevious],
            reportingMetadata: nil,
            outcomes: nil
        )
        let result = action.preparedOutcomes()
        #expect(result.count == 3)
        #expect(result[0] == ThomasButtonClickBehavior.pagerNext.asOutcome)
        #expect(result[1] == ThomasButtonClickBehavior.pagerPrevious.asOutcome)
        #expect(result[2] == payload.asOutcome)
    }

    @Test
    func preparedOutcomesEmptyWhenAllNil() {
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: nil,
            behaviors: nil,
            reportingMetadata: nil,
            outcomes: nil
        )
        #expect(action.preparedOutcomes().isEmpty)
    }

    @Test
    func preparedOutcomesOrderBehaviorsBeforeActions() throws {
        let payload = ThomasActionsPayload(value: try AirshipJSON.from(json: "{}"))
        let action = ThomasAutomatedAction(
            identifier: "a1",
            delay: nil,
            actions: [payload],
            behaviors: [.formSubmit],
            reportingMetadata: nil,
            outcomes: nil
        )
        let result = action.preparedOutcomes()
        #expect(result.count == 2)
        guard case .form(let first) = result[0] else {
            Issue.record("Expected form outcome first")
            return
        }
        #expect(first.command == .submit)
        guard case .airshipAction = result[1] else {
            Issue.record("Expected action outcome second")
            return
        }
    }

    @Test
    func decodeWithOutcomesField() throws {
        let json = """
        {
          "identifier": "auto1",
          "outcomes": [
            { "type": "dismiss", "cancel": false }
          ]
        }
        """
        let decoded = try decoder.decode(ThomasAutomatedAction.self, from: Data(json.utf8))
        #expect(decoded.outcomes?.count == 1)
    }

    @Test
    func decodeWithoutOutcomesBackwardCompat() throws {
        let json = """
        {
          "identifier": "auto1",
          "behaviors": ["pager_next"]
        }
        """
        let decoded = try decoder.decode(ThomasAutomatedAction.self, from: Data(json.utf8))
        #expect(decoded.outcomes == nil)
        #expect(decoded.behaviors == [.pagerNext])
    }
}
