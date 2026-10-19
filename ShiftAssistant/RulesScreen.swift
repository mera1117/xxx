import SwiftUI

struct RulesScreen: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section("当前使用") {
                    if let selected = store.selectedRule {
                        Text(selected.name).font(.headline)
                        Text(selected.cycle.map(\.rawValue).joined(separator: " → "))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("循环起始日：\(selected.anchorDate.formatted(date: .numeric, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("尚未设置倒班规则")
                    }
                }
                Section("规则列表") {
                    ForEach(store.data.rules) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(rule.name).font(.headline)
                                Text(rule.cycle.map(\.rawValue).joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.selectedRule?.id == rule.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                            } else {
                                Button("使用") { store.selectRule(rule.id) }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.selectRule(rule.id) }
                    }
                    .onDelete { offsets in
                        for index in offsets { store.deleteRule(store.data.rules[index]) }
                    }
                }
            }
            .navigationTitle("倒班规则")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showingAdd) { AddRuleSheet() }
        }
    }
}

struct AddRuleSheet: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = "自定义循环"
    @State private var cycleText = "白班,白班,休息,休息"
    @State private var anchor = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("规则名称") { TextField("例如：上二休二", text: $name) }
                Section("循环班次") {
                    TextField("用逗号分隔，例如：白班,夜班,休息", text: $cycleText, axis: .vertical)
                    Text("可用班次：白班、中班、夜班、休息、请假、自定义")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("循环起始日") { DatePicker("起始日", selection: $anchor, displayedComponents: .date) }
            }
            .navigationTitle("新增规则")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let kinds = cycleText.split(separator: ",").compactMap { token -> ShiftKind? in
                            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                            return ShiftKind.allCases.first { $0.rawValue == trimmed }
                        }
                        guard !kinds.isEmpty else { return }
                        let rule = CycleRule(name: name.isEmpty ? "自定义循环" : name, cycle: kinds, anchorDate: Calendar.current.startOfDay(for: anchor))
                        store.addRule(rule)
                        store.selectRule(rule.id)
                        dismiss()
                    }
                }
            }
        }
    }
}
