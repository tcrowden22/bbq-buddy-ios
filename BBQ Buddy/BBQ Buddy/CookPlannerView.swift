import SwiftUI
import Foundation
import Supabase

// MARK: - Shared Session Manager
@MainActor
class SharedSessionManager: ObservableObject {
    static let shared = SharedSessionManager()
    
    @Published var currentCookPlan: CookPlan?
    @Published var shouldNavigateToSession = false
    private let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(supabaseURL: URL(string: SupabaseConfig.supabaseURL)!, supabaseKey: SupabaseConfig.supabaseAnonKey)
    }
    
    func startNewSession(with plan: CookPlan) async {
        print("[SharedSessionManager] Starting new session with plan: \(plan)")
        currentCookPlan = plan
        shouldNavigateToSession = true
        
        // Save to Supabase
        let sessionName = "BBQ Plan: \(plan.meatType) (\(formatted(Date())))"
        let metadata: [String: String] = [
            "meat_type": plan.meatType,
            "weight": "\(plan.weight)",
            "completion_time": ISO8601DateFormatter().string(from: plan.completionTime),
            "start_time": ISO8601DateFormatter().string(from: plan.startTime),
            "wrap_time": plan.wrapTime.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "rest_time": plan.restTime.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "temperature": "\(plan.temperature ?? 203)"
        ]
        
        print("[SharedSessionManager] Saving session to Supabase")
        print("[SharedSessionManager] Session name: \(sessionName)")
        print("[SharedSessionManager] Metadata: \(metadata)")
        
        // Create initial message
        let initialMessage = ChatMessage(
            text: "Started cooking \(plan.weight) lbs of \(plan.meatType) at \(plan.temperature ?? 203)°F",
            isUser: false
        )
        
        // Save chat session
        await withCheckedContinuation { continuation in
            SessionStorageManager.shared.saveSession(
                sessionName: sessionName,
                messages: [initialMessage],
                metadata: metadata
            ) { result in
                switch result {
                case .success:
                    print("[SharedSessionManager] Chat session saved successfully!")
                case .failure(let error):
                    print("[SharedSessionManager] Failed to save chat session: \(error)")
                    print("[SharedSessionManager] Error details: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
        
        // Also create a cook session
        do {
            guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
                print("[SharedSessionManager] Error: No user ID found")
                return
            }
            
            let cookSessionId = UUID()
            
            // Create cook session record
            let cookSession = CookSessionInsert(
                id: cookSessionId.uuidString,
                user_id: userId,
                meat_type: plan.meatType,
                weight: plan.weight,
                start_time: ISO8601DateFormatter().string(from: plan.startTime),
                end_time: ISO8601DateFormatter().string(from: plan.completionTime),
                temperature_readings: [],
                notes: nil,
                ai_feedback: nil
            )
            
            print("[SharedSessionManager] Creating cook session with ID: \(cookSessionId)")
            
            try await client.database
                .from("cook_sessions")
                .insert(cookSession)
                .execute()
            
            print("[SharedSessionManager] Cook session created successfully")
            
        } catch {
            print("[SharedSessionManager] Error creating cook session: \(error)")
            print("[SharedSessionManager] Error details: \(error.localizedDescription)")
        }
    }
    
    func clearSession() {
        currentCookPlan = nil
        shouldNavigateToSession = false
    }
    
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// Helper struct for creating cook sessions
private struct CookSessionInsert: Encodable {
    let id: String
    let user_id: String
    let meat_type: String
    let weight: Double
    let start_time: String
    let end_time: String
    let temperature_readings: [TemperatureReading]
    let notes: String?
    let ai_feedback: String?
    
    struct TemperatureReading: Encodable {
        let id: String
        let time: String
        let temperature: Double
    }
}

struct CookPlan: Equatable {
    var meatType: String
    var weight: Double
    var completionTime: Date
    var startTime: Date
    var wrapTime: Date?
    var restTime: Date?
    var temperature: Int?
    var tips: String?
}

// MARK: - ViewModel
class CookPlannerViewModel: ObservableObject {
    @Published var meatTypes = ["Brisket", "Beef Ribs", "Pork Ribs", "Chicken", "Turkey", "Pork Butt"]
    @Published var selectedMeat = ""
    @Published var weight: String = ""
    @Published var targetCompletion = Date().addingTimeInterval(60*60*8) // 8 hours from now
    @Published var showChat = false
    @Published var chatMessages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var currentInput = ""
    @Published var cookPlan: CookPlan?
    @Published var isReadyToStart = false
    
    var isFormValid: Bool {
        !selectedMeat.isEmpty && !weight.isEmpty && Double(weight) != nil && Double(weight)! > 0
    }
    
    func generateCookPlan() {
        guard isFormValid, let weightValue = Double(weight) else { return }
        
        isLoading = true
        showChat = true
        
        // Add user's initial request to chat
        let userMessage = "I want to cook \(weightValue) lbs of \(selectedMeat) and have it ready by \(formatted(targetCompletion)). Can you help me plan this cook?"
        chatMessages.append(ChatMessage(text: userMessage, isUser: true))
        
        // Call OpenAI API for real AI response
        callOpenAIForCookPlan(prompt: userMessage)
    }
    
    private func callOpenAIForCookPlan(prompt: String) {
        let apiKey = Config.openAIKey
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        let systemPrompt = """
        You are BBQ Buddy, an expert pitmaster and AI assistant. When asked for a cook plan, reply with a short, direct summary first (1-2 lines), then a step-by-step plan using relevant emojis for each step (fire, clock, thermometer, etc). Keep it concise and easy to scan. Example format:
        
        **Summary:** [short summary]
        🔥 Start: [time]
        🌡️ Smoker: [temp]
        🎯 Target: [internal temp]
        ⏰ Ready: [ready time]
        📦 Wrap: [wrap time, if needed]
        🛌 Rest: [rest time]
        """
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 350
        ]
        let jsonData = try! JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                guard let self = self else { return }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let message = choices.first?["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    self.chatMessages.append(ChatMessage(text: "Sorry, I couldn't get a response from the AI.", isUser: false))
                    return
                }
                self.chatMessages.append(ChatMessage(text: content.trimmingCharacters(in: .whitespacesAndNewlines), isUser: false))
                // Set cookPlan with current form values so session can be created
                let weightValue = Double(self.weight) ?? 0
                let cookTimePerPound: Double = {
                    switch self.selectedMeat.lowercased() {
                    case "brisket": return 1.5
                    case "beef ribs": return 1.25
                    case "pork ribs": return 1.0
                    case "chicken": return 0.5
                    case "turkey": return 0.75
                    case "pork butt": return 1.25
                    default: return 1.0
                    }
                }()
                let totalCookTime = cookTimePerPound * weightValue
                let startTime = Calendar.current.date(byAdding: .hour, value: -Int(totalCookTime), to: self.targetCompletion) ?? self.targetCompletion
                let wrapTime = Calendar.current.date(byAdding: .hour, value: -4, to: self.targetCompletion)
                let restTime = Calendar.current.date(byAdding: .minute, value: 30, to: self.targetCompletion)
                let temp = content.contains("225") ? 225 : (content.contains("250") ? 250 : (content.contains("275") ? 275 : 203))
                self.cookPlan = CookPlan(
                    meatType: self.selectedMeat,
                    weight: weightValue,
                    completionTime: self.targetCompletion,
                    startTime: startTime,
                    wrapTime: wrapTime,
                    restTime: restTime,
                    temperature: temp,
                    tips: nil
                )
            }
        }.resume()
    }
    
    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userMessage = currentInput
        chatMessages.append(ChatMessage(text: userMessage, isUser: true))
        currentInput = ""
        
        // Check if user approves the plan
        let approvalKeywords = ["looks good", "approve", "start cooking", "let's start", "good to go", "sounds good", "perfect", "great"]
        let messageWords = userMessage.lowercased()
        
        if approvalKeywords.contains(where: { messageWords.contains($0) }) {
            isReadyToStart = true
            chatMessages.append(ChatMessage(text: "Excellent! I'm creating your cooking session now. Let's get that \(selectedMeat.lowercased()) cooking! 🔥", isUser: false))
            
            // Create session and navigate
                                if let plan = cookPlan {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            Task {
                                await SharedSessionManager.shared.startNewSession(with: plan)
                            }
                        }
                    }
            return
        }
        
        isLoading = true
        
        // Simulate ChatGPT response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.simulateFollowUpResponse(to: userMessage)
        }
    }
    
    private func simulateFollowUpResponse(to userMessage: String) {
        let message = userMessage.lowercased()
        
        let response: String
        
        // Check for specific temperature numbers first
        let temperatureRegex = try! NSRegularExpression(pattern: "\\b(\\d{2,3})\\b", options: [])
        let matches = temperatureRegex.matches(in: message, options: [], range: NSRange(location: 0, length: message.count))
        
        if let match = matches.first, let range = Range(match.range, in: message) {
            if let requestedTemp = Int(String(message[range])) {
                // User specified an exact temperature
                if var plan = cookPlan {
                    plan.temperature = requestedTemp
                    cookPlan = plan
                    
                    // Recalculate cook times based on new temperature
                    let tempAdjustment = requestedTemp < 275 ? "slower" : "faster"
                    let timeChange = requestedTemp < 275 ? "add 30-45 mins" : "shave 20-30 mins"
                    
                    response = """
                    Perfect! Dialing it down to \(requestedTemp)°F 👍
                    
                    **Updated Cook Plan:**
                    🌡️ New smoker temp: \(requestedTemp)°F
                    ⏰ This will \(timeChange) to cook time
                    🎯 Still targeting \(plan.temperature)°F internal
                    🔥 \(tempAdjustment.capitalized) cook = better smoke penetration!
                    
                    Smart call - \(requestedTemp)°F will give you amazing flavor! Ready to fire up or need more tweaks?
                    """
                    
                    chatMessages.append(ChatMessage(text: response, isUser: false))
                    isLoading = false
                    return
                }
            }
        }
        
        // Handle temperature adjustment requests without specific numbers
        if message.contains("lower") || message.contains("reduce") || message.contains("decrease") || message.contains("adjust") {
            if message.contains("temp") || message.contains("temperature") || message.contains("high") {
                // Update the cook plan with lower temperature
                if var plan = cookPlan {
                    let currentTemp = plan.temperature ?? 275
                    let newTemp = max(currentTemp - 25, 225) // Reduce by 25°F, minimum 225°F
                    plan.temperature = newTemp
                    cookPlan = plan
                    
                    response = """
                    You got it! Lower and slower is often better 👍
                    
                    **Updated Cook Plan:**
                    🌡️ New smoker temp: \(newTemp)°F
                    ⏰ Adding ~30-45 mins to cook time
                    🎯 Still hitting \(currentTemp)°F internal
                    
                    This'll give you more smoke flavor and tender bark. Smart move! Need any other tweaks?
                    """
                } else {
                    response = "I hear ya! Once we get your plan locked in, I can dial in those temps perfectly. Say 'looks good' to get cooking!"
                }
            } else {
                response = "What are we lowering, partner? Temperature, cook time, or something else? I'm here to dial it in!"
            }
        }
        // Handle temperature increase requests
        else if message.contains("higher") || message.contains("increase") || message.contains("hotter") {
            if message.contains("temp") || message.contains("temperature") {
                if var plan = cookPlan {
                    let currentTemp = plan.temperature ?? 275
                    let newTemp = min(currentTemp + 25, 325) // Increase by 25°F, maximum 325°F
                    plan.temperature = newTemp
                    cookPlan = plan
                    
                    response = """
                    Hot and fast it is! 🔥
                    
                    **Cranked Up Temps:**
                    🌡️ New smoker temp: \(newTemp)°F
                    ⚡ Shaving ~20-30 mins off cook time
                    📊 Watch for faster bark development
                    
                    Keep an eye on it - higher temps can dry out if not careful. You cooking against the clock today?
                    """
                } else {
                    response = "I can crank up the heat once we get your plan set! Say 'looks good' and we'll get this party started!"
                }
            } else {
                response = "What needs more heat, friend? Temperature, spice level, or something else? Let's fire it up!"
            }
        }
        // Handle timing adjustments
        else if message.contains("earlier") || message.contains("later") || message.contains("time") {
            if var plan = cookPlan {
                if message.contains("earlier") {
                    plan.startTime = Calendar.current.date(byAdding: .hour, value: -1, to: plan.startTime) ?? plan.startTime
                    response = """
                    Earlier start, coming right up! ⏰
                    
                    **Adjusted Timeline:**
                    🔥 New fire-up time: \(formatted(plan.startTime))
                    ✅ Still ready by: \(formatted(plan.completionTime))
                    🌙 That's an early morning for great BBQ!
                    
                    Coffee's gonna taste extra good that morning! Sound better?
                    """
                } else if message.contains("later") {
                    plan.startTime = Calendar.current.date(byAdding: .hour, value: 1, to: plan.startTime) ?? plan.startTime
                    response = """
                    Later start works! 😴
                    
                    **Pushed Back Timeline:**
                    🔥 New fire-up time: \(formatted(plan.startTime))
                    ✅ Still ready by: \(formatted(plan.completionTime))
                    ☕ Extra sleep never hurt anyone!
                    
                    That work better with your schedule?
                    """
                } else {
                    response = "Want to start earlier to beat the rush, or later to sleep in? I can adjust the timeline however you need!"
                }
                cookPlan = plan
            } else {
                response = "I can dial in perfect timing once we lock in your plan. Say 'looks good' and let's get this cook scheduled!"
            }
        }
        // Wood selection expertise
        else if message.contains("wood") {
            response = """
            Now we're talking! Wood choice is everything 🌳
            
            **For \(selectedMeat):**
            🌰 **Oak** - My go-to base, burns clean & steady
            🍎 **Apple** - Sweet, mild smoke (pairs great with oak)
            💪 **Hickory** - Bold bacon flavor (use sparingly)
            🍒 **Cherry** - Beautiful color, mild taste
            
            **My recommendation:** 70% oak, 30% apple. Trust me on this combo - it's magic! What's available in your area?
            """
        } 
        // Rub and seasoning expertise
        else if message.contains("rub") || message.contains("seasoning") {
            response = """
            Let's build you a killer rub! 🧂
            
            **BBQ Buddy's \(selectedMeat) Rub:**
            🟤 2 tbsp brown sugar (caramelization!)
            🌶️ 1 tbsp paprika (color & mild heat)
            🧂 1 tbsp kosher salt (draws out moisture)
            ⚫ 1 tsp black pepper (coarse ground)
            🧄 1 tsp garlic powder
            🧅 1 tsp onion powder
            
            **Pro move:** Apply 2-4 hours before (overnight is even better). Salt draws moisture first, then reabsorbs with flavor. Science! 🔬
            """
        } 
        // Temperature and technique questions (only if no adjustment was requested)
        else if message.contains("temperature") || message.contains("temp") {
            response = """
            Temperature talk - my favorite! 🌡️
            
            **Current Setup:**
            🔥 Smoker: \(cookPlan?.temperature ?? 275)°F
            🎯 Target internal: \(cookPlan?.temperature ?? 203)°F
            📊 Stall zone: 160-170°F (wrap time!)
            
            **Why these temps?** 275°F gives great bark without drying out. For \(selectedMeat.lowercased()), we go past USDA safe (165°F) to break down collagen into gelatin. That's what makes it tender!
            
            Want to adjust the smoker temp up or down?
            """
        } 
        // General BBQ wisdom
        else {
            response = """
            I'm here to help you smoke the perfect \(selectedMeat.lowercased())! 🔥
            
            **Ask me about:**
            🌡️ Temperature adjustments (hotter/cooler)
            🌳 Wood selection & pairing
            🧂 Rub recipes & techniques
            ⏰ Timing tweaks
            🥩 Meat safety & doneness
            
            30+ years of pit experience at your service! What's on your mind, or ready to "fire it up"?
            """
        }
        
        chatMessages.append(ChatMessage(text: response, isUser: false))
        isLoading = false
    }
    
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Main View
struct CookPlannerView: View {
    @StateObject private var viewModel = CookPlannerViewModel()
    @State private var animateIcon = false
    @FocusState private var isInputFocused: Bool
    @EnvironmentObject var sessionManager: SharedSessionManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                HeaderView(animateIcon: $animateIcon)
                
