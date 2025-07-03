import Foundation
import SwiftUI
import Supabase

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var sessions: [CookSession] = []
    @Published var selectedSession: CookSession?
    @Published var noteDraft: String = ""
    @Published var aiFeedbackDraft: String = ""
    
    private let client: SupabaseClient
    private let dateFormatter: ISO8601DateFormatter
    
    init() {
        client = SupabaseClient(supabaseURL: URL(string: SupabaseConfig.supabaseURL)!, supabaseKey: SupabaseConfig.supabaseAnonKey)
        
        // Configure date formatter to handle Supabase's date format
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        Task {
            await loadSessions()
        }
    }
    
    func loadSessions() async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            print("[HistoryViewModel] Error: No user ID found when loading sessions")
            return
        }
        
        print("[HistoryViewModel] Loading sessions for user: \(userId)")
        
        do {
            let response = try await client.database
                .from("cook_sessions")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
            
            print("[HistoryViewModel] Received response from Supabase")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try parsing with fractional seconds first
                if let date = self.dateFormatter.date(from: dateString) {
                    return date
                }
                
                // If that fails, try without fractional seconds
                self.dateFormatter.formatOptions = [.withInternetDateTime]
                if let date = self.dateFormatter.date(from: dateString) {
                    // Reset format options for next time
                    self.dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return date
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string \(dateString)"
                )
            }
            
            do {
                let decodedSessions = try decoder.decode([CookSessionRecord].self, from: response.data)
                print("[HistoryViewModel] Successfully decoded \(decodedSessions.count) sessions")
                
                self.sessions = decodedSessions.map { record in
                    print("[HistoryViewModel] Processing session: \(record.id)")
                    return record.toCookSession()
                }
                print("[HistoryViewModel] Successfully loaded \(self.sessions.count) sessions")
            } catch {
                print("[HistoryViewModel] Error decoding sessions: \(error)")
                print("[HistoryViewModel] Response data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            }
        } catch {
            print("[HistoryViewModel] Error loading sessions: \(error)")
        }
    }
    
    func deleteSession(_ session: CookSession) async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        
        print("[HistoryViewModel] Deleting session: \(session.id)")
        
        do {
            try await client.database
                .from("cook_sessions")
                .delete()
                .eq("id", value: session.id.uuidString)
                .eq("user_id", value: userId)
                .execute()
            
            // Remove from local state
            sessions.removeAll { $0.id == session.id }
            if selectedSession?.id == session.id {
                selectedSession = nil
            }
            
            print("[HistoryViewModel] Successfully deleted session")
        } catch {
            print("[HistoryViewModel] Error deleting session: \(error)")
        }
    }
    
    func addNote(to session: CookSession, note: String) {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        
        Task {
            do {
                try await client.database
                    .from("cook_sessions")
                    .update(["notes": note])
                    .eq("id", value: session.id.uuidString)
                    .eq("user_id", value: userId)
                    .execute()
                
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx].notes = note
                }
            } catch {
                print("[HistoryViewModel] Error adding note: \(error)")
            }
        }
    }
    
    func addAIFeedback(to session: CookSession, feedback: String) {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        
        Task {
            do {
                try await client.database
                    .from("cook_sessions")
                    .update(["ai_feedback": feedback])
                    .eq("id", value: session.id.uuidString)
                    .eq("user_id", value: userId)
                    .execute()
                
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx].aiFeedback = feedback
                }
            } catch {
                print("[HistoryViewModel] Error adding AI feedback: \(error)")
            }
        }
    }
    
    func analyzePhoto(for session: CookSession, photo: UIImage) {
        MeatPhotoAnalyzer.shared.analyze(photo: photo) { [weak self] feedback in
            if let feedback = feedback {
                Task { @MainActor in
                    self?.addAIFeedback(to: session, feedback: feedback)
                }
            }
        }
    }
}

// Helper struct for decoding Supabase response
private struct CookSessionRecord: Codable {
    let id: String
    let user_id: String
    let meat_type: String
    let weight: Double
    let start_time: Date
    let end_time: Date
    let temperature_readings: [TemperatureReading]
    let notes: String?
    let ai_feedback: String?
    let created_at: Date
    
    struct TemperatureReading: Codable {
        let id: String
        let time: Date
        let temperature: Double
        
        func toCookSessionReading() -> CookSession.TemperatureReading {
            CookSession.TemperatureReading(
                id: UUID(uuidString: id) ?? UUID(),
                time: time,
                temperature: temperature
            )
        }
    }
    
    func toCookSession() -> CookSession {
        CookSession(
            id: UUID(uuidString: id) ?? UUID(),
            meatType: meat_type,
            weight: weight,
            startTime: start_time,
            endTime: end_time,
            temperatureReadings: temperature_readings.map { $0.toCookSessionReading() },
            notes: notes,
            aiFeedback: ai_feedback
        )
    }
} 