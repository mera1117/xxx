import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            CalendarScreen()
                .tabItem { Label("排班", systemImage: "calendar") }
            RulesScreen()
                .tabItem { Label("倒班规则", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") }
            TeamScreen()
                .tabItem { Label("团队", systemImage: "person.3") }
            StatisticsScreen()
                .tabItem { Label("统计", systemImage: "chart.bar") }
            SettingsScreen()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(.blue)
    }
}

struct CalendarScreen: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var month = Calendar.current.firstDayOfMonth(for: Date())
    @State private var showingEditor = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month)! } label: {
                        Image(systemName: "chevron.left").padding(8)
                    }
                    Spacer()
                    Text(month.formatted(.dateTime.year().month()))
                        .font(.title3.bold())
                    Spacer()
                    Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month)! } label: {
                        Image(systemName: "chevron.right").padding(8)
                    }
                }
                .padding(.horizontal)

                HStack {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(daysForGrid(), id: \.self) { date in
                        if Calendar.current.component(.month, from: date) == Calendar.current.component(.month, from: month) {
                            let kind = store.kind(for: date)
                            Button {
                                store.selectedDate = date
                                showingEditor = true
                            } label: {
                                VStack(spacing: 5) {
                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.subheadline.weight(Calendar.current.isDateInToday(date) ? .bold : .regular))
                                    Text(store.title(for: date))
                                        .font(.system(size: 9, weight: .medium))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(kind.color.opacity(0.13))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Calendar.current.isDate(date, inSameDayAs: store.selectedDate) ? .blue : .clear, lineWidth: 2))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height: 54)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text(store.selectedDate.formatted(date: .long, time: .omitted))
                        .font(.headline)
                    HStack {
                        Circle().fill(store.kind(for: store.selectedDate).color).frame(width: 10, height: 10)
                        Text(store.title(for: store.selectedDate)).font(.title3.bold())
                        Spacer()
                        Button("编辑班次") { showingEditor = true }
                            .buttonStyle(.borderedProminent)
                    }
                    if let entry = store.entry(for: store.selectedDate), !entry.note.isEmpty {
                        Text(entry.note).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let rule = store.selectedRule {
                        Text("当前规则：\(rule.name) · \(rule.cycle.count) 天循环")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .navigationTitle("倒班助手")
            .sheet(isPresented: $showingEditor) {
                ShiftEditorSheet(date: store.selectedDate)
            }
        }
    }

    private func daysForGrid() -> [Date] {
        let cal = Calendar.current
        let first = cal.firstDayOfMonth(for: month)
        let weekday = cal.component(.weekday, from: first)
        let start = cal.date(byAdding: .day, value: -(weekday - 1), to: first)!
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
}

struct ShiftEditorSheet: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    let date: Date
    @State private var kind: ShiftKind = .day
    @State private var title = ""
    @State private var start = "09:00"
    @State private var end = "17:00"
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("日期") { Text(date.formatted(date: .complete, time: .omitted)) }
                Section("班次") {
                    Picker("类型", selection: $kind) {
                        ForEach(ShiftKind.allCases) { item in Text(item.rawValue).tag(item) }
                    }
                    TextField("显示名称", text: $title)
                    HStack {
                        TextField("开始时间", text: $start).textInputAutocapitalization(.never)
                        TextField("结束时间", text: $end).textInputAutocapitalization(.never)
                    }
                    TextField("备注", text: $note, axis: .vertical)
                }
                Section {
                    Button("恢复循环规则") {
                        store.clearOverride(for: date)
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("编辑班次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.setEntry(date: date, kind: kind, title: title.isEmpty ? kind.rawValue : title, start: start, end: end, note: note)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let item = store.entry(for: date) {
                    kind = item.kind; title = item.title; start = item.startTime; end = item.endTime; note = item.note
                } else {
                    kind = store.kind(for: date); title = store.kind(for: date).rawValue
                }
            }
        }
    }
}

extension Calendar {
    func firstDayOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}
