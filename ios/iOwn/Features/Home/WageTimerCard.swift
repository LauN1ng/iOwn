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
        .sheet(isPresented: $showSettings, onDismiss: { config = .load() }) { WageSettingsView() }
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
                .scaledFont(12)
                .foregroundStyle(.secondary)

            if config.isConfigured {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("¥" + Money.string(earned))
                                .scaledFont(30, weight: .heavy, design: .rounded)
                                .foregroundStyle(Theme.greenText)
                                .monospacedDigit()
                                .tracking(-0.4)
                                .contentTransition(.numericText(value: earned))
                                .animation(.easeOut(duration: 0.35), value: earned)   // 数字滚动而非硬跳
                            if !state.isWorkingDay {
                                Text("今天休息")
                                    .scaledFont(11, weight: .semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(Theme.iconBg)
                                    .cornerRadius(999)
                            }
                        }
                        Text("时薪 ¥\(Money.compact(config.hourlyWage(now: now))) · 本月已走 \(config.daysTouchedThisMonth(now: now)) 个工作日")
                            .scaledFont(11.5)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    // 状态区置于金额行右侧（原 doodle 位置），不额外撑高卡片
                    StatusPill(state: state, now: now, config: config)
                }
            } else {
                Text("¥ ——")
                    .scaledFont(30, weight: .heavy, design: .rounded)
                    .foregroundStyle(Theme.greenText.opacity(0.45))
                    .monospacedDigit()
                Text("点这里设置到手薪资与工作时段 ›")
                    .scaledFont(11.5, weight: .semibold)
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

// MARK: - 状态胶囊（方案 2）

/// 状态胶囊 + 倒计时：工作中（绿）/ 午休（黄）/ 未上班·已下班·休息（灰）/ 调休（蓝）
/// 与未来小组件共用同一 `WorkState` 判定（`WageConfig.todayStatus`）
private struct StatusPill: View {
    let state: WorkState
    let now: Date
    let config: WageConfig

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // 状态胶囊
            Text("● " + state.label)
                .scaledFont(11, weight: .semibold)
                .foregroundStyle(pillTextColor)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(pillBg)
                .cornerRadius(999)

            // 倒计时副行（仅在有意义的状态显示）
            if let (prefix, target) = countdown(now: now) {
                HStack(spacing: 3) {
                    Text(prefix)
                        .scaledFont(10.5)
                        .foregroundStyle(.tertiary)
                    Text(target, style: .timer)      // 系统实时绘制，秒级跳动（App 内 + 未来小组件通用）
                        .scaledFont(10.5, weight: .semibold)
                        .foregroundStyle(Theme.greenText)
                        .monospacedDigit()
                }
            }
        }
        .fixedSize()                 // 不被金额行压缩换行
        .accessibilityHidden(true)   // 状态已由整卡 accessibilityLabel 承载
    }

    /// 状态 → 胶囊配色（绿=填充档 Theme.green，文字白；其余用文字档保证对比度）
    private var pillBg: Color {
        switch state {
        case .working, .makeupWorking: return Theme.green
        case .lunch:                   return Theme.amber
        case .makeupBefore, .makeupAfter: return Theme.blue
        default:                       return Theme.iconBg
        }
    }

    private var pillTextColor: Color {
        switch state {
        case .working, .makeupWorking: return .white
        case .lunch:                   return .white
        case .makeupBefore, .makeupAfter: return .white
        default:                       return .secondary
        }
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
