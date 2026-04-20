//
//  View+DebugLabel.swift
//  SpaceManager
//
//  Debug identifiers for SwiftUI views.
//

import SwiftUI

extension View {
    func debugLabel(_ label: String) -> some View {
        accessibilityIdentifier(label)
    }
}
