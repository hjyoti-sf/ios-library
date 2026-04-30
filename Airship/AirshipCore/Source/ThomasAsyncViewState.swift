/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

@MainActor
final class ThomasAsyncViewState: ObservableObject {
    
    let properties: ThomasViewInfo.AsyncViewController.Properties?
    
    private let taskSleeper: any AirshipTaskSleeper
    private let requestSession: any AirshipRequestSession
    private let channelIdFetcher: (() async throws -> String)
    private let contactIdFetcher: (() async throws -> String)
    
    private var resolveTask: Task<Void, Never>?
    
    init(
        properties: ThomasViewInfo.AsyncViewController.Properties? = nil,
        taskSleeper: any AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared,
        requestSession: (any AirshipRequestSession)? = nil,
        channelIdFetcher: (() async throws -> String)? = nil,
        contactIdFetcher: (() async throws -> String)? = nil
    ) {
        self.properties = properties
        self.taskSleeper = taskSleeper
        self.requestSession = requestSession ?? Airship.config.requestSession
        self.channelIdFetcher = channelIdFetcher ?? {
            // Wait for channel ID from identifierUpdates stream
            var iterator = Airship.channel.identifierUpdates.makeAsyncIterator()
            guard let channelID = await iterator.next() else {
                throw AsyncRequestError.client
            }
            return channelID
        }
        
        self.contactIdFetcher = contactIdFetcher ?? {
            guard let internalContact = Airship.contact as? any InternalAirshipContact else {
                throw AsyncRequestError.client
            }
            return await internalContact.getStableContactID()
        }
    }
    
    deinit {
        resolveTask?.cancel()
    }
    
    enum Status: Encodable, Sendable, Equatable, Hashable {
        case loading
        case loaded
        case error(ErrorInfo)
        
        enum CodingKeys: CodingKey {
            case status
            case error
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .loading:
                try container.encode("loading", forKey: .status)
            case .loaded:
                try container.encode("loaded", forKey: .status)
            case .error(let error):
                try container.encode("error", forKey: .status)
                try container.encode(error, forKey: .error)
            }
        }
    }
    
    enum ErrorInfo: Encodable, Sendable, Equatable, Hashable {
        case client
        case timedOut
        case server(statusCode: Int)
        
        enum CodingKeys: String, CodingKey {
            case type
            case statusCode = "http_status_code"
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .client:
                try container.encode("client_error", forKey: .type)
            case .timedOut:
                try container.encode("timeout", forKey: .type)
            case .server(let statusCode):
                try container.encode("server_error", forKey: .type)
                try container.encode(statusCode, forKey: .statusCode)
            }
        }
    }
    
    @Published
    var response: ThomasViewInfo?
    
    @Published
    var status: Status = .loading
    
    func retry() {
        guard resolveTask == nil, response == nil else { return }
        status = .loading
        resolveTask = Task { @MainActor [weak self] in
            defer {
                self?.resolveTask = nil
            }
            guard let self else { return }
            do {
                try await self.resolve()
                self.status = .loaded
            } catch is CancellationError {
                return
            } catch {
                self.status = .error(self.categorizeError(error))
                AirshipLogger.error("Failed to resolve async view: \(error)")
            }
        }
    }
    
    private func categorizeError(_ error: any Error) -> ErrorInfo {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timedOut
            default:
                return .client
            }
        }
        
        if let asyncError = error as? AsyncRequestError {
            switch asyncError {
            case .client:
                return .client
            case .server(let statusCode):
                return .server(statusCode: statusCode)
            }
        }
        
        return .client
    }
    
    /// Only HTTP 5xx responses are retried; 4xx and other errors fail immediately.
    private func isRetryableServerError(_ error: any Error) -> Bool {
        guard let asyncError = error as? AsyncRequestError,
              case .server(let statusCode) = asyncError else {
            return false
        }
        return (500..<600).contains(statusCode)
    }
    
    func resolve() async throws {
        try Task.checkCancellation()
        
        guard let properties else {
            throw AsyncRequestError.client
        }
        
        guard case .content(let info) = properties.request else {
            throw AsyncRequestError.client
        }
        
        let retry = properties.retry
        var lastError: (any Error)?
        
        for attempt in 0...retry.maxRetries {
            try Task.checkCancellation()

            let delay = calculateBackoff(attempt: attempt, retryPolicy: retry)
            try await taskSleeper.sleep(timeInterval: delay)
            
            do {
                let httpResponse = try await makeRequest(info)
                guard let viewInfo = httpResponse.result else {
                    throw AsyncRequestError.client
                }
                self.response = viewInfo
                return
            } catch {
                if error is CancellationError {
                    throw error
                }
                
                lastError = error
                
                guard isRetryableServerError(error) else {
                    throw error
                }
            }
        }
        
        throw lastError ?? AsyncRequestError.client
    }
    
    // MARK: - HTTP
    
    /// Delay before each resolve attempt. `attempt` is the loop index (sleep-then-request).
    /// - `attempt == 0`: no wait before the first request.
    /// - `attempt >= 1`: `min(initialBackoff * 2^(attempt - 1), maxBackoff)` before subsequent attempts.
    private func calculateBackoff(
        attempt: Int,
        retryPolicy: ThomasViewInfo.AsyncViewController.RetryingConfig
    ) -> TimeInterval {
        if attempt == 0 {
            return 0
        }

        return min(
            retryPolicy.initialBackoff * pow(2.0, Double(attempt - 1)),
            retryPolicy.maxBackoff
        )
    }
    
    private func makeRequest(
        _ info: ThomasViewInfo.AsyncViewController.Request.ContentRequest
    ) async throws -> AirshipHTTPResponse<ThomasViewInfo> {
        
        let resolvedAuth: AirshipRequestAuth?
        switch info.auth {
        case .app:
            resolvedAuth = .basicAppAuth
        case .channel:
            let channelID = try await channelIdFetcher()
            resolvedAuth = .generatedChannelToken(identifier: channelID)
        case .contact:
            let contactID = try await contactIdFetcher()
            resolvedAuth = .contactAuthToken(identifier: contactID)
        case .none:
            resolvedAuth = nil
        }
        
        let airshipRequest = AirshipRequest(
            url: info.url,
            method: "GET",
            auth: resolvedAuth
        )
        
        return try await requestSession.performHTTPRequest(airshipRequest) { (data, response) in
            guard let data = data, response.isSuccessfulHTTPStatus else {
                throw AsyncRequestError.server(statusCode: response.statusCode)
            }
            do {
                return try JSONDecoder().decode(ThomasViewInfo.self, from: data)
            } catch {
                throw AsyncRequestError.client
            }
        }
    }
}

private enum AsyncRequestError: Error {
    case client
    case server(statusCode: Int)
}

private extension HTTPURLResponse {
    /// Matches `AirshipHTTPResponse.isSuccess` (HTTP 2xx).
    var isSuccessfulHTTPStatus: Bool {
        (200...299).contains(statusCode)
    }
}
