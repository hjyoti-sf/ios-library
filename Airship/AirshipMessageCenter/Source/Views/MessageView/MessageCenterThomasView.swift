/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

struct MessageCenterThomasView: View {
    
    @Binding
    var phase: MessageCenterMessageView.DisplayPhase
    
    @StateObject
    private var viewModel: ViewModel
    
    init(
        phase: Binding<MessageCenterMessageView.DisplayPhase>,
        layoutRequest: @escaping () async throws -> URLRequest,
        analytics: ThomasDisplayListener,
        dismissHandle: ThomasDismissHandle,
        stateStorage: @escaping () -> any LayoutDataStorage
    ) {
        self._phase = phase
        self._viewModel = StateObject(
            wrappedValue: ViewModel(
                request: layoutRequest,
                analytics: analytics,
                dismissHandle: dismissHandle,
                stateStorage: stateStorage
            )
        )
    }
    
    var body: some View {
        if let (layout, model) = viewModel.layout {
            AirshipSimpleLayoutView(
                layout: layout,
                viewModel: model
            )
        } else {
            Color.clear.task {
                switch phase {
                case .loaded: return
                default: self.phase = await viewModel.loadLayout()
                }
            }
        }
    }
}

@MainActor
private final class ViewModel: ObservableObject {
    private let layoutRequest: () async throws -> URLRequest
    private let stateStorageBuilder: () -> any LayoutDataStorage

    @Published
    private(set) var layout: (AirshipLayout, AirshipSimpleLayoutViewModel)? = nil

    let analyticsRecorder: any ThomasDelegate
    let dismissHandle: ThomasDismissHandle

    init(
        request: @escaping () async throws -> URLRequest,
        analytics: ThomasDisplayListener,
        dismissHandle: ThomasDismissHandle,
        stateStorage: @escaping () -> any LayoutDataStorage
    ) {
        self.layoutRequest = request
        self.analyticsRecorder = analytics
        self.dismissHandle = dismissHandle
        self.stateStorageBuilder = stateStorage
    }
    
    func loadLayout() async -> MessageCenterMessageView.DisplayPhase {
        guard self.layout == nil else {
            return .loaded
        }
        
        do {
            let request = try await self.layoutRequest()
            let (data, _) = try await URLSession.airshipSecureSession.data(for: request)
            let downloaded = try JSONDecoder().decode(AirshipLayout.self, from: data)
            let storage = await preloadData(for: downloaded)
            self.layout = (downloaded, makeSimpleLayoutViewModel(with: storage))
        } catch {
            return .error(error)
        }
        
        return .loaded
    }

    func dismiss() {
        self.dismissHandle.dismiss()
    }
    
    private func preloadData(for layout: AirshipLayout) async -> (any LayoutDataStorage)? {
        let storage = self.stateStorageBuilder()
        
        guard let options = layout.options?.stateRestoration else {
            storage.clear()
            return nil
        }
        
        await storage.prepare(restoreID: options.restoreID)
        return storage
    }
    
    private func makeSimpleLayoutViewModel(with storage: (any LayoutDataStorage)?) -> AirshipSimpleLayoutViewModel {
        AirshipSimpleLayoutViewModel(
            delegate: analyticsRecorder,
            dismissHandle: dismissHandle,
            stateStorage: storage
        )
    }
}

extension View {
    func also(_ action: (Self) -> ()) -> some View {
        action(self)
        return self
    }
}
