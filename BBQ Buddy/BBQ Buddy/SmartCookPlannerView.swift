import SwiftUI

struct CookSessionModel: Identifiable, Codable {
    let id: UUID
    var meatType: String
    var weight: Double
    var readyTime: Date
    var remind: Bool?
    var woodType: String?
    var barkPreference: String?
    var logCook: Bool?
}

struct CookSuggestionEngine {
    static func suggestion(for date: Date = Date(), timeAvailable: Double? = nil) -> (prompt: String, meat: String) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let month = calendar.component(.month, from: date)
        let season: String = {
            switch month {
            case 12, 1, 2: return "winter"
            case 3, 4, 5: return "spring"
            case 6, 7, 8: return "summer"
            default: return "fall"
            }
        }()
        // Time-based
        if let hours = timeAvailable, hours <= 4 {
            return ("Only have \(Int(hours)) hours? Try baby back ribs or chicken!", "Baby Back Ribs")
        }
        // Day-based
        if weekday == 7 && hour < 15 { // Saturday before 3pm
            return ("It's Saturday afternoon — brisket might be perfect for tomorrow's lunch.", "Brisket")
        } else if weekday == 1 { // Sunday
            return ("Sunday is great for pork shoulder or pulled pork!", "Pork Shoulder")
        }
        // Season-based
        if season == "summer" {
            return ("Summer BBQ? Ribs or chicken are always a hit!", "Ribs")
        } else if season == "winter" {
            return ("Cold outside? Try a smoked chuck roast or beef ribs!", "Chuck Roast")
        }
        // Default
        return ("Not sure what to cook? Brisket, ribs, or chicken are always great!", "Brisket")
    }
}

struct SmartCookPlannerView: View {
    enum Step {
        case meatType, weight, readyTime, summary, remind, wood, bark, log, done
    }
    
    @State private var step: Step = .meatType
    @State private var meatType: String = ""
    @State private var weight: String = ""
    @State private var readyTime: Date = Date().addingTimeInterval(60*60*6)
    @State private var showSummary = false
    @State private var chat: [ChatBubble] = []
    @FocusState private var isInputFocused: Bool
    @State private var session = CookSessionModel(id: UUID(), meatType: "", weight: 0, readyTime: Date())
    
