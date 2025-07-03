//
//  ContentView.swift
//  BBQ Buddy
//
//  Created by TJ Crowden on 7/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var sessionManager = SharedSessionManager.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @Namespace private var tabNamespace
    
    var body: some View {
        ZStack {
            // Black to orange gradient background like SessionView
            LinearGradient(
                colors: [
                    Color.black.opacity(0.9),
                    Color.red.opacity(0.3),
                    Color.orange.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0: PlannerView().environmentObject(sessionManager)
                    case 1: SessionView().environmentObject(sessionManager)
                    case 2: HistoryView().environmentObject(sessionManager)
                    case 3: AssistantView().environmentObject(sessionManager)
                    case 4: ProfileView().environmentObject(sessionManager)
                    default: PlannerView().environmentObject(sessionManager)
                    }
                }
                .environmentObject(appSettings)
                .environmentObject(authManager)
                
                CustomTabBar(selectedTab: $selectedTab, namespace: tabNamespace)
            }
        }
        .onChange(of: sessionManager.shouldNavigateToSession) { _, shouldNavigate in
            print("[ContentView] shouldNavigateToSession changed: \(shouldNavigate)")
            if shouldNavigate {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    selectedTab = 1 // Navigate to Session tab
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    sessionManager.shouldNavigateToSession = false
                }
            }
        }
        .onChange(of: sessionManager.currentCookPlan) { _, plan in
            if plan == nil {
                // Session was cleared, navigate back to planner
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    selectedTab = 0 // Navigate to Planner tab
                }
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var namespace: Namespace.ID
    
    let tabs: [(icon: String, label: String)] = [
        ("calendar.badge.clock", "Planner"),
        ("flame.fill", "Session"),
        ("clock.arrow.circlepath", "History"),
        ("person.text.rectangle", "Assistant"),
        ("person.crop.circle", "Profile")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \ .self) { idx in
                let isSelected = selectedTab == idx
                Button(action: {
                    if selectedTab != idx {
                        HapticsManager.selection()
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedTab = idx
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                                    .frame(width: 48, height: 36)
                                    .shadow(color: Color.orange.opacity(0.25), radius: 8, x: 0, y: 4)
                            }
                            Image(systemName: tabs[idx].icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(isSelected ? .white : .primary)
                                .scaleEffect(isSelected ? 1.18 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                        }
                        Text(tabs[idx].label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .orange : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: -2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    ContentView()
}
