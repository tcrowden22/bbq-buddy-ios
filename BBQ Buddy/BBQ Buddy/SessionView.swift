import SwiftUI
import Charts
import Foundation

struct SessionView: View {
    @EnvironmentObject var sessionManager: SharedSessionManager
    @StateObject private var viewModel = SessionViewModel()
    @StateObject private var thermometerManager = ThermometerManager()
    @State private var temperatureHistory: [TemperaturePoint] = []
    @State private var animateProgress = false
    @State private var glowOpacity = 0.0
    @State private var isChatExpanded = false
    @State private var cookNotes: [CookNote] = []
    
    var body: some View {
        ZStack {
            // Background gradient
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
                ScrollView {
                    VStack(spacing: 24) {
                        if let cookPlan = sessionManager.currentCookPlan {
                            CookOverviewCard(cookPlan: cookPlan)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Temperature Display
                        TemperatureDisplay(
                            currentTemp: viewModel.currentTempF,
                            targetTemp: viewModel.targetTempF,
                            wrapTemp: viewModel.wrapTempF,
                            animateProgress: $animateProgress,
                            glowOpacity: $glowOpacity
                        )
                        
                        // Temperature Chart
                        VStack(spacing: 16) {
                            HStack {
                                Text("Temperature History")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            // Chart
                            TemperatureChart(data: temperatureHistory)
                                .frame(height: 200)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        
                        // Cook Notes
                        CookNotesView(notes: $cookNotes)
                        
                        if viewModel.isSessionComplete {
                            Button(action: {
                                Task {
                                    await viewModel.endSession(
                                        cookPlan: sessionManager.currentCookPlan,
                                        notes: cookNotes
                                    )
                                    sessionManager.clearSession()
                                }
                            }) {
                                Text("Complete Session")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 32)
                }
                
                // Chat Assistant Panel
                ChatAssistantPanel(
                    isExpanded: $isChatExpanded,
                    cookPlan: sessionManager.currentCookPlan,
                    temperatureHistory: temperatureHistory,
                    cookNotes: cookNotes
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .alert("Time to Wrap!", isPresented: $viewModel.showWrapAlert) {
            Button("OK") {}
        } message: {
            Text("Your meat has reached the wrapping temperature.")
        }
        .alert("Time to Pull!", isPresented: $viewModel.showPullAlert) {
            Button("OK") {}
        } message: {
            Text("Your meat has reached the target temperature.")
        }
        .onAppear {
            startMonitoring()
        }
        .onChange(of: sessionManager.currentCookPlan) { _, cookPlan in
            if let plan = cookPlan {
                // Update session parameters based on cook plan
                viewModel.targetTempF = Double(plan.temperature ?? 203)
                viewModel.wrapTempF = plan.temperature == 165 ? 140 : 165 // Chicken vs other meats
                startMonitoring()
            }
        }
        .onChange(of: thermometerManager.latestTemperature) { _, temp in
            updateTemperatureHistory(temp)
            updateGlowEffect()
        }
    }
    
    private func startMonitoring() {
        viewModel.startMonitoring(thermometerManager: thermometerManager)
        
        withAnimation(.easeInOut(duration: 1.0)) {
            animateProgress = true
        }
        
        // Simulate temperature data for demo
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            let simulatedTemp = Double.random(in: 150...200)
            thermometerManager.latestTemperature = simulatedTemp
        }
    }
    
    private func updateTemperatureHistory(_ temp: Double?) {
        guard let temp = temp else { return }
        let tempF = temp * 9/5 + 32
        let point = TemperaturePoint(time: Date(), temperature: tempF)
        
        temperatureHistory.append(point)
        
        // Keep only last 20 points
        if temperatureHistory.count > 20 {
            temperatureHistory.removeFirst()
        }
    }
    
    private func updateGlowEffect() {
        if let tempF = viewModel.currentTempF {
            if tempF >= viewModel.wrapTempF {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowOpacity = 1.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    glowOpacity = 0.0
                }
            }
        }
    }
}

struct TemperaturePoint: Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Double
}

struct SessionHeaderView: View {
    let cookPlan: CookPlan?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Session")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let plan = cookPlan {
                        Text("\(String(format: "%.1f", plan.weight)) lbs \(plan.meatType)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Monitor your BBQ in real-time")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
            }
            
            // Show cook plan summary card if available
            if let plan = cookPlan {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("🔥 \(plan.meatType)")
                        Spacer()
                        Text("\(String(format: "%.1f lbs", plan.weight))")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    
                    HStack {
                        Text("🌡️ Target: \(plan.temperature ?? 203)°F")
                        Spacer()
                        Text("⏰ Ready: \(formatted(plan.completionTime))")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.orange)
                    
                    if let wrap = plan.wrapTime {
                        HStack {
                            Text("📦 Wrap: \(formatted(wrap))")
                            Spacer()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    }
                    if let rest = plan.restTime {
                        HStack {
                            Text("🛌 Rest: \(formatted(rest))")
                            Spacer()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.orange.opacity(0.12), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProgressRingView: View {
    @ObservedObject var viewModel: SessionViewModel
    @ObservedObject var thermometerManager: ThermometerManager
    @Binding var animateProgress: Bool
    @Binding var glowOpacity: Double
    
    private var progress: Double {
        guard let currentTemp = thermometerManager.latestTemperature else { return 0.0 }
        let tempF = currentTemp * 9/5 + 32
        return min(tempF / viewModel.targetTempF, 1.0)
    }
    
    private var currentTempF: Double {
        guard let temp = thermometerManager.latestTemperature else { return 0.0 }
        return temp * 9/5 + 32
    }
    
    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.orange.opacity(glowOpacity), .red.opacity(glowOpacity)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 8
                )
                .frame(width: 280, height: 280)
                .blur(radius: 20)
                .opacity(glowOpacity)
            
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 12)
                .frame(width: 240, height: 240)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animateProgress ? progress : 0)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.5), value: progress)
            
            // Center content
            VStack(spacing: 8) {
                // Current temperature
                Text("\(Int(currentTempF))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.bouncy(duration: 0.8), value: currentTempF)
                
                Text("°F")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                // Progress percentage
                Text("\(Int(progress * 100))% complete")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                // Connection status
                HStack(spacing: 8) {
                    Circle()
                        .fill(thermometerManager.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(thermometerManager.isConnected ? "Connected" : "Disconnected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .frame(height: 300)
    }
}

struct TimerStatusPanel: View {
    @ObservedObject var viewModel: SessionViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if let time = viewModel.timeUntilNextAction,
               let action = viewModel.nextAction {
                
                VStack(spacing: 12) {
                    // Next action icon
                    actionIcon(for: action)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(actionColor(for: action))
                    
                    Text(action)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Countdown timer
                    Text(formatTime(time))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(actionColor(for: action))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(actionColor(for: action).opacity(0.3), lineWidth: 2)
                                )
                        )
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text("Cook Complete!")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private func actionIcon(for action: String) -> Image {
        if action.lowercased().contains("wrap") {
            return Image(systemName: "bandage.fill")
        } else if action.lowercased().contains("rest") {
            return Image(systemName: "bed.double.fill")
        } else if action.lowercased().contains("pull") {
            return Image(systemName: "hand.raised.fill")
        } else {
            return Image(systemName: "timer")
        }
    }
    
    private func actionColor(for action: String) -> Color {
        if action.lowercased().contains("wrap") {
            return .orange
        } else if action.lowercased().contains("rest") {
            return .green
        } else if action.lowercased().contains("pull") {
            return .red
        } else {
            return .blue
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct TemperatureChartView: View {
    let temperatureHistory: [TemperaturePoint]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Temperature Chart")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if temperatureHistory.count >= 2 {
                Chart(temperatureHistory) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Temperature", point.temperature)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Time", point.time),
                        y: .value("Temperature", point.temperature)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .orange.opacity(0.2), .red.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 150)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.2))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("Collecting temperature data...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(height: 150)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

struct ActionButtonsView: View {
    @ObservedObject var viewModel: SessionViewModel
    @ObservedObject var thermometerManager: ThermometerManager
    @EnvironmentObject var sessionManager: SharedSessionManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isSessionComplete {
                Button(action: {
                    Task {
                        await viewModel.endSession(cookPlan: sessionManager.currentCookPlan)
                        sessionManager.clearSession()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Complete Session")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.green.opacity(0.8), .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            
            Button(action: {
                if let temp = thermometerManager.latestTemperature {
                    print("Current temperature: \(temp)°C")
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "thermometer")
                        .font(.system(size: 20))
                    Text("Check Temperature")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.8), .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            Button(action: {
                // Reset alerts for testing
                viewModel.showWrapAlert = false
                viewModel.showPullAlert = false
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                    Text("Reset Alerts")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.orange.opacity(0.8), .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct TargetTempCard: View {
    let icon: String
    let title: String
    let temp: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(temp)°F")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct CookOverviewCard: View {
    let cookPlan: CookPlan
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Cook Overview")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Content
            VStack(spacing: 12) {
                // Meat Info
                HStack {
                    Label {
                        Text(cookPlan.meatType)
                            .foregroundColor(.white)
                    } icon: {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Text("\(String(format: "%.1f", cookPlan.weight)) lbs")
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Time Info
                VStack(spacing: 8) {
                    HStack {
                        Label {
                            Text("Start Time")
                                .foregroundColor(.white)
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Text(formatTime(cookPlan.startTime))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    HStack {
                        Label {
                            Text("Expected Completion")
                                .foregroundColor(.white)
                        } icon: {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Text(formatTime(cookPlan.completionTime))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    HStack {
                        Label {
                            Text("Total Cook Time")
                                .foregroundColor(.white)
                        } icon: {
                            Image(systemName: "hourglass.circle.fill")
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Text(formatDuration(from: cookPlan.startTime, to: cookPlan.completionTime))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Temperature Info
                VStack(spacing: 8) {
                    HStack {
                        Label {
                            Text("Target Temperature")
                                .foregroundColor(.white)
                        } icon: {
                            Image(systemName: "thermometer.high")
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Text("\(cookPlan.temperature ?? 203)°F")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if let wrapTime = cookPlan.wrapTime {
                        HStack {
                            Label {
                                Text("Wrap at")
                                    .foregroundColor(.white)
                            } icon: {
                                Image(systemName: "square.stack.fill")
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            Text("165°F (\(formatTime(wrapTime)))")
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                if let restTime = cookPlan.restTime {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    HStack {
                        Label {
                            Text("Rest Period")
                                .foregroundColor(.white)
                        } icon: {
                            Image(systemName: "bed.double.fill")
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Text("30 min (\(formatTime(restTime)))")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: start, to: end)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        return "\(hours)h \(minutes)m"
    }
}

struct TemperatureChart: View {
    let data: [TemperaturePoint]
    
    var body: some View {
        GeometryReader { geometry in
            if data.count > 1 {
                let minTemp = (data.map { $0.temperature }.min() ?? 0) - 10
                let maxTemp = (data.map { $0.temperature }.max() ?? 200) + 10
                let tempRange = maxTemp - minTemp
                
                // Draw temperature lines
                Path { path in
                    let timeWidth = geometry.size.width / CGFloat(data.count - 1)
                    
                    path.move(to: CGPoint(
                        x: 0,
                        y: geometry.size.height * (1 - (data[0].temperature - minTemp) / tempRange)
                    ))
                    
                    for i in 1..<data.count {
                        let point = CGPoint(
                            x: CGFloat(i) * timeWidth,
                            y: geometry.size.height * (1 - (data[i].temperature - minTemp) / tempRange)
                        )
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                
                // Temperature points
                ForEach(0..<data.count, id: \.self) { i in
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .position(
                            x: CGFloat(i) * (geometry.size.width / CGFloat(data.count - 1)),
                            y: geometry.size.height * (1 - (data[i].temperature - minTemp) / tempRange)
                        )
                }
            } else {
                Text("Not enough data")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct TemperatureDisplay: View {
    let currentTemp: Double?
    let targetTemp: Double
    let wrapTemp: Double
    @Binding var animateProgress: Bool
    @Binding var glowOpacity: Double
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(
                        Color.white.opacity(0.2),
                        lineWidth: 15
                    )
                
                Circle()
                    .trim(from: 0, to: animateProgress ? 1 : 0)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 15,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: animateProgress)
                
                VStack(spacing: 8) {
                    if let temp = currentTemp {
                        Text("\(Int(temp))°F")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text("--°F")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text("Current Temperature")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 200, height: 200)
            .shadow(color: .orange.opacity(glowOpacity), radius: 20, x: 0, y: 0)
            
            // Target Temperature
            HStack(spacing: 20) {
                VStack {
                    Text("\(Int(targetTemp))°F")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Target")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                VStack {
                    Text("\(Int(wrapTemp))°F")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Wrap")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView()
    }
}

struct ChatAssistantPanel: View {
    @Binding var isExpanded: Bool
    let cookPlan: CookPlan?
    let temperatureHistory: [TemperaturePoint]
    let cookNotes: [CookNote]
    @State private var messageText: String = ""
    @StateObject private var viewModel = AssistantViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "message.circle.fill")
                        .foregroundColor(.orange)
                    Text("BBQ Assistant")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            
            if isExpanded {
                // Chat Messages
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
                
                // Input Field
                HStack(spacing: 12) {
                    TextField("Ask about your cook...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.white)
                        .accentColor(.orange)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
        .onChange(of: cookPlan) { _, newPlan in
            if let plan = newPlan {
                updateCookContext(plan)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = messageText
        messageText = ""
        
        Task {
            await viewModel.sendMessage(
                userMessage,
                cookPlan: cookPlan,
                temperatureHistory: temperatureHistory,
                cookNotes: cookNotes
            )
        }
    }
    
    private func updateCookContext(_ plan: CookPlan) {
        Task {
            await viewModel.updateCookContext(plan)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content)
                .padding(12)
                .background(message.isUser ? Color.orange : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(16)
                .cornerRadius(16, corners: message.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// Add corner radius extension if not already present
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct CookNotesView: View {
    @Binding var notes: [CookNote]
    @State private var newNoteText = ""
    @State private var selectedNoteType: CookNote.NoteType = .observation
    @State private var isAddingNote = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Cook Notes")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                
                Button(action: { withAnimation { isAddingNote.toggle() } }) {
                    Image(systemName: isAddingNote ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isAddingNote ? .gray : .orange)
                }
            }
            
            if isAddingNote {
                VStack(spacing: 12) {
                    // Note Type Picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CookNote.NoteType.allCases, id: \.self) { type in
                                Button(action: { selectedNoteType = type }) {
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue.capitalized)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedNoteType == type ? Color(type.color) : Color.gray.opacity(0.3))
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    // Note Input
                    HStack(alignment: .bottom) {
                        TextField("Add a note...", text: $newNoteText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($isInputFocused)
                            .lineLimit(1...5)
                        
                        Button(action: addNote) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .orange)
                        }
                        .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            
            // Notes List
            if notes.isEmpty {
                Text("No notes yet")
                    .foregroundColor(.white.opacity(0.6))
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(notes.sorted(by: { $0.timestamp > $1.timestamp })) { note in
                            NoteCard(note: note)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func addNote() {
        guard !newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let note = CookNote(
            id: UUID(),
            timestamp: Date(),
            content: newNoteText.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedNoteType
        )
        
        withAnimation {
            notes.append(note)
            newNoteText = ""
            isAddingNote = false
            isInputFocused = false
        }
    }
}

struct NoteCard: View {
    let note: CookNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: note.type.icon)
                    .foregroundColor(Color(note.type.color))
                
                Text(note.type.rawValue.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(note.type.color))
                
                Spacer()
                
                Text(note.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Content
            Text(note.content)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
} 