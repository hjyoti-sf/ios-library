/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Combine

@MainActor
struct AsyncViewController: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var thomasState: ThomasState
    
    let info: ThomasViewInfo.AsyncViewController
    let constraints: ViewConstraints
    
    @StateObject
    private var state: ThomasAsyncViewState
    
    @StateObject
    private var scopedStateCache: ScopedStateCache = ScopedStateCache()
    
    init(
        info: ThomasViewInfo.AsyncViewController,
        constraints: ViewConstraints
    ) {
        self.info = info
        self.constraints = constraints
        self._state = StateObject(
            wrappedValue: ThomasAsyncViewState(properties: info.properties)
        )
    }
    
    var body: some View {
        Group {
            if let response = state.response {
                ViewFactory.createView(response, constraints: constraints)
            } else {
                ViewFactory.createView(info.properties.placeholder, constraints: constraints)
                    .constraints(constraints)
                    .thomasCommon(info)
                    .onAppear  {
                        state.retry()
                    }
            }
        }
        .environmentObject(state)
        .environmentObject(
            scopedStateCache.getOrCreate {
                thomasState.with(asyncViewState: state)
            }
        )
        .id(info.properties.identifier)
    }
}
