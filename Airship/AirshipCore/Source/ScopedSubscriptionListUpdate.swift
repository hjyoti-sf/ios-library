/* Copyright Airship and Contributors */

import Foundation

struct ScopedSubscriptionListUpdate: Codable, Equatable, Sendable {
    let listId: String
    let type: SubscriptionListUpdateType
    let scope: ChannelScope
    let date: Date
}
