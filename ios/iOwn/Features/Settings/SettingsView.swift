import SwiftUI

/// 设置页骨架 —— 外观 / 导出 CSV / 工资计时器参数 / 分类管理
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
                    NavigationLink {
                        CategoryManagerView()
                    } label: {
                        Label("分类管理", systemImage: "square.grid.2x2")
                    }
                    // TODO(M1-E2): 导出 CSV
                }
                Section("资产") {
                    NavigationLink {
                        FixedExpenseView()
                    } label: {
                        Label("固定支出 / 订阅", systemImage: "calendar")
                    }
                    // 负债已并入「资产 → 信用账户」，不再单列入口（2026-10-10 v4）
                }
                Section("开发中") {
                    LabeledContent("版本", value: "自用版 0.4.0")
                }
                Section {
                    Text("数据只存在这台手机上。导出即备份。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)      // v1.4：去掉系统列表底色，与其它页的卡片语言对齐
            .listRowBackground(Theme.card)         // 行底改用全 App 统一的白色卡片
            .listRowSeparatorTint(Theme.hairline)  // 分隔线用 hairline token，不用系统默认
            .background(Theme.bg)
            .navigationTitle("设置")
        }
    }
}

#Preview { SettingsView() }
