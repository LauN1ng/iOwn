import SwiftUI

/// 首页顶卡：工资计时器（D1）——本月已赚每秒自走 + 时薪副注 + doodle
/// 实现：TimelineView(.periodic(by: 1)) 驱动重算（金额自走不能用 Text(timerInterval:)）
/// v1.3：参数只在「进入/关闭设置」时读一次，不再每秒读 UserDefaults；整卡按下缩放反馈
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
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.green)
                    .frame(width: 4)
                    .cornerRadius(2)
                    .padding(.vertical, 14)
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("打开工资计时器设置")
        .sheet(isPresented: $showSettings, onDismiss: { config = .load() }) { WageSettingsView() }
    }

    /// VoiceOver 摘要（不跟随每秒自走，避免朗读数字追着跳）
    private var accessibilityLabel: String {
        guard config.isConfigured else { return "工资计时器，尚未设置" }
        return "工资计时器，本月已赚 \(Money.string(config.earnedThisMonth())) 元"
    }

    @ViewBuilder
    private func content(config: WageConfig, now: Date) -> some View {
        let earned = config.earnedThisMonth(now: now)
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("工资计时器 · 本月已赚")
                        .scaledFont(12)
                        .foregroundStyle(.secondary)
                    if config.isConfigured && config.isWorkingNow(now: now) {
                        Circle().fill(Theme.green).frame(width: 6, height: 6)   // 工作中：绿点
                    }
                }

                if config.isConfigured {
                    Text("¥" + Money.string(earned))
                        .scaledFont(30, weight: .heavy, design: .rounded)
                        .foregroundStyle(Theme.greenText)
                        .monospacedDigit()
                        .tracking(-0.4)
                        .contentTransition(.numericText(value: earned))
                        .animation(.easeOut(duration: 0.35), value: earned)   // 数字滚动而非硬跳
                    Text("时薪 ¥\(Money.compact(config.hourlyWage(now: now))) · 本月已走 \(config.daysTouchedThisMonth(now: now)) 个工作日")
                        .scaledFont(11.5)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("¥ ——")
                        .scaledFont(30, weight: .heavy, design: .rounded)
                        .foregroundStyle(Theme.greenText.opacity(0.45))
                        .monospacedDigit()
                    Text("点这里设置月薪与工作时段 ›")
                        .scaledFont(11.5, weight: .semibold)
                        .foregroundStyle(Theme.greenText)
                }
            }
            Spacer(minLength: 0)
            WageDoodle()
                .frame(width: 78, height: 62)
                .accessibilityHidden(true)   // 纯装饰插画
        }
        .padding(16)
    }
}

/// 手绘线条 doodle（黑线 + 一笔绿）：时钟 + 加号圆
struct WageDoodle: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 表盘
                Circle()
                    .stroke(Color.primary, lineWidth: 2.2)
                    .frame(width: w * 0.56, height: w * 0.56)
                    .position(x: w * 0.44, y: h * 0.62)
                // 指针（绿）
                Path { p in
                    p.move(to: CGPoint(x: w * 0.44, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.40))
                    p.move(to: CGPoint(x: w * 0.44, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.70))
                }
                .stroke(Theme.green, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                // 加号圆
                Circle()
                    .stroke(Color.primary, lineWidth: 2.2)
                    .frame(width: w * 0.24, height: w * 0.24)
                    .position(x: w * 0.80, y: h * 0.40)
                    .opacity(0.85)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.80, y: h * 0.34))
                    p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.46))
                    p.move(to: CGPoint(x: w * 0.74, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.40))
                }
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .opacity(0.6)
            }
        }
    }
}
