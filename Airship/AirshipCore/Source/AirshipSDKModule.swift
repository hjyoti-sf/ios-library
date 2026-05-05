/* Copyright Airship and Contributors */

public import Foundation

/// - Note: For internal use only. :nodoc:
public protocol AirshipSDKModule: NSObject {
    var actionsManifest: (any ActionsManifest)? { get }
    var components: [any AirshipComponent] { get }

    @MainActor
    static func load(_ args: AirshipModuleLoaderArgs) -> (any AirshipSDKModule)?
}