    struct ChatBubble: Identifiable {
        let id = UUID()
        let text: String
        let isUser: Bool
        let buttons: [ChatButton]?
    }
    struct ChatButton: Identifiable {
        let id = UUID()
        let title: String
        let action: () -> Void
    }
    
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
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            SuggestionBubbleView(step: step, meatType: meatType)
                            ChatBubblesView(chat: chat)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 8)
                    }
                    .onChange(of: chat.count) { _, _ in
                        if let last = chat.last?.id {
                            withAnimation(.easeOut(duration: 0.5)) { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
                }
                Divider()
                Group {
                    if step == .meatType {
                        HStack {
                            TextField("e.g. Brisket, Ribs, Chicken", text: $meatType)
                                .textFieldStyle(.roundedBorder)
                                .focused($isInputFocused)
                                .frame(minHeight: 36)
                            sendButton(enabled: !meatType.trimmingCharacters(in: .whitespaces).isEmpty) {
                                addUserReply(meatType)
                                session.meatType = meatType
                                step = .weight
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    addBotPrompt("How much does it weigh?")
                                }
                            }
                        }
                    } else if step == .weight {
                        HStack {
                            TextField("Weight in pounds", text: $weight)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .focused($isInputFocused)
                                .frame(minHeight: 36)
                            sendButton(enabled: Double(weight) != nil && Double(weight)! > 0) {
                                addUserReply(weight + " lbs")
                                session.weight = Double(weight) ?? 0
                                step = .readyTime
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    addBotPrompt("When do you want it ready by?")
                                }
                            }
                        }
                    } else if step == .readyTime {
                        HStack {
                            DatePicker("", selection: $readyTime, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .frame(maxWidth: 180)
                            sendButton(enabled: true) {
                                addUserReply(formatted(readyTime))
                                session.readyTime = readyTime
                                step = .summary
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showSummary = true
                                    addBotPrompt(summaryText())
                                }
                            }
                        }
                    } else if step == .remind || step == .wood || step == .bark || step == .log {
                        Color.clear.frame(height: 1) // keep layout
                    } else {
                        EmptyView()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            if chat.isEmpty {
                addBotPrompt("What are you cooking today?")
            }
        }
        .onChange(of: showSummary) { _, show in
            if show {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    step = .remind
                    askRemind()
                }
            }
        }
        .navigationTitle("Smart Cook Planner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
    func sendButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticsManager.impact(.medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
        }) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(enabled ? .white : .gray)
                .background(
                    Circle()
                        .fill(enabled ? AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.gray.opacity(0.3)))
                        .frame(width: 44, height: 44)
                )
                .scaleEffect(enabled ? 1.0 : 0.9)
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
    
    func addBotPrompt(_ text: String, buttons: [ChatButton]? = nil) {
        chat.append(ChatBubble(text: text, isUser: false, buttons: buttons))
    }
    func addUserReply(_ text: String) {
        chat.append(ChatBubble(text: text, isUser: true, buttons: nil))
    }
    
    func summaryText() -> String {
        guard let weightVal = Double(weight) else { return "" }
        let hoursPerPound = 1.5
        let cookHours = hoursPerPound * weightVal
        let startTime = Calendar.current.date(byAdding: .minute, value: -Int(cookHours*60), to: readyTime) ?? readyTime
        let wrapTime = Calendar.current.date(byAdding: .hour, value: -6, to: readyTime) ?? readyTime
        let restTime = Calendar.current.date(byAdding: .hour, value: 1, to: readyTime) ?? readyTime
        return "Here's your plan for \(meatType):\n\n• Start at \(formatted(startTime))\n• Wrap at \(formatted(wrapTime))\n• Rest until \(formatted(restTime))\n\nHappy BBQing!"
    }
    
    // --- Conversational AI Follow-ups ---
    func askRemind() {
        addBotPrompt("Would you like me to remind you when it's time to wrap or rest?", buttons: [
            ChatButton(title: "Yes, please") {
                addUserReply("Yes, please")
                session.remind = true
                step = .wood
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { askWood() }
            },
            ChatButton(title: "No, thanks") {
                addUserReply("No, thanks")
                session.remind = false
                step = .wood
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { askWood() }
            }
        ])
    }
    func askWood() {
        let woods = ["Hickory", "Apple", "Cherry", "Oak", "Pecan", "Mesquite"]
        addBotPrompt("What kind of wood are you using?", buttons: woods.map { wood in
            ChatButton(title: wood) {
                addUserReply(wood)
                session.woodType = wood
                step = .bark
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { askBark() }
            }
        })
    }
    func askBark() {
        addBotPrompt("Do you prefer a bark-heavy cook or juicy wrap?", buttons: [
            ChatButton(title: "Bark-heavy") {
                addUserReply("Bark-heavy")
                session.barkPreference = "Bark-heavy"
                step = .log
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { askLog() }
            },
            ChatButton(title: "Juicy wrap") {
                addUserReply("Juicy wrap")
                session.barkPreference = "Juicy wrap"
                step = .log
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { askLog() }
            }
        ])
    }
    func askLog() {
        addBotPrompt("Want to log this cook for future reference?", buttons: [
            ChatButton(title: "Yes, log it") {
                addUserReply("Yes, log it")
                session.logCook = true
                step = .done
                saveSession()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    addBotPrompt("Cook logged! You're all set. Good luck!")
                }
            },
            ChatButton(title: "No, just cook") {
                addUserReply("No, just cook")
                session.logCook = false
                step = .done
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    addBotPrompt("No problem! Enjoy your BBQ.")
                }
            }
        ])
    }
    
    // Convert ChatBubble to ChatMessage
    private func convertToMessages(_ bubbles: [ChatBubble]) -> [ChatMessage] {
        return bubbles.map { bubble in
            ChatMessage(text: bubble.text, isUser: bubble.isUser)
        }
    }

    func saveSession() {
        print("[SmartCookPlannerView] saveSession called")
        
        // Check if user is authenticated
        guard AuthManager.shared.isAuthenticated else {
            print("[SmartCookPlannerView] User not authenticated, skipping session save")
            return
        }
        
        guard let userId = AuthManager.shared.currentUser?.id else {
            print("[SmartCookPlannerView] No current user ID found")
            return
        }
        
        print("[SmartCookPlannerView] User authenticated with ID: \(userId)")
        
        // Create session name
        let sessionName = "BBQ Plan: \(session.meatType) (\(formatted(Date())))"
        
        // Create metadata
        let metadata: [String: String] = [
            "meat_type": session.meatType,
            "weight": "\(session.weight)",
            "ready_time": ISO8601DateFormatter().string(from: session.readyTime),
            "wood_type": session.woodType ?? "",
            "bark_preference": session.barkPreference ?? "",
            "log_cook": session.logCook == true ? "true" : "false"
        ]
        
        print("[SmartCookPlannerView] Saving session with \(chat.count) messages")
        print("[SmartCookPlannerView] Session name: \(sessionName)")
        print("[SmartCookPlannerView] Metadata: \(metadata)")
        
        // Convert chat bubbles to messages
        let messages = convertToMessages(chat)
        
        // Save using SessionStorageManager
        SessionStorageManager.shared.saveSession(
            sessionName: sessionName,
            messages: messages,
            metadata: metadata
        ) { result in
            switch result {
            case .success:
                print("[SmartCookPlannerView] Session saved successfully!")
            case .failure(let error):
                print("[SmartCookPlannerView] Failed to save session: \(error)")
                print("[SmartCookPlannerView] Error details: \(error.localizedDescription)")
            }
        }
    }
    
    func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct SuggestionBubbleView: View {
    let step: SmartCookPlannerView.Step
    let meatType: String
    var body: some View {
        Group {
            if step == .meatType && meatType.trimmingCharacters(in: .whitespaces).isEmpty {
                let suggestion = CookSuggestionEngine.suggestion(for: Date(), timeAvailable: nil)
                HStack {
                    Text(suggestion.prompt)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(AnyShapeStyle(.ultraThinMaterial))
                        )
                        .foregroundColor(.primary)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                        .frame(maxWidth: 260, alignment: .leading)
                    Spacer()
                }
            } else {
                EmptyView()
            }
        }
    }
}

struct ChatBubblesView: View {
    let chat: [SmartCookPlannerView.ChatBubble]
    var body: some View {
        ForEach(chat) { bubble in
            HStack {
                if bubble.isUser { Spacer() }
                VStack(alignment: bubble.isUser ? .trailing : .leading, spacing: 8) {
                    Text(bubble.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(bubble.isUser ? AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(.ultraThinMaterial))
                        )
                        .foregroundColor(bubble.isUser ? .white : .primary)
                        .shadow(color: bubble.isUser ? Color.blue.opacity(0.15) : Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                        .frame(maxWidth: 260, alignment: bubble.isUser ? .trailing : .leading)
                    if let buttons = bubble.buttons {
                        HStack(spacing: 12) {
                            ForEach(buttons) { btn in
                                Button(action: btn.action) {
                                    Text(btn.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule().fill(AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)))
                                        )
                                        .foregroundColor(.white)
                                        .scaleEffect(0.97)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                if !bubble.isUser { Spacer() }
            }
            .id(bubble.id)
        }
    }
}

#Preview {
    SmartCookPlannerView()
} 