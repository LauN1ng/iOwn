import SwiftUI

/// 设置页骨架 —— M3（E1-E5）：外观 / 导出 CSV / 工资计时器参数 / 自动记账引导 / 分类管理
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("开发中") {
                    LabeledContent("版本", value: "M1 骨架 0.1.0")
                    // TODO(M3-E5): 分类管理
                    // TODO(M1-E3): 工资计时器参数（月薪/发薪日/工作时段）
                    // TODO(M3-E4): 自动记账引导（iOS 27 通知自动化）
                    // TODO(M1-E2): 导出 CSV
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
