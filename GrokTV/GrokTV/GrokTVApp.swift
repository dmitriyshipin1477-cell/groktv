import SwiftUI

@main
struct GrokTVApp: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Living-room friendly dark palette and type scale shared by all views.
enum Theme {
    static let background = LinearGradient(
        colors: [Color(red: 0.03, green: 0.03, blue: 0.05), Color(red: 0.07, green: 0.07, blue: 0.11)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let userBubble = Color(red: 0.20, green: 0.36, blue: 0.85)
    static let assistantBubble = Color(red: 0.15, green: 0.15, blue: 0.20)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let errorBackground = Color(red: 0.55, green: 0.12, blue: 0.14)

    static let bodyFont = Font.system(size: 34, weight: .regular)
    static let labelFont = Font.system(size: 24, weight: .semibold)
    static let titleFont = Font.system(size: 56, weight: .bold)
    static let heroFont = Font.system(size: 76, weight: .heavy)
}
