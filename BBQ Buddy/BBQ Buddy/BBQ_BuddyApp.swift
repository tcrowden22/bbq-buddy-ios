//
//  BBQ_BuddyApp.swift
//  BBQ Buddy
//
//  Created by TJ Crowden on 7/2/25.
//

import SwiftUI
import Contacts

@main
struct BBQ_BuddyApp: App {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var authManager = AuthManager.shared
    
    init() {
        // Request Contacts permission on app launch
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            // You can handle the result if needed
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(appSettings)
                        .environmentObject(authManager)
                } else {
                    AuthView()
                        .environmentObject(authManager)
                }
            }
            .preferredColorScheme(appSettings.isDarkMode ? .dark : .light)
            .accentColor(BBQTheme.accentColor)
        }
    }
}
