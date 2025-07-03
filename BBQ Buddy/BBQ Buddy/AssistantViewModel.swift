import Foundation
import OpenAI

class AssistantViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    
    private let openAI: OpenAI
    
    init() {
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        self.openAI = OpenAI(apiToken: apiKey)
    }
    
    func sendMessage(
        _ message: String,
        cookPlan: CookPlan?,
        temperatureHistory: [TemperaturePoint],
        cookNotes: [CookNote]
    ) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message
        let userMessage = Message(role: .user, content: message)
        messages.append(userMessage)
        
        // Build context
        var context = "You are a BBQ cooking assistant. "
        
        if let plan = cookPlan {
            context += "The user is cooking \(plan.weight)lbs of \(plan.meatType) "
            context += "with a target temperature of \(plan.temperature ?? 203)°F. "
        }
        
        // Add temperature context
        if !temperatureHistory.isEmpty {
            let currentTemp = temperatureHistory.last?.temperature ?? 0
            context += "Current meat temperature is \(Int(currentTemp))°F. "
            
            // Calculate temperature trend
            if temperatureHistory.count >= 2 {
                let lastFivePoints = Array(temperatureHistory.suffix(5))
                let tempChange = lastFivePoints.last!.temperature - lastFivePoints.first!.temperature
                if abs(tempChange) > 2 {
                    context += "Temperature is \(tempChange > 0 ? "rising" : "falling") "
                    context += "at about \(abs(Int(tempChange/5)))°F per minute. "
                } else {
                    context += "Temperature is holding steady. "
                }
            }
        }
        
        // Add cook notes context
        if !cookNotes.isEmpty {
            context += "\n\nRecent cook notes:\n"
            let recentNotes = Array(cookNotes.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5))
            for note in recentNotes {
                let timeString = note.timestamp.formatted(date: .omitted, time: .shortened)
                context += "[\(timeString)] (\(note.type.rawValue)) \(note.content)\n"
            }
        }
        
        // Generate response
        Task {
            await generateResponse(userMessage: message, context: context)
        }
    }
    
    @MainActor
    private func generateResponse(userMessage: String, context: String) {
        isLoading = true
        
        let systemMessage = ChatMessage(role: .system, content: context)
        let userChatMessage = ChatMessage(role: .user, content: userMessage)
        let previousMessages = messages.dropLast().map { ChatMessage(role: $0.role, content: $0.content) }
        
        let query = ChatQuery(
            model: .gpt4,
            messages: [systemMessage] + previousMessages + [userChatMessage]
        )
        
        Task {
            do {
                let result = try await openAI.chat(query: query)
                if let choice = result.choices.first {
                    let assistantMessage = Message(role: .assistant, content: choice.message.content)
                    messages.append(assistantMessage)
                }
            } catch {
                print("Error generating response: \(error)")
                let errorMessage = Message(
                    role: .assistant,
                    content: "I apologize, but I encountered an error. Please try again."
                )
                messages.append(errorMessage)
            }
            
            isLoading = false
        }
    }
} 