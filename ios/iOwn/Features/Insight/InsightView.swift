import SwiftUI
import SwiftData

/// 洞察页（D2，视觉基准 v1.5 §12）
/// 区块：月份卡（大绿金额 + 12 月柱状图）/ 支出日历热力格 + 心情账单 / 分类占比
/// 数据全部由 InsightStats 纯函数从 [Tx] 派生（口径：仅支出）
struct InsightView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]

    /// 口径切换：0 = 当月 / 1 = 全年（对应原型月份胶囊下拉）
    @State private var scope = 0

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Radius.cardSpacing) {
                        monthCard
                        HStack(alignment: .top, spacing: Radius.cardSpacing) {
                            calendarCard
                            moodCard
                        }
                        categoryCard.id("insight-bottom")
                    }
                    .padding(.horizontal, Radius.pagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 110)   // 避开悬浮 TabBar(~49) + FAB(伸出 76) 的遮挡
                }
                .onAppear {
                    // CI 截图钩子：滚到底部，验证分类占比卡不被 TabBar/FAB 遮挡
                    if ProcessInfo.processInfo.arguments.contains("-ci-insight-bottom") {
                        proxy.scrollTo("insight-bottom", anchor: .bottom)
                    }
                }
            }
            .background(Theme.bg)
            .navigationTitle("洞察")
        }
    }

    // MARK: - 区块 1：月份卡 + 12 月柱状图

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                // 月份胶囊：点按切换「当月 / 全年」口径
                Button {
                    Haptics.tap()
                    withAnimation(Motion.fade) { scope = scope == 0 ? 1 : 0 }
                } label: {
                    HStack(spacing: 5) {
                        Text(scope == 0 ? monthLabel : "全年")
                            .scaledFont(15, weight: .bold)
                            .foregroundStyle(Theme.greenText)
                        Image(systemName: "chevron.down")
                            .scaledFont(10, weight: .bold)
                            .foregroundStyle(Theme.greenText)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.greenSoft, in: Capsule())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.94))
                .accessibilityLabel(scope == 0 ? "当前口径：\(monthLabel)" : "当前口径：全年")
                .accessibilityHint("点按切换当月与全年")

                Spacer()

                if let avg = InsightStats.monthlyAverage(txs) {
                    HStack(spacing: 3) {
                        Text("月均支出").scaledFont(11).foregroundStyle(.secondary)
                        Text(money(avg)).scaledFont(11, weight: .semibold).foregroundStyle(.primary)
                    }
                }
            }

            Text(money(headlineAmount))
                .scaledFont(42, weight: .heavy, design: .rounded)
                .foregroundStyle(Theme.greenText)
                .monospacedDigit()
                .tracking(-0.5)
                .accessibilityLabel("支出金额 \(money(headlineAmount))")

            monthBars

            // 底部：今年总支出
            Divider().overlay(Theme.hairline)
            HStack {
                Text("今年总支出").scaledFont(12).foregroundStyle(.secondary)
                Spacer()
                Text(money(InsightStats.yearTotal(txs)))
                    .scaledFont(13, weight: .bold).foregroundStyle(.primary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    /// 12 月柱状图：当月（或全年口径下 12 月最大值）绿柱高亮，其余灰柱；虚线基线
    private var monthBars: some View {
        let series = InsightStats.monthlySeries(txs)
        let maxVal = series.max() ?? 0
        let currentMonth = calendar.component(.month, from: .now)   // 1...12
        return VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                // 虚线基线
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
                    .overlay(
                        Rectangle().stroke(Theme.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<12, id: \.self) { i in
                        let v = series[i]
                        let h = barHeight(v, max: maxVal)
                        let isCur = (i + 1) == currentMonth
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isCur ? Theme.green : Theme.iconBg)
                            .frame(height: max(h, 4))
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: 84, alignment: .bottom)
            }
            .frame(height: 84, alignment: .bottom)

            HStack(spacing: 5) {
                ForEach(0..<12, id: \.self) { i in
                    Text("\(i + 1)")
                        .scaledFont(9)
                        .foregroundStyle((i + 1) == currentMonth ? Theme.greenText : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("12 月支出柱状图，\(currentMonth) 月为 \(money(series[safe: currentMonth - 1] ?? 0))")
    }

    /// 柱高：按最大值归一（最大柱占满 84pt）
    private func barHeight(_ v: Decimal, max maxVal: Decimal) -> CGFloat {
        guard maxVal > 0, v > 0 else { return 0 }
        let r = NSDecimalNumber(decimal: v / maxVal).doubleValue
        return CGFloat(max(0, min(1, r))) * 84
    }

    // MARK: - 区块 2a：支出日历热力格

    private var calendarCard: some View {
        let daily = InsightStats.dailyTotals(txs)
        let maxDaily = daily.values.max() ?? 0
        let daysInMonth = calendar.range(of: .day, in: .month, for: .now)?.count ?? 30
        // 当月 1 日是周几（周一=0 起）
        let firstWeekday = mondayIndex(for: monthStart())
        let leading = firstWeekday
        let count = InsightStats.monthCount(txs)
        let streak = InsightStats.monthStreak(txs)
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(alignment: .leading, spacing: 10) {
            Text("支出日历").scaledFont(13, weight: .bold)

            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(0..<leading, id: \.self) { _ in
                    Color.clear.frame(height: 14)
                }
                ForEach(1...daysInMonth, id: \.self) { d in
                    let day = calendar.date(byAdding: .day, value: d - 1, to: monthStart()) ?? .now
                    let amt = daily[calendar.startOfDay(for: day)] ?? 0
                    let level = InsightStats.heatLevel(amt, maxAmount: maxDaily)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatColor(level))
                        .frame(height: 14)
                        .accessibilityHidden(true)
                }
            }

            Divider().overlay(Theme.hairline)
            HStack(spacing: 4) {
                Text("\(count)").scaledFont(12, weight: .bold).foregroundStyle(Theme.greenText)
                Text("笔 · 连续 \(streak) 天").scaledFont(11).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card)
        .cornerRadius(Radius.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("支出日历，本月 \(count) 笔，连续 \(streak) 天")
    }

    /// 热力档位 → 颜色（0 空 / 1 浅 / 2 中 / 3 深）
    private func heatColor(_ level: Int) -> Color {
        switch level {
        case 0: Theme.iconBg
        case 1: Theme.green.opacity(0.22)
        case 2: Theme.green.opacity(0.55)
        default: Theme.green
        }
    }

    // MARK: - 区块 2b：心情账单

    private var moodCard: some View {
        let moods = InsightStats.moodCounts(txs)
        return VStack(alignment: .leading, spacing: 10) {
            Text("心情账单").scaledFont(13, weight: .bold)

            if moods.isEmpty {
                Text("记几笔\n带心情的账")
                    .scaledFont(12).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            } else {
                ForEach(moods, id: \.mood) { item in
                    HStack(spacing: 6) {
                        CategoryIcon(item.mood, size: 22).accessibilityHidden(true)
                        Text(item.mood.label).scaledFont(12).foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("× \(item.count)")
                            .scaledFont(13, weight: .bold).foregroundStyle(Theme.greenText)
                            .monospacedDigit()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card)
        .cornerRadius(Radius.large)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 区块 3：分类占比

    private var categoryCard: some View {
        let shares = InsightStats.categoryShares(txs)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("分类占比").scaledFont(13, weight: .bold)
                Spacer()
                Text("占当月总支出").scaledFont(11).foregroundStyle(.secondary)
            }

            if shares.isEmpty {
                Text("本月还没有支出记录")
                    .scaledFont(12).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(shares) { s in
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            CategoryIcon(asset: s.iconName, fallback: s.emoji, size: 22)
                                .accessibilityHidden(true)
                            Text(s.name).scaledFont(13).foregroundStyle(.primary)
                            Spacer()
                            Text("\(Int((s.ratio * 100).rounded()))%")
                                .scaledFont(12, weight: .semibold).foregroundStyle(Theme.greenText)
                                .monospacedDigit()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.iconBg)
                                Capsule().fill(Theme.green)
                                    .frame(width: max(4, geo.size.width * s.ratio))
                            }
                        }
                        .frame(height: 7)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(s.name) 占比 \(Int((s.ratio * 100).rounded()))%，\(money(s.amount))")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    // MARK: - 辅助

    /// 顶部大金额：当月口径 = 当月支出；全年口径 = 今年总支出
    private var headlineAmount: Decimal {
        scope == 0 ? InsightStats.monthTotal(txs) : InsightStats.yearTotal(txs)
    }

    private var monthLabel: String {
        "\(calendar.component(.month, from: .now))月"
    }

    private func monthStart() -> Date {
        calendar.dateInterval(of: .month, for: .now)?.start ?? calendar.startOfDay(for: .now)
    }

    /// 周一 = 0 的星期序号（用于日历网格前置空格）
    private func mondayIndex(for date: Date) -> Int {
        let wd = calendar.component(.weekday, from: date)   // 1=周日 … 7=周六
        return (wd + 5) % 7                                  // 周一→0 … 周日→6
    }

    /// 两位小数金额串（视觉 §4.2：全 App 金额两位小数）
    private func money(_ v: Decimal) -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        return "¥ " + (f.string(from: n) ?? "0.00")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview { InsightView() }
