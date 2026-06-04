/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
@_spi(AirshipInternal) import AirshipCore
#endif

/// Any data needed by in-app message to handle displaying the message
struct PreparedInAppMessageData: Sendable {
    var message: InAppMessage
    var displayAdapter: any DisplayAdapter
    var displayCoordinator: any DisplayCoordinator
    var analytics: any InAppMessageAnalyticsProtocol
    var actionRunner: any InAppActionRunner & ThomasActionRunner
}

final class InAppMessageAutomationPreparer: AutomationPreparerDelegate {
    typealias PrepareDataIn = InAppMessage
    typealias PrepareDataOut = PreparedInAppMessageData

    private let displayCoordinatorManager: any DisplayCoordinatorManagerProtocol
    private let displayAdapterFactory: any DisplayAdapterFactoryProtocol
    private let assetManager: any AssetCacheManagerProtocol
    private let analyticsFactory: any InAppMessageAnalyticsFactoryProtocol
    private let actionRunnerFactory: any InAppActionRunnerFactoryProtocol

    @MainActor
    public var displayInterval: TimeInterval {
        get {
            return displayCoordinatorManager.displayInterval
        }
        set {
            displayCoordinatorManager.displayInterval = newValue
        }
    }

    init(
        assetManager: any AssetCacheManagerProtocol,
        displayCoordinatorManager: any DisplayCoordinatorManagerProtocol,
        displayAdapterFactory: any DisplayAdapterFactoryProtocol = DisplayAdapterFactory(),
        analyticsFactory: any InAppMessageAnalyticsFactoryProtocol,
        actionRunnerFactory: any InAppActionRunnerFactoryProtocol = InAppActionRunnerFactory()
    ) {
        self.assetManager = assetManager
        self.displayCoordinatorManager = displayCoordinatorManager
        self.displayAdapterFactory = displayAdapterFactory
        self.analyticsFactory = analyticsFactory
        self.actionRunnerFactory = actionRunnerFactory
    }

    func prepare(
        data: InAppMessage,
        preparedScheduleInfo: PreparedScheduleInfo
    ) async throws -> DelegatePreparerResult<PreparedInAppMessageData> {
        // Resolve intermediate layout at prepare time so urlInfos and display adapter
        // always see a fully-decoded AirshipLayout.
        let message: InAppMessage
        if case .airshipLayoutJSON(let intermediate) = data.displayContent {
            do {
                var resolved = data
                resolved.displayContent = .airshipLayout(try intermediate.resolve())
                message = resolved
            } catch {
                AirshipLogger.error("Failed to resolve layout for \(data.name): \(error)")
                // Non-remote-data schedules come from push payloads that won't change — cancel.
                // Remote-data schedules go back to idle to retry on next trigger.
                return data.source != .remoteData ? .cancel : .skip
            }
        } else {
            message = data
        }

        let assets = try await self.prepareAssets(
            message: message,
            scheduleID: preparedScheduleInfo.scheduleID,
            skip: preparedScheduleInfo.additionalAudienceCheckResult == false || preparedScheduleInfo.experimentResult?.isMatch == true
        )

        let displayCoordinator = self.displayCoordinatorManager.displayCoordinator(message: message)

        let analytics = await self.analyticsFactory.makeAnalytics(
            preparedScheduleInfo: preparedScheduleInfo,
            message: message
        )

        let actionRunner = self.actionRunnerFactory.makeRunner(message: message, analytics: analytics)

        let displayAdapter = try await self.displayAdapterFactory.makeAdapter(
            args: DisplayAdapterArgs(
                message: message,
                assets: assets,
                priority: preparedScheduleInfo.priority,
                _actionRunner: actionRunner
            )
        )

        return .prepared(PreparedInAppMessageData(
            message: message,
            displayAdapter: displayAdapter,
            displayCoordinator: displayCoordinator,
            analytics: analytics,
            actionRunner: actionRunner
        ))
    }

    func cancelled(scheduleID: String) async {
        AirshipLogger.trace("Execution cancelled \(scheduleID)")
        await self.assetManager.clearCache(identifier: scheduleID)
    }

    private func prepareAssets(message: InAppMessage, scheduleID: String, skip: Bool) async throws -> any AirshipCachedAssetsProtocol {
        // - prepare assets
        let imageURLs: [String] = if skip {
            []
        } else {
            message.urlInfos
                .compactMap { info in
                    guard case .image(let url, let prefetch) = info, prefetch else {
                        return nil
                    }
                    return url
                }
        }

        AirshipLogger.trace("Preparing assets \(scheduleID): \(imageURLs)")

        return try await self.assetManager.cacheAssets(
            identifier: scheduleID,
            assets: imageURLs
        )
    }

    @MainActor
    func setAdapterFactoryBlock(
        forType type: CustomDisplayAdapterType,
        factoryBlock: @escaping @Sendable (DisplayAdapterArgs) -> (any CustomDisplayAdapter)?
    ) {
        self.displayAdapterFactory.setAdapterFactoryBlock(
            forType: type,
            factoryBlock: { args in
                factoryBlock(args)
            }
        )
    }
}
