import SwiftUI

struct BBQTheme {
    static let accentColor = Color(red: 0.95, green: 0.35, blue: 0.1) // Warm orange-red
    static let gradient = LinearGradient(
        gradient: Gradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.2), Color(red: 0.7, green: 0.2, blue: 0.1)]),
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardBackground: Material = .ultraThinMaterial
    static let cardCornerRadius: CGFloat = 24
    static let cardShadow = Shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    static let titleFont = Font.system(size: 32, weight: .bold, design: .rounded)
    static let subtitleFont = Font.system(size: 18, weight: .semibold, design: .rounded)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func bbqCardStyle() -> some View {
        self
            .background(BBQTheme.cardBackground)
            .cornerRadius(BBQTheme.cardCornerRadius)
            .shadow(color: BBQTheme.cardShadow.color, radius: BBQTheme.cardShadow.radius, x: BBQTheme.cardShadow.x, y: BBQTheme.cardShadow.y)
    }
    func bbqTitle() -> some View {
        self.font(BBQTheme.titleFont).foregroundColor(BBQTheme.accentColor)
    }
    func bbqSubtitle() -> some View {
        self.font(BBQTheme.subtitleFont).foregroundColor(.primary)
    }
    func bbqSpring() -> some View {
        self.animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.3), value: UUID())
    }
} 