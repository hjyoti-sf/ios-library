/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
public protocol ThomasLayoutEvent: Sendable {
    var name: EventType { get }
    var data: (any Sendable&Encodable)? { get }
}
