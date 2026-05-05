/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
public enum RemoteDataSourceStatus: Sendable {
    case upToDate
    case stale
    case outOfDate
}
