import SwiftUI
import UniformTypeIdentifiers

struct SettingsScreen: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var showingExporter = false
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("提醒") {
                    Toggle("上班提醒", isOn: Binding(
                        get: { store.data.reminderEnabled },
                        set: { store.updateReminder($0) }
                    ))
                    Text("提醒使用 iOS 本地通知。当前版本会为已手动设置具体开始时间的未来班次安排提醒。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("数据管理") {
                    Button { createBackup() } label: { Label("导出本地备份", systemImage: "square.and.arrow.up") }
                    Button { showingImporter = true } label: { Label("导入备份", systemImage: "square.and.arrow.down") }
                    Text("数据保存在本机，不需要注册账号。建议定期导出 JSON 备份。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("关于") {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("广告", value: "不集成广告 SDK")
                    LabeledContent("数据联网", value: "默认不联网")
                    Text("独立开发的倒班助手原型。原版的服务器、聊天、云同步等服务不属于本地版本。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .fileExporter(isPresented: $showingExporter, document: BackupDocument(url: exportURL), contentType: .json, defaultFilename: "ShiftAssistant-Backup") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                do {
                    let urls = try result.get()
                    guard let url = urls.first else { return }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    try store.importData(from: url)
                    message = "备份导入成功"
                } catch { message = "导入失败：\(error.localizedDescription)" }
            }
            .alert("提示", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("好", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    private func createBackup() {
        do {
            exportURL = try store.exportData()
            showingExporter = true
        } catch { message = "导出失败：\(error.localizedDescription)" }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var url: URL?
    init(url: URL?) { self.url = url }
    init(configuration: ReadConfiguration) throws { url = nil }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url, let data = try? Data(contentsOf: url) else {
            return FileWrapper(regularFileWithContents: Data("{}".utf8))
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
