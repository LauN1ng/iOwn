import SwiftUI

/// 首页顶卡：工资计时器（D1，v1.6 重构）
///
/// v1.6 变更（2026-10-10）：
/// - 口径：月薪 → **到手薪资**（不再计算五险一金/个税，用户直接填到手值）
/// - 删除左侧装饰绿条；删除手绘时钟 doodle
/// - 右侧状态区改为 **方案 2：状态胶囊 + 倒计时**（为小组件铺路，共享同一状态机）
/// - 调休：`WageConfig.todayStatus` 判定，优先级 手动标记 > holiday-cn > 默认周规则
///
/// 小组件适配说明：状态胶囊（5 分钟粒度）与倒计时可 1:1 还原到 WidgetKit；
/// 其中倒计时未来在小组件内可用 `Text(style:.timer)` 实现真·秒级跳动。
struct WageTimerCard: View {
    @State private var showSettings = false
    @State private var config: WageConfig = .load()

    var body: some View {
        Button {
            Haptics.tap()
            showSettings = true
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(config: config, now: context.date)
            }
            .background(Theme.card)
            .cornerRadius(Radius.large)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("打开工资计时器设置")
        .sheet(isPresented: $showSettings, onDismiss: { config = .load() }) {
            // 2026-10-15（D2）：与 RootTabView 的入口保持一致（两处入口必须同款）
            WageSettingsView(showsGrabber: true)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    /// VoiceOver 摘要（不跟随每秒自走，避免朗读数字追着跳）
    private var accessibilityLabel: String {
        guard config.isConfigured else { return "工资计时器，尚未设置" }
        let state = config.todayStatus()
        let base = "工资计时器，本月已赚 \(Money.string(config.earnedThisMonth())) 元，\(state.label)"
        return base
    }

    @ViewBuilder
    private func content(config: WageConfig, now: Date) -> some View {
        let earned = config.earnedThisMonth(now: now)
        let state = config.todayStatus(now: now)
        VStack(alignment: .leading, spacing: 6) {
            Text("到手薪资 · 本月已赚")
                .scaledFont(.sm)
                .foregroundStyle(.secondary)

            if config.isConfigured {
                HStack(alignment: .center, spacing: 12) {
                    // ⭐ 2026-10-15「情绪脸」：40pt → **56pt** 裸放（不带容器底），当「卡片的脸」。
                    //
                    //   尺寸依据：右侧文字块实测高度 ≈ 金额行(.xl) + 6 + 副行(.xs) ≈ 55pt，
                    //   56pt 的脸与它**齐平** —— 脸和钱「平起平坐」，是这张卡里 emoji 能拿到的
                    //   最高舞台（首屏最大的一张卡）。宽度实测：脸 56 + 间距 12 后，金额区仍余
                    //   ≈168pt，两行文案（135 / 170pt）放得下，不需要截断。
                    //
                    //   语义依据：素材从 `state_*`（物品：公文包）换成 `face_*`（脸：融化）——
                    //   见 `Data/WageFace.swift`。**换语义才是主修复，放大只是配套**。
                    CategoryIcon(asset: state.iconAsset, size: 56)
                        .accessibilityHidden(true)   // 装饰：状态语义由整卡 accessibilityLabel + 右侧胶囊承载

                    VStack(alignment: .leading, spacing: 6) {
                        Text("¥" + Money.string(earned))
                            .scaledFont(.xl, weight: .heavy, design: .rounded)
                            .foregroundStyle(Theme.greenText)
                            .monospacedDigit()
                            .tracking(-0.4)
                            .contentTransition(.numericText(value: earned))
                            .animation(.easeOut(duration: 0.35), value: earned)   // 数字滚动而非硬跳
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        // 2026-10-15：emoji 40 → 56pt 后又多占了 16pt 宽度；大字号（.xxxLarge）
                        // 下副行最长 → 把缩字下限从 0.8 放到 0.7，避免直接截断成省略号。
                        Text("时薪 ¥\(Money.compact(config.hourlyWage(now: now))) · 本月已走 \(config.daysTouchedThisMonth(now: now)) 个工作日")
                            .scaledFont(.xs)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 4)
                    // 状态胶囊 + 倒计时（2026-10-12 已去色，见 StatusPill）
                    StatusPill(state: state, now: now, config: config)
                }
            } else {
                Text("¥ ——")
                    .scaledFont(.xl, weight: .heavy, design: .rounded)
                    .foregroundStyle(Theme.greenText.opacity(0.45))
                    .monospacedDigit()
                Text("点这里设置到手薪资与工作时段 ›")
                    .scaledFont(.xs, weight: .semibold)
                    .foregroundStyle(Theme.greenText)
            }
        }
        // bug 修复：未设置分支里没有 Spacer / 未撑满宽度 → 卡片缩到内容宽，
        // 又被外层 ScrollView 的 VStack 默认居中对齐，于是"卡片居中显示"。
        // 这里强制撑满整宽 + 左对齐，两种状态宽度一致。
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

// MARK: - 状态胶囊（2026-10-12 方案 B：去色）

/// 状态胶囊 + 倒计时。
///
/// **2026-10-12 变更（emoji 升权「方案 B」）**：
/// - 色彩职责回归 —— 原实现用 `Theme.green / .amber / .blue` **填充**表状态，
///   违反「绿 = 交互/功能色、彩色 = 内容」铁律；现改为中性 `Theme.iconBg`，
///   **状态表意交给左侧的情绪脸**（`WorkState.iconAsset`；2026-10-15 起 56pt），绿色还给交互。
/// - 去掉 `● ` 前缀（与左侧 emoji 重复）。
/// - 与未来小组件共用同一 `WorkState` 判定（`WageConfig.todayStatus`）不变。
private struct StatusPill: View {
    let state: WorkState
    let now: Date
    let config: WageConfig

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // 状态胶囊（中性底，不再用品牌色填充）
            Text(state.label)
                .scaledFont(.xs, weight: .semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Theme.iconBg)
                .cornerRadius(999)

            // 倒计时副行（仅在有意义的状态显示）
            if let (prefix, target) = countdown(now: now) {
                HStack(spacing: 3) {
                    Text(prefix)
                        .scaledFont(.micro)
                        .foregroundStyle(.tertiary)
                    Text(target, style: .timer)      // 系统实时绘制，秒级跳动（App 内 + 未来小组件通用）
                        .scaledFont(.micro, weight: .semibold)
                        .foregroundStyle(Theme.greenText)
                        .monospacedDigit()
                }
            }
        }
        .fixedSize()                 // 不被金额行压缩换行
        .accessibilityHidden(true)   // 状态已由整卡 accessibilityLabel 承载
    }

    /// 倒计时目标：返回 (前缀, 目标时间)；nil = 该状态不显示倒计时
    private func countdown(now: Date) -> (String, Date)? {
        let cal = Calendar.current
        let day = cal.startOfDay(for: now)
        func at(_ h: Int, _ m: Int) -> Date {
            cal.date(byAdding: .minute, value: h * 60 + m, to: day) ?? now
        }
        switch state {
        case .beforeWork, .makeupBefore:
            return ("距上班", at(config.startHour, config.startMinute))
        case .working, .makeupWorking:
            return ("距下班", at(config.endHour, config.endMinute))
        case .lunch:
            let lunchStart = at(config.lunchStartHour, config.lunchStartMinute)
            return ("午休剩", lunchStart.addingTimeInterval(Double(config.lunchMinutes) * 60))
        case .afterWork, .makeupAfter, .rest:
            return nil
        }
    }
}
