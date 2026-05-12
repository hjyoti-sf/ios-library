/* Copyright Airship and Contributors */

import SwiftUI
import Foundation

struct EmbeddedPlaygroundPicker: View {
    @Binding var selectedID: String
    var embeddedIds: [String]

    var body: some View {
        VStack {
            Picker("Embedded View", selection: $selectedID) {
                ForEach(embeddedIds, id: \.self) { id in
                    Text(id).tag(id)
                }
            }
#if !os(tvOS) && !os(macOS)
            .pickerStyle(WheelPickerStyle())
#endif
        }
        .onAppear {
            if !embeddedIds.isEmpty {
                selectedID = embeddedIds.first!
            }
        }
    }
}

#Preview {
    EmbeddedPlaygroundPicker(selectedID:Binding.constant("home-rating"), embeddedIds: ["home-rating", "home-special-offer"])
}
