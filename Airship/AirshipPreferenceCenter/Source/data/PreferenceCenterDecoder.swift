/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

class PreferenceCenterDecoder {
    class func decodeConfig(data: Data) throws -> PreferenceCenterConfig {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .airshipISO8601
        return try decoder.decode(PreferenceCenterConfig.self, from: data)
    }
}
