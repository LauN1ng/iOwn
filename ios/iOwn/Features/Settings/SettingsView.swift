import SwiftUI

/// 设置页骨架 —— M3（E1-E5）：外观 / 导出 CSV / 工资计时器参数 / 自动记账引导 / 分类管理
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("记账") {
                    NavigationLink {
                        WageSettingsView()
                    } label: {
                        Label("工资计时器", systemImage: "timer")
                    }
                    // TODO(M3-E5): 分类管理
                    // TODO(M3-E4): 自动记账引导（iOS 27 通知自动化）
                    // TODO(M1-E2): 导出 CSV
                }
                Section("开发中") {
                    LabeledContent("版本", value: "M1 骨架 0.2.0")
                }
                Section {
                    Text("数据只存在这台手机上。导出即备份。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.visible)
            .background(Theme.bg)
            .navigationTitle("设置")
        }
    }
}

#Preview { SettingsView() }