                // Cook Details Form
                if !viewModel.showChat {
                    CookDetailsCard(viewModel: viewModel)
                }
                
                // Chat Interface
                if viewModel.showChat {
                    ChatInterfaceCard(viewModel: viewModel, isInputFocused: $isInputFocused)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateIcon = true
            }
        }
        .onChange(of: viewModel.isReadyToStart) { _, isReady in
            if isReady {
                // Remove automatic navigation - user must tap Continue button
                // HapticsManager.notification(.success)
                // 
                // DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                //     if let plan = viewModel.cookPlan {
                //         SharedSessionManager.shared.startNewSession(with: plan)
                //     }
                // }
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @Binding var animateIcon: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .scaleEffect(animateIcon ? 1.1 : 0.9)
                    .opacity(animateIcon ? 0.6 : 1.0)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(animateIcon ? 5 : -5))
            }
            
            Text("BBQ Buddy")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Plan your perfect BBQ session")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Cook Details Card
struct CookDetailsCard: View {
    @ObservedObject var viewModel: CookPlannerViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Cook Details")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.white)
            
            VStack(spacing: 20) {
                // Meat Type Selection
                MeatTypeGrid(selectedMeat: $viewModel.selectedMeat, meatTypes: viewModel.meatTypes)
                
                // Weight Input
                WeightInputField(weight: $viewModel.weight)
                
                // Completion Time
                CompletionTimeField(targetCompletion: $viewModel.targetCompletion)
                
                // Plan Button
                if viewModel.isFormValid {
                    PlanButton(viewModel: viewModel)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Meat Type Grid
struct MeatTypeGrid: View {
    @Binding var selectedMeat: String
    let meatTypes: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select Meat Type", systemImage: "fork.knife")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(meatTypes, id: \.self) { meat in
                    Button(action: {
                        HapticsManager.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMeat = meat
                        }
                    }) {
                        HStack {
                            Text(meatIcon(for: meat))
                                .font(.system(size: 20))
                            Text(meat)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(selectedMeat == meat ? .white : .white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMeat == meat ? 
                                      LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                      LinearGradient(colors: [.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMeat == meat ? Color.clear : Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .scaleEffect(selectedMeat == meat ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func meatIcon(for meat: String) -> String {
        switch meat.lowercased() {
        case "brisket": return "🥩"
        case "beef ribs": return "🐄"
        case "pork ribs": return "🍖"
        case "pork shoulder": return "🐷"
        case "chicken": return "🐔"
        case "turkey": return "🦃"
        case "pork butt": return "🐷"
        default: return "🔥"
        }
    }
}

// MARK: - Weight Input Field
struct WeightInputField: View {
    @Binding var weight: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Weight (lbs)", systemImage: "scalemass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            TextField("Enter weight in pounds", text: $weight)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.orange : Color.white.opacity(0.2), lineWidth: isFocused ? 2 : 1)
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Completion Time Field
struct CompletionTimeField: View {
    @Binding var targetCompletion: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ready By", systemImage: "clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            DatePicker("", selection: $targetCompletion, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Plan Button
struct PlanButton: View {
    @ObservedObject var viewModel: CookPlannerViewModel
    
    var body: some View {
        Button(action: {
            HapticsManager.impact(.medium)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                viewModel.generateCookPlan()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .medium))
                
                Text("Get AI Cook Plan")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(viewModel.isLoading)
        .opacity(viewModel.isLoading ? 0.7 : 1.0)
    }
}

// MARK: - Chat Interface Card
struct ChatInterfaceCard: View {
    @ObservedObject var viewModel: CookPlannerViewModel
    @FocusState.Binding var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.orange)
                
                Text("AI BBQ Assistant")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("New Plan") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.showChat = false
                        viewModel.chatMessages.removeAll()
                        viewModel.selectedMeat = ""
                        viewModel.weight = ""
                        viewModel.isReadyToStart = false
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.orange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.chatMessages) { message in
                            PlannerChatBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isLoading {
                            TypingIndicator()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.chatMessages.count) { _, _ in
                    if let lastMessage = viewModel.chatMessages.last {
                        withAnimation(.easeOut(duration: 0.5)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Bar
            if !viewModel.isReadyToStart {
                PlannerChatInputBar(viewModel: viewModel, isInputFocused: $isInputFocused)
            } else {
                // Show completion message with continue button
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                        
                        Text("Session Created!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Ready to start cooking")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button(action: {
                        print("[CookPlannerView] Ready to Smoke tapped")
                        if let plan = viewModel.cookPlan {
                            print("[CookPlannerView] Starting new session with plan: \(plan)")
                            Task {
                                await SharedSessionManager.shared.startNewSession(with: plan)
                                SharedSessionManager.shared.shouldNavigateToSession = true
                                print("[CookPlannerView] shouldNavigateToSession set to true")
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 18, weight: .medium))
                            
                            Text("Ready to Smoke?")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
                .background(.ultraThinMaterial)
            }
            
            if viewModel.showChat && !viewModel.isLoading && !viewModel.isReadyToStart && !viewModel.chatMessages.isEmpty {
                Button(action: {
                    HapticsManager.impact(.medium)
                    // Mark as ready to start, trigger session creation logic
                    viewModel.isReadyToStart = true
                    if let plan = viewModel.cookPlan {
                        Task {
                            await SharedSessionManager.shared.startNewSession(with: plan)
                            SharedSessionManager.shared.shouldNavigateToSession = true
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("Ready to Smoke?")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .frame(height: 500)
    }
}

// MARK: - Chat Bubble View
struct PlannerChatBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            Text(message.text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(message.isUser ? .white : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(message.isUser ? 
                              LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(message.isUser ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                )
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Chat Input Bar
struct PlannerChatInputBar: View {
    @ObservedObject var viewModel: CookPlannerViewModel
    @FocusState.Binding var isInputFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about your cook plan...", text: $viewModel.currentInput)
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    viewModel.sendMessage()
                }
            
            Button(action: {
                HapticsManager.impact(.light)
                viewModel.sendMessage()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: viewModel.currentInput.isEmpty ? [.gray] : [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                    )
            }
            .disabled(viewModel.currentInput.isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    CookPlannerView()
} 