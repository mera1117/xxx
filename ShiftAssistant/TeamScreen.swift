import SwiftUI

struct TeamScreen: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("本地团队名单仅保存在本机，不会上传服务器。此版本可管理成员资料；跨设备协作、聊天和多人实时同步需要另行搭建服务。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("成员") {
                    if store.data.teamMembers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("还没有成员").font(.headline)
                            Text("添加成员，建立本地团队名单。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowInsets(EdgeInsets())
                    }
                    ForEach(store.data.teamMembers) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name).font(.headline)
                            if !member.role.isEmpty { Text(member.role).font(.subheadline).foregroundStyle(.secondary) }
                            if !member.note.isEmpty { Text(member.note).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { store.deleteMember(store.data.teamMembers[index]) }
                    }
                }
            }
            .navigationTitle("团队管理")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showingAdd) { AddMemberSheet() }
        }
    }
}

struct AddMemberSheet: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("姓名或昵称", text: $name)
                TextField("岗位/班组", text: $role)
                TextField("备注", text: $note)
            }
            .navigationTitle("添加成员")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.addMember(name: name, role: role)
                        dismiss()
                    }
                }
            }
        }
    }
}
