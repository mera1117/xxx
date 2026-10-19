import Foundation
import SwiftUI

@MainActor
final class ShiftStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    private let saveURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        saveURL = support.appendingPathComponent("shift-data.json")
        if let bytes = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder.shiftDecoder.decode(AppData.self, from: bytes) {
            data = decoded
        } else {
            data = AppData()
        }
        if data.selectedRuleID == nil { data.selectedRuleID = data.rules.first?.id }
        applyRule(to: Date())
    }

    var selectedRule: CycleRule? {
        data.rules.first(where: { $0.id == data.selectedRuleID }) ?? data.rules.first
    }

    func entry(for date: Date) -> ShiftEntry? {
        data.entries.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func kind(for date: Date) -> ShiftKind {
        if let item = entry(for: date) { return item.kind }
        guard let rule = selectedRule, !rule.cycle.isEmpty else { return .rest }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: rule.anchorDate)
        let target = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: anchor, to: target).day ?? 0
        let index = ((days % rule.cycle.count) + rule.cycle.count) % rule.cycle.count
        return rule.cycle[index]
    }

    func title(for date: Date) -> String {
        if let item = entry(for: date) { return item.title }
        return kind(for: date).rawValue
    }

    func setEntry(date: Date, kind: ShiftKind, title: String? = nil, start: String? = nil, end: String? = nil, note: String = "") {
        let day = Calendar.current.startOfDay(for: date)
        let old = entry(for: day)
        let item = ShiftEntry(
            id: old?.id ?? UUID(),
            date: day,
            kind: kind,
            title: title ?? kind.rawValue,
            startTime: start ?? old?.startTime ?? data.defaultStartTime,
            endTime: end ?? old?.endTime ?? data.defaultEndTime,
            note: note.isEmpty ? (old?.note ?? "") : note
        )
        data.entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: day) }
        data.entries.append(item)
        persist()
    }

    func clearOverride(for date: Date) {
        data.entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        persist()
    }

    func addRule(_ rule: CycleRule) {
        data.rules.append(rule)
        if data.selectedRuleID == nil { data.selectedRuleID = rule.id }
        persist()
    }

    func updateRule(_ rule: CycleRule) {
        if let index = data.rules.firstIndex(where: { $0.id == rule.id }) {
            data.rules[index] = rule
            persist()
        }
    }

    func deleteRule(_ rule: CycleRule) {
        data.rules.removeAll { $0.id == rule.id }
        if data.selectedRuleID == rule.id { data.selectedRuleID = data.rules.first?.id }
        persist()
    }

    func selectRule(_ id: UUID) {
        data.selectedRuleID = id
        persist()
    }

    func addMember(name: String, role: String) {
        data.teamMembers.append(LocalTeamMember(name: name, role: role))
        persist()
    }

    func deleteMember(_ member: LocalTeamMember) {
        data.teamMembers.removeAll { $0.id == member.id }
        persist()
    }

    func updateReminder(_ enabled: Bool) {
        data.reminderEnabled = enabled
        persist()
        if enabled {
            NotificationManager.shared.requestPermissionIfNeeded()
            scheduleUpcomingReminders()
        } else {
            NotificationManager.shared.cancelAll()
        }
    }

    func scheduleUpcomingReminders() {
        guard data.reminderEnabled else { return }
        NotificationManager.shared.cancelAll()
        let cal = Calendar.current
        for offset in 0..<21 {
            guard let date = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date())) else { continue }
            let shift = kind(for: date)
            guard shift != .rest, let entry = entry(for: date) else { continue }
            let parts = entry.startTime.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2,
                  let start = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date),
                  let fire = cal.date(byAdding: .minute, value: -60, to: start),
                  fire > Date() else { continue }
            NotificationManager.shared.schedule(title: "即将上班", body: "\(entry.title) 将在约 1 小时后开始", at: fire, identifier: entry.id.uuidString)
        }
    }

    func exportData() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ShiftAssistant-Backup.json")
        try JSONEncoder.shiftEncoder.encode(data).write(to: url, options: .atomic)
        return url
    }

    func importData(from url: URL) throws {
        let bytes = try Data(contentsOf: url)
        data = try JSONDecoder.shiftDecoder.decode(AppData.self, from: bytes)
        persist()
    }

    func replaceData(_ newData: AppData) {
        data = newData
        persist()
    }

    func persist() {
        do {
            let bytes = try JSONEncoder.shiftEncoder.encode(data)
            try bytes.write(to: saveURL, options: .atomic)
        } catch {
            print("Could not save shift data: \(error)")
        }
    }

    private func applyRule(to date: Date) {
        guard data.entries.isEmpty, let rule = selectedRule else { return }
        // Rules calculate dates dynamically; do not create thousands of stored rows.
        _ = date
        _ = rule
    }

    func monthStats(for month: Date) -> (work: Int, rest: Int, night: Int, leave: Int) {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return (0,0,0,0) }
        var work = 0, rest = 0, night = 0, leave = 0
        var day = interval.start
        while day < interval.end {
            switch kind(for: day) {
            case .rest: rest += 1
            case .night: work += 1; night += 1
            case .leave: leave += 1
            default: work += 1
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return (work, rest, night, leave)
    }
}

extension JSONEncoder {
    static var shiftEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
extension JSONDecoder {
    static var shiftDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
