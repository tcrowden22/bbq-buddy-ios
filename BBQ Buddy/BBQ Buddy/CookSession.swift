import Foundation
import SwiftUI

struct CookSession: Identifiable, Codable {
    let id: UUID
    let cookPlanId: UUID
    let startTime: Date
    let endTime: Date
    let meatType: String
    let weight: Double
    let targetTemp: Int
    let notes: [CookNote]
    var aiFeedback: String?
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return "\(hours)h \(minutes)m"
    }
    
    struct TemperatureReading: Codable, Identifiable {
        var id: UUID = UUID()
        let time: Date
        let temperature: Double
    }
} 