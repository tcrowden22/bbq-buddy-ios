import Foundation
import SwiftUI

enum ChatSender {
    case user
    case assistant
}

struct AssistantChatMessage: Identifiable {
    let id = UUID()
    let sender: ChatSender
    let text: String
    let image: UIImage? // Placeholder for future image analysis
} 