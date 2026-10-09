import SwiftUI

/// 首页顶卡：工资计时器（D1）——本月已赚每秒自走 + 时薪副注 + doodle
/// 实现：TimelineView(.periodic(by: 1)) 驱动重算（金额自走不能用 Text(timerInterval:)）
struct WageTimerCard: View {
    @State private var showSettings = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let config = WageConfig.load()
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
        .contentShape(Rectangle())
        .onTapGesture { showSettings = true }
        .sheet(isPresented: $showSettings) { WageSettingsView() }
    }

    @ViewBuilder
    private func content(config: WageConfig, now: Date) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("工资计时器 · 本月已赚")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    if config.isConfigured && config.isWorkingNow(now: now) {
                        Circle().fill(Theme.green).frame(width: 6, height: 6)   // 工作中：绿点呼吸
                    }
                }

                if config.isConfigured {
                    Text("¥" + Money.string(config.earnedThisMonth(now: now)))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.green)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("时薪 ¥\(Money.compact(config.hourlyWage(now: now))) · 本月已走 \(config.daysTouchedThisMonth(now: now)) 个工作日")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("¥ ——")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.green.opacity(0.45))
                        .monospacedDigit()
                    Text("点这里设置月薪与工作时段 ›")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Theme.green)
                }
            }
            Spacer(minLength: 0)
            WageDoodle()
                .frame(width: 78, height: 62)
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
