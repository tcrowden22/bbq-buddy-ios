import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date = Date()
}

struct CookNote: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let content: String
    let type: NoteType
    
    enum NoteType: String, Codable {
        case observation // General observations
        case temperature // Temperature-related notes
        case wrapping // Wrapping events
        case spritzing // Spritzing/basting events
        case issue // Problems or concerns
        
        var icon: String {
            switch self {
            case .observation: return "note.text"
            case .temperature: return "thermometer"
            case .wrapping: return "shippingbox.fill"
            case .spritzing: return "spray"
            case .issue: return "exclamationmark.triangle"
            }
        }
        
        var color: String {
            switch self {
            case .observation: return "gray"
            case .temperature: return "orange"
            case .wrapping: return "blue"
            case .spritzing: return "green"
            case .issue: return "red"
            }
        }
    }
} 