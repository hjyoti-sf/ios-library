/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore

// MARK: - Test doubles

/// Records sleep intervals without real delays.
private actor RecordingTaskSleeper: AirshipTaskSleeper {
    private(set) var sleepIntervals: [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleepIntervals.append(timeInterval)
    }
}

// MARK: - Tests

@Suite("ThomasAsyncViewState", .serialized)
@MainActor
struct ThomasAsyncViewStateTest {

    private var validViewInfoJSONData: Data {
        let json = """
        {
          "type": "empty_view",
          "background_color": {
            "default": {
              "type": "hex",
              "hex": "#00FF00",
              "alpha": 0.5
            }
          }
        }
        """
        return Data(json.utf8)
    }

    private func httpResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/async-view")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: [:]
        )!
    }

    private func makeProperties(
        retry: ThomasViewInfo.AsyncViewController.RetryingConfig? = nil,
        auth: ThomasViewInfo.AsyncViewController.Request.Auth? = nil
    ) throws -> ThomasViewInfo.AsyncViewController.Properties {
        let placeholder = try JSONDecoder().decode(ThomasViewInfo.self, from: validViewInfoJSONData)
        let retryConfig = retry ?? ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 0,
            initialBackoff: 1.0,
            maxBackoff: 10.0
        )
        return ThomasViewInfo.AsyncViewController.Properties(
            retry: retryConfig,
            request: .content(
                .init(
                    url: URL(string: "https://example.com/async-view")!,
                    auth: auth
                )
            ),
            placeholder: placeholder,
            identifier: "test-async-resolve"
        )
    }

    @Test
    func channelAuth() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: .channel),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            channelIdFetcher: { "injected-channel-id" }
        )
        try await state.resolve()
        #expect(testSession.lastRequest?.auth == .generatedChannelToken(identifier: "injected-channel-id"))
    }

    @Test
    func contactAuth() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(auth: .contact),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession,
            contactIdFetcher: { "injected-contact-id" }
        )
        try await state.resolve()
        #expect(testSession.lastRequest?.auth == .contactAuthToken(identifier: "injected-contact-id"))
    }

    @Test
    func resolveSucceedsOnFirstAttempt() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 200), data: validViewInfoJSONData)]
        let state = ThomasAsyncViewState(
            properties: try makeProperties(),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession
        )
        try await state.resolve()
        #expect(state.response != nil)
        #expect(testSession.requestInvocationCount == 1)
    }

    @Test
    func resolveDoesNotRetryOnNonServerHTTPError() async throws {
        let testSession = TestAirshipRequestSession()
        let sleeper = RecordingTaskSleeper()
        testSession.responseScript = [
            (response: httpResponse(statusCode: 404), data: nil),
            (response: httpResponse(statusCode: 200), data: validViewInfoJSONData)
        ]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 3,
            initialBackoff: 0.25,
            maxBackoff: 100.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: sleeper,
            requestSession: testSession
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(testSession.requestInvocationCount == 1)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 1)
        #expect(intervals[0] == 0)
    }

    @Test
    func resolveRetriesWithExponentialBackoffThenSucceeds() async throws {
        let testSession = TestAirshipRequestSession()
        let sleeper = RecordingTaskSleeper()
        testSession.responseScript = [
            (response: httpResponse(statusCode: 500), data: nil),
            (response: httpResponse(statusCode: 500), data: nil),
            (response: httpResponse(statusCode: 200), data: validViewInfoJSONData)
        ]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 3,
            initialBackoff: 0.25,
            maxBackoff: 100.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: sleeper,
            requestSession: testSession
        )
        try await state.resolve()
        #expect(state.response != nil)
        #expect(testSession.requestInvocationCount == 3)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 3)
        #expect(intervals[0] == 0)
        #expect(abs(intervals[1] - 0.25) < 0.0001)
        #expect(abs(intervals[2] - 0.5) < 0.0001)
    }

    @Test
    func resolveExhaustsRetriesAndThrowsServerError() async throws {
        let testSession = TestAirshipRequestSession()
        let sleeper = RecordingTaskSleeper()
        testSession.responseScript = [
            (response: httpResponse(statusCode: 503), data: nil),
            (response: httpResponse(statusCode: 503), data: nil)
        ]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 1,
            initialBackoff: 0.1,
            maxBackoff: 10.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: sleeper,
            requestSession: testSession
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(state.response == nil)
        #expect(testSession.requestInvocationCount == 2)
        let intervals = await sleeper.sleepIntervals
        #expect(intervals.count == 2)
        #expect(intervals[0] == 0)
        
    }

    @Test
    func resolveWithMaxRetriesZeroPerformsSingleAttempt() async throws {
        let testSession = TestAirshipRequestSession()
        let sleeper = RecordingTaskSleeper()
        testSession.responseScript = [(response: httpResponse(statusCode: 500), data: nil)]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 0,
            initialBackoff: 1.0,
            maxBackoff: 10.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: sleeper,
            requestSession: testSession
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
        #expect(testSession.requestInvocationCount == 1)
        #expect(await sleeper.sleepIntervals.count == 1)
    }

    @Test
    func resolveNilPropertiesThrows() async throws {
        let state = ThomasAsyncViewState(
            properties: nil,
            taskSleeper: RecordingTaskSleeper(),
            requestSession: TestAirshipRequestSession()
        )
        await #expect(throws: (any Error).self) {
            try await state.resolve()
        }
    }

    @Test
    func retryMapsFinalServerErrorToStatus() async throws {
        let testSession = TestAirshipRequestSession()
        testSession.responseScript = [(response: httpResponse(statusCode: 404), data: nil)]
        let retry = ThomasViewInfo.AsyncViewController.RetryingConfig(
            maxRetries: 0,
            initialBackoff: 0.01,
            maxBackoff: 1.0
        )
        let state = ThomasAsyncViewState(
            properties: try makeProperties(retry: retry),
            taskSleeper: RecordingTaskSleeper(),
            requestSession: testSession
        )
        state.retry()
        for _ in 0..<400 {
            if case .error = state.status { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(state.status == .error(.server(statusCode: 404)))
    }
}
