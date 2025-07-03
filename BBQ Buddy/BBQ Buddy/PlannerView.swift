import SwiftUI

class PlannerViewModel: ObservableObject {
    // Add planner-specific logic and @Published properties here
}

struct PlannerView: View {
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
            
            CookPlannerView()
        }
    }
}

#Preview {
    PlannerView()
} 