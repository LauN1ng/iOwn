import Foundation

// MARK: - 洞察数据引擎（D2，视觉基准 v1.5 §12）
// 全部 static 纯函数，入参 [Tx] / 显式 now+calendar，无存储副作用，与 BalanceEngine 同思路。
// 口径：只统计支出（type == .out）；transfer / in 不计。

enum InsightStats {

    // MARK: - 通用过滤

    /// 支出笔（洞察各口径共用）
    /// 排除还款流水（source == .repayment）：它是负债的偿还动作，不是消费。
    /// 否则「花呗买东西记一笔 + 到期还款再记一笔」会把同一笔消费统计两次。
    static func expenseTxs(_ txs: [Tx]) -> [Tx] {
        txs.filter { $0.type == .out && $0.source != .repayment }
    }

    /// 某天（startOfDay）的支出合计
    private static func sum(_ txs: [Tx]) -> Decimal {
        txs.reduce(Decimal(0)) { $0 + $1.amount }
    }

    // MARK: - 当月概览

    /// 当月（now 所在自然月）支出合计
    static func monthTotal(_ txs: [Tx], now: Date = .now, calendar: Calendar = .current) -> Decimal {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return 0 }
        return sum(expenseTxs(txs).filter { interval.contains($0.date) })
    }

    /// 当月笔数
    static func monthCount(_ txs: [Tx], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return 0 }
        return expenseTxs(txs).filter { interval.contains($0.date) }.count
    }

    /// 月均支出：有记账的**已结束月份**的支出均值；无历史返回 nil（UI 不显示）
    static func monthlyAverage(_ txs: [Tx], now: Date = .now, calendar: Calendar = .current) -> Decimal? {
        let expenses = expenseTxs(txs)
        guard !expenses.isEmpty,
              let thisMonth = calendar.dateInterval(of: .month, for: now) else { return nil }
        var buckets: [Date: Decimal] = [:]
        for tx in expenses where tx.date < thisMonth.start {
            let key = calendar.dateInterval(of: .month, for: tx.date)?.start ?? tx.date
            buckets[key, default: 0] += tx.amount
        }
        guard !buckets.isEmpty else { return nil }
        let total = buckets.values.reduce(Decimal(0), +)
        return total / Decimal(buckets.count)
    }

    // MARK: - 12 月柱状图 / 今年总支出

    /// 当前年 1–12 月支出序列（长度为 12；无数据月为 0）
    static func monthlySeries(_ txs: [Tx], now: Date = .now, calendar: Calendar = .current) -> [Decimal] {
        let expenses = expenseTxs(txs)
        let year = calendar.component(.year, from: now)
        var series = [Decimal](repeating: 0, count: 12)
        for tx in expenses {
            let comps = calendar.dateComponents([.year, .month], from: tx.date)
            guard comps.year == year, let m = comps.month, (1...12).contains(m) else { continue }
            series[m - 1] += tx.amount
        }
        return series
    }

    /// 当年 1 月至今支出合计
    static func yearTotal(_ txs: [Tx], now: Date = .now, calendar: Calendar = .current) -> Decimal {
        let year = calendar.component(.year, from: now)
        return sum(expenseTxs(txs).filter { calendar.component(.year, from: $0.date) == year })
    }

    // MARK: - 支出日历热力格

    /// 当月每日支出合计（key = startOfDay）
    static func dailyTotals(_ txs: [Tx], now: Date = .now, calendar: Calendar = .current) -> [Date: Decimal] {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return [:] }
        var map: [Date: Decimal] = [:]
        for tx in expenseTxs(txs) where interval.contains(tx.date) {
            let day = calendar.startOfDay(for: tx.date)
            map[day, default: 0] += tx.amount
        }
        return map
    }

    /// 当月内从今日（或当月最后一天）向前连续有记账的天数
    static func monthStreak(_ txs: [Tx], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return 0 }
        let days = Set(expenseTxs(txs).filter { interval.contains($0.date) }
            .map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        // 起点：当月今天是当月内则由今天起算，否则由当月最后一天起算
        var day = calendar.startOfDay(for: min(now, interval.end.addingTimeInterval(-1)))
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day), prev >= interval.start else { break }
            day = prev
        }
        return streak
    }

    /// 热力档位（0 无 / 1 低 / 2 中 / 3 高）；相对当月最大单日额分档
    static func heatLevel(_ amount: Decimal, maxAmount: Decimal) -> Int {
        guard amount > 0, maxAmount > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: amount / maxAmount).doubleValue
        if ratio >= 0.66 { return 3 }
        if ratio >= 0.33 { return 2 }
        return 1
    }

    // MARK: - 心情账单

    /// 心情计数（按 Mood.allCases 顺序，仅含 >0）
    static func moodCounts(_ txs: [Tx]) -> [(mood: Mood, count: Int)] {
        let expenses = expenseTxs(txs)
        return Mood.allCases.compactMap { mood in
            let n = expenses.filter { $0.mood == mood }.count
            return n > 0 ? (mood, n) : nil
        }
    }

    // MARK: - 分类占比

    struct CategoryShare: Identifiable {
        let id: String          // 大类 id
        let emoji: String
        let name: String
        let amount: Decimal
        let ratio: Double       // 0...1
    }

    /// 当月按大类支出占比（降序，仅含 >0）
    static func categoryShares(_ txs: [Tx], now: Date = .now, calendar: Calendar = .current) -> [CategoryShare] {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return [] }
        var buckets: [String: Decimal] = [:]
        for tx in expenseTxs(txs) where interval.contains(tx.date) {
            buckets[tx.categoryID, default: 0] += tx.amount
        }
        let total = buckets.values.reduce(Decimal(0), +)
        guard total > 0 else { return [] }
        return buckets.map { id, amount in
            let def = CategoryPresets.category(id: id)
            return CategoryShare(
                id: id,
                emoji: def?.emoji ?? "❔",
                name: def?.name ?? "其他",
                amount: amount,
                ratio: NSDecimalNumber(decimal: amount / total).doubleValue
            )
        }
        .sorted { $0.amount > $1.amount }
    }
}
