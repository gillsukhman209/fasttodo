//
//  AppState.swift
//  fasttodo
//

import SwiftUI

@Observable
class AppState {
    static let shared = AppState()
    var shouldFocusInput = false
}
