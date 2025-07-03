import Foundation
import Combine

class CookPlanSummaryViewModel: ObservableObject {
    @Published var meatType: String = ""
    @Published var weight: Double = 0
    @Published var readyTime: Date = Date()
    @Published var summary: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Publishers.CombineLatest3($meatType, $weight, $readyTime)
            .sink { [weak self] meat, weight, ready in
                self?.summary = Self.generateSummary(meatType: meat, weight: weight, readyTime: ready)
            }
            .store(in: &cancellables)
    }
    
    static func generateSummary(meatType: String, weight: Double, readyTime: Date) -> String {
        guard !meatType.isEmpty, weight > 0 else { return "" }
        let hoursPerPound = 1.5
        let cookHours = hoursPerPound * weight
        let startTime = Calendar.current.date(byAdding: .minute, value: -Int(cookHours*60), to: readyTime) ?? readyTime
        let wrapTime = Calendar.current.date(byAdding: .hour, value: -6, to: readyTime) ?? readyTime
        let restStart = Calendar.current.date(byAdding: .hour, value: -1, to: readyTime) ?? readyTime
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let readyString = Self.friendlyTime(readyTime)
        let startString = Self.friendlyTime(startTime)
        let wrapString = Self.friendlyTime(wrapTime)
        let restStartString = Self.friendlyTime(restStart)
        let totalHours = Int(round(cookHours))
        let meat = meatType.lowercased().hasPrefix("a ") || meatType.lowercased().hasPrefix("an ") ? meatType : "your \(weight.clean) lb \(meatType)"
        return "To have \(meat) ready by \(readyString), start your cook at \(startString). Wrap at \(wrapString), and let it rest from \(restStartString) to \(readyString). Total estimated cook time: \(totalHours) hours."
    }
    
    static func friendlyTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

private extension Double {
    var clean: String {
        self.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.1f", self)
    }
} 