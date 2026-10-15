import SwiftUI

/// 设置页 —— 工资计时器参数 / 分类管理 / 固定支出 / 关于
///
/// 2026-10-15（D2 页面容器语言）：系统 `List` → **全自绘**（`ScrollView` + `VStack` + 白卡），
/// 与其余 7 个业务页共用同一套容器语言与 token（`Theme.card` / `Radius.large` / `Theme.hairline`）。
/// 代价（已知取舍）：失去系统 List 的分组吸顶、系统行高与自动缩进 —— 全部由 `CardSection` 承担。
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    group("记账") {
                        CardSection {
                            navRow("工资计时器", "nav_timer") { WageSettingsView() }
                            CardDivider()
                            navRow("分类管理", "cur_label") { CategoryManagerView() }
                        }
                        // TODO(M1-E2): 导出 CSV
                    }

                    group("资产") {
                        CardSection {
                            navRow("固定支出 / 订阅", "cur_tear_off_calendar") { FixedExpenseView() }
                        }
                        // 负债已并入「资产 → 信用账户」，不再单列入口（2026-10-10 v4）
                    }

                    group("关于") {
                        CardSection {
                            CardRow("版本") {
                                Text("自用版 0.4.0")
                                    .scaledFont(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        CardFooterNote(text: "图标使用 Microsoft Fluent Emoji 素材。\nCopyright (c) Microsoft Corporation. Licensed under the MIT License.")
                    }

                    CardFooterNote(text: "数据只存在这台手机上。导出即备份。")
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 6)
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .navigationTitle("设置")
        }
    }

    // MARK: 构件

    /// 分组 = 标题 + 卡片（替代 `List` 的 `Section`）
    private func group<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            CardSectionTitle(text: title)
            content()
        }
    }

    /// 设置行：Fluent 图标 + 标题 + 右侧 ›（整行可点，push 到下个页面）
    private func navRow<Destination: View>(_ title: String, _ asset: String,
                                           @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 10) {
                Image(asset)
                    .renderingMode(.original)
                    .resizable().scaledToFit()
                    .frame(width: 22, height: 22)
                Text(title)
                    .scaledFont(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .scaledFont(.sm, weight: .semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview { SettingsView() }
