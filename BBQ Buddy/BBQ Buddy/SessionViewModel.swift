import Foundation
import UserNotifications
import Combine
import Supabase
import SwiftUI

class SessionViewModel: ObservableObject {
    @Published var targetTempF: Double = 203 // Default target temp in Fahrenheit
    @Published var wrapTempF: Double = 165
    @Published var currentTempF: Double = 0.0
    @Published var timeUntilNextAction: TimeInterval? = nil
    @Published var nextAction: String? = nil
    @Published var showWrapAlert: Bool = false
    @Published var showPullAlert: Bool = false
    @Published var isSessionComplete: Bool = false
    @Published var temperatureReadings: [CookSession.TemperatureReading] = []
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var sessionStartTime: Date?
    private let client: SupabaseClient
    private var hasShownWrapAlert = false
    private var hasShownPullAlert = false
    private let storageManager = SessionStorageManager()
    
    init() {
        client = SupabaseClient(supabaseURL: URL(string: SupabaseConfig.supabaseURL)!, supabaseKey: SupabaseConfig.supabaseAnonKey)
        sessionStartTime = Date()
    }
    
    func startMonitoring(thermometerManager: ThermometerManager) {
        sessionStartTime = Date()
        thermometerManager.$latestTemperature
            .receive(on: RunLoop.main)
            .sink { [weak self] tempC in
                guard let self = self else { return }
                if let tempC = tempC {
                    let tempF = tempC * 9/5 + 32
                    self.currentTempF = tempF
                    self.checkAlerts(tempF: tempF)
                    
                    // Record temperature reading
                    let reading = CookSession.TemperatureReading(
                        time: Date(),
                        temperature: tempF
                    )
                    self.temperatureReadings.append(reading)
                }
            }
            .store(in: &cancellables)
        startTimer()
        requestNotificationPermissions()
    }
    
    private func checkAlerts(tempF: Double) {
        if !hasShownWrapAlert && tempF >= wrapTempF {
            showWrapAlert = true
            hasShownWrapAlert = true
            scheduleNotification(title: "Wrap Time!", body: "Meat has reached \(Int(wrapTempF))°F. Time to wrap.")
            nextAction = "Pull and rest at \(Int(targetTempF))°F"
        } else if !hasShownPullAlert && tempF >= targetTempF {
            showPullAlert = true
            hasShownPullAlert = true
            scheduleNotification(title: "Pull & Rest!", body: "Meat has reached \(Int(targetTempF))°F. Time to pull and rest.")
            nextAction = nil
            isSessionComplete = true
        } else if tempF < wrapTempF {
            nextAction = "Wrap at \(Int(wrapTempF))°F"
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateTimeUntilNextAction()
        }
    }
    
    private func updateTimeUntilNextAction() {
        guard let temp = currentTempF else { timeUntilNextAction = nil; return }
        let rate = 1.0 // Placeholder: degrees per minute, should be estimated
        if !showWrapAlert && temp < wrapTempF {
            timeUntilNextAction = (wrapTempF - temp) / rate * 60
        } else if !showPullAlert && temp < targetTempF {
            timeUntilNextAction = (targetTempF - temp) / rate * 60
        } else {
            timeUntilNextAction = nil
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[SessionViewModel] Error requesting notification permissions: \(error)")
            }
        }
    }
    
    private func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // Helper struct for inserting cook sessions
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
    
    @MainActor
    func endSession(cookPlan: CookPlan?, notes: [CookNote]) async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString,
              let startTime = sessionStartTime,
              let cookPlan = cookPlan else {
            print("[SessionViewModel] Cannot end session: missing required data")
            return
        }
        
        let endTime = Date()
        let session = CookSession(
            id: UUID(),
            cookPlanId: cookPlan.id,
            startTime: startTime,
            endTime: endTime,
            meatType: cookPlan.meatType,
            weight: cookPlan.weight,
            targetTemp: cookPlan.temperature ?? 203,
            notes: notes
        )
        
        print("[SessionViewModel] Ending session with \(temperatureReadings.count) temperature readings")
        
        do {
            let dateFormatter = ISO8601DateFormatter()
            
            let record = CookSessionInsert(
                id: session.id.uuidString,
                user_id: userId,
                meat_type: session.meatType,
                weight: session.weight,
                start_time: dateFormatter.string(from: session.startTime),
                end_time: dateFormatter.string(from: session.endTime),
                temperature_readings: temperatureReadings.map { reading in
                    CookSessionInsert.TemperatureReading(
                        id: reading.id.uuidString,
                        time: dateFormatter.string(from: reading.time),
                        temperature: reading.temperature
                    )
                },
                notes: nil,
                ai_feedback: nil
            )
            
            print("[SessionViewModel] Saving session to Supabase")
            
            try await client.database
                .from("cook_sessions")
                .insert(record)
                .execute()
            
            print("[SessionViewModel] Session saved to history successfully")
            
            // Clean up
            timer?.invalidate()
            timer = nil
            cancellables.removeAll()
            
            await storageManager.saveSession(session)
            
        } catch {
            print("[SessionViewModel] Error saving session to history: \(error)")
            print("[SessionViewModel] Error details: \(error.localizedDescription)")
        }
    }
} 