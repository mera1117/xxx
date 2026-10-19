import Foundation
import SwiftUI

enum ShiftKind: String, Codable, CaseIterable, Identifiable {
    case day = "白班"
    case night = "夜班"
    case evening = "中班"
    case rest = "休息"
    case leave = "请假"
    case custom = "自定义"

    var id: String { rawValue }
    var color: Color {
        switch self {
        case .day: return .blue
        case .night: return .indigo
        case .evening: return .orange
        case .rest: return .green
        case .leave: return .pink
        case .custom: return .purple
        }
    }
}

struct ShiftEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var kind: ShiftKind
    var title: String
    var startTime: String = "09:00"
    var endTime: String = "17:00"
    var note: String = ""
}

struct CycleRule: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// One item per day in the repeating cycle.
    var cycle: [ShiftKind]
    var anchorDate: Date
    var reminderMinutes: Int = 60
    var isEnabled: Bool = true

    static let starter = CycleRule(
        name: "上二休二",
        cycle: [.day, .day, .rest, .rest],
        anchorDate: Calendar.current.startOfDay(for: Date()),
        reminderMinutes: 60
    )
}

struct LocalTeamMember: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var role: String = ""
    var note: String = ""
}

struct AppData: Codable {
    var entries: [ShiftEntry] = []
    var rules: [CycleRule] = [.starter]
    var teamMembers: [LocalTeamMember] = []
    var selectedRuleID: UUID? = nil
    var reminderEnabled: Bool = false
    var defaultStartTime: String = "09:00"
    var defaultEndTime: String = "17:00"
}
