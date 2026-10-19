import SwiftUI

struct StatisticsScreen: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var month = Calendar.current.firstDayOfMonth(for: Date())

    var body: some View {
        NavigationStack {
            let stats = store.monthStats(for: month)
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Button { month = Calendar.current.date(byAdding: .month, value: -1, to: month)! } label: { Image(systemName: "chevron.left").padding() }
                        Spacer()
                        Text(month.formatted(.dateTime.year().month())).font(.title3.bold())
                        Spacer()
                        Button { month = Calendar.current.date(byAdding: .month, value: 1, to: month)! } label: { Image(systemName: "chevron.right").padding() }
                    }
                    .padding(.horizontal)
                    statCard(title: "工作天数", value: stats.work, icon: "briefcase.fill")
                    statCard(title: "休息天数", value: stats.rest, icon: "bed.double.fill")
                    statCard(title: "夜班天数", value: stats.night, icon: "moon.fill")
                    statCard(title: "请假天数", value: stats.leave, icon: "calendar.badge.exclamationmark")
                    Text("统计按当前循环规则计算，并叠加手动修改的日期。工资、加班费和夜班补贴可在后续版本加入具体计算规则。")
                        .font(.footnote).foregroundStyle(.secondary).padding()
                }
                .padding(.top)
            }
            .navigationTitle("排班统计")
        }
    }

    private func statCard(title: String, value: Int, icon: String) -> some View {
        HStack {
            Image(systemName: icon).font(.title2).frame(width: 48, height: 48).background(.blue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            Text(title).font(.headline)
            Spacer()
            Text("\(value)").font(.system(size: 28, weight: .bold, design: .rounded))
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.gray.opacity(0.15)))
        .padding(.horizontal)
    }
}
