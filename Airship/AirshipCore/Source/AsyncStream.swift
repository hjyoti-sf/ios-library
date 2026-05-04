/* Copyright Airship and Contributors */

import Foundation

public extension AsyncStream {
    static func airshipMakeStreamWithContinuation(
        _ type: Element.Type = Element.self
    ) -> (Self, AsyncStream.Continuation) {
        var continuation: Continuation?
        let stream = Self(type) { continuation = $0 }
        guard let continuation else {
            preconditionFailure("AsyncStream initializer did not invoke continuation synchronously")
        }
        return (stream, continuation)
    }
}
