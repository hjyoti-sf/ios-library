/* Copyright Airship and Contributors */

public import Foundation

/// - Note: for internal use only.  :nodoc:
@_spi(AirshipInternal)
public struct AirshipDateFormatter: Sendable {
    private init() {}

    /// ISO 8601 date formats suitable for API encoding/decoding.
    public enum Format: Sendable {
        /// ISO 8601 with T delimiter, milliseconds, and UTC timezone (`yyyy-MM-dd'T'HH:mm:ss.SSSZ`)
        case iso8601WithMilliseconds
        /// ISO 8601 with T delimiter and UTC timezone, no milliseconds (`yyyy-MM-dd'T'HH:mm:ssZ`)
        case iso8601
    }

    /// Locale-dependent relative display formats. Not suitable for API encoding.
    public enum RelativeFormat: Sendable {
        /// Short date & time format
        case short
        /// Short date format
        case shortDate
        /// Full date & time format
        case full
        /// Full date format
        case fullDate
    }

    private static let dateFormatterISO8601WithMilliseconds: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let dateFormatterISO8601: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static let altDateFormatters: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd'T'HH",
        "yyyy-MM-dd HH",
        "yyyy-MM-dd",
        "yyyy-MM",
        "yyyy",
    ].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = format
        return f
    }

    private static let dateFormatterRelativeFull: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .full
        f.dateStyle = .full
        f.doesRelativeDateFormatting = true
        return f
    }()

    private static let dateFormatterRelativeShort: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    private static let dateFormatterRelativeShortDate: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .none
        f.dateStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()

    private static let dateFormatterRelativeFullDate: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .none
        f.dateStyle = .full
        f.doesRelativeDateFormatting = true
        return f
    }()

    /// Parses a date string from a variety of formats.
    ///
    /// Tries RFC 3339 with milliseconds first, then falls back to common ISO 8601 variants
    /// including formats with/without the `T` delimiter, with/without milliseconds,
    /// with/without timezone offset, and partial dates down to year only.
    ///
    /// - Parameter string: The date string to parse.
    ///
    /// - Returns: A parsed Date, or nil if no supported format matched.
    public static func date(from string: String) -> Date? {
        if let date = dateFormatterISO8601.date(from: string) {
            return date
        }

        if let date = dateFormatterISO8601WithMilliseconds.date(from: string) {
            return date
        }

        for formatter in altDateFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    public static func string(fromDate date: Date, format: Format) -> String {
        switch format {
        case .iso8601WithMilliseconds:
            return self.dateFormatterISO8601WithMilliseconds.string(from: date)
        case .iso8601:
            return self.dateFormatterISO8601.string(from: date)
        }
    }

    public static func string(fromDate date: Date, relativeFormat: RelativeFormat) -> String {
        switch relativeFormat {
        case .shortDate:
            return self.dateFormatterRelativeShortDate.string(from: date)
        case .fullDate:
            return self.dateFormatterRelativeFullDate.string(from: date)
        case .full:
            return self.dateFormatterRelativeFull.string(from: date)
        case .short:
            return self.dateFormatterRelativeShort.string(from: date)
        }
    }
}

extension JSONDecoder.DateDecodingStrategy {
    /// Decodes dates using the flexible Airship date string parser.
    @_spi(AirshipInternal)
    public static var airshipISO8601: JSONDecoder.DateDecodingStrategy {
        return .custom({ decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            guard let date = AirshipDateFormatter.date(from: dateStr) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date string: \(dateStr)"
                )
            }
            return date
        })
    }
}

extension JSONEncoder.DateEncodingStrategy {
    @_spi(AirshipInternal)
    public static func airship(format: AirshipDateFormatter.Format) -> JSONEncoder.DateEncodingStrategy {
        return .custom({ date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(
                AirshipDateFormatter.string(fromDate: date, format: format)
            )
        })
    }
}
