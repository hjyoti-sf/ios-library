/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasAccessibilityActionOutcomeTest {

    private let decoder = JSONDecoder()

    @Test
    func preparedOutcomesReturnsOutcomesWhenPresent() throws {
        let json = """
        {
          "type": "default",
          "behaviors": ["cancel"],
          "outcomes": [
            { "type": "dismiss", "cancel": true }
          ]
        }
        """
        let action = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        let expected = try #require(action.properties.outcomes)
        #expect(action.preparedOutcomes() == expected)
    }

    @Test
    func preparedOutcomesMapsBehaviorsAndActionsWhenOutcomesNil() throws {
        let json = """
        {
          "type": "default",
          "behaviors": ["video_play"],
          "actions": [
            { "add_tags": ["x"] }
          ]
        }
        """
        let action = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        let result = action.preparedOutcomes()
        #expect(result.count == 2)
        #expect(result[0] == ThomasButtonClickBehavior.videoPlay.asOutcome)
        guard case .airshipAction = result[1] else {
            Issue.record("Expected wrapped actions")
            return
        }
    }

    @Test
    func preparedOutcomesEmptyWhenAllNil() throws {
        let json = """
        {
          "type": "escape"
        }
        """
        let action = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        #expect(action.preparedOutcomes().isEmpty)
    }

    @Test
    func decodeWithOutcomesField() throws {
        let json = """
        {
          "type": "escape",
          "outcomes": [
            { "type": "dismiss", "cancel": false }
          ]
        }
        """
        let decoded = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        #expect(decoded.properties.outcomes?.count == 1)
    }

    @Test
    func decodeWithoutOutcomesBackwardCompat() throws {
        let json = """
        {
          "type": "default",
          "behaviors": ["pager_next"]
        }
        """
        let decoded = try decoder.decode(ThomasAccessibilityAction.self, from: Data(json.utf8))
        #expect(decoded.properties.outcomes == nil)
        #expect(decoded.properties.behaviors == [.pagerNext])
    }
}
