import SwiftUI
import SwiftData

/// 线索（首页）—— A2：按日分组流水（日期+日合计 / emoji+意图分类+名称+心情胶囊+金额）
/// 顶卡 = 工资计时器趣味卡（D1，M1 末接入）；视觉对照：site/prototype.html #home
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]

    private let ciArgs = ProcessInfo.processInfo.arguments

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    // TODO(M1-D1): 工资计时器卡（绿左边框 + Text(timerInterval:) 自走金额 + doodle）
                    WageTimerPlaceholder

                    if txs.isEmpty {
                        EmptyStateCard()
                    } else {
                        ForEach(dayGroups, id: \.day) { group in
                            dayCard(group)
                        }
                    }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .background(Theme.bg)
            .navigationTitle("线索")
            .onAppear { seedDemoDataIfRequested() }
        }
    }

    // MARK: 按日分组

    private struct DayGroup {
        let day: Date          // 当日 0 点
        let items: [Tx]
        var net: Decimal       // Σ收入 - Σ支出（金额一律绿）
    }

    private var dayGroups: [DayGroup] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: txs) { calendar.startOfDay(for: $0.date) }
        return dict
            .map { day, items in
                let net = items.reduce(Decimal(0)) { acc, tx in
                    switch tx.type {
                    case .out: acc - tx.amount
                    case .in: acc + tx.amount
                    case .transfer: acc
                    }
                }
                return DayGroup(day: day, items: items.sorted { $0.date > $1.date }, net: net)
            }
            .sorted { $0.day > $1.day }
    }

    private func dayCard(_ group: DayGroup) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                dayText(group.day)
                Spacer()
                Text("¥ \(Self.money(group.net))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.green)
                    .monospacedDigit()
            }

            ForEach(group.items, id: \.persistentModelID) { tx in
                txRow(tx)
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    /// HeyCost 式日期：英文月份小字 + 大号日数字（视觉基准 §3）
    private func dayText(_ day: Date) -> some View {
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "MMM"
        let comps = calendar.dateComponents([.month, .day], from: day)
        let dayStr = String(format: "%02d", comps.day ?? 0)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(monthFormatter.string(from: day) + ".")
                .font(.system(size: 15, weight: .bold))
            Text(dayStr)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.primary)
    }

    private func txRow(_ tx: Tx) -> some View {
        let cat = CategoryPresets.category(id: tx.categoryID)
        let sub = cat?.subs.first { $0.id == tx.subID }
        let title = tx.note.isEmpty ? (sub?.name ?? cat?.name ?? "记录") : tx.note
        let sign = tx.type == .out ? "" : "+"
        return HStack(spacing: 12) {
            Text(sub?.emoji ?? cat?.emoji ?? "🏷️")
                .font(.system(size: 20))
                .frame(width: 42, height: 42)
                .background(Theme.iconBg)
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 3) {
                Text(cat?.name ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let mood = tx.mood {
                Text("\(mood.label) \(mood.emoji)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Theme.bg)
                    .cornerRadius(999)
            }

            Text("\(sign)¥ \(Self.money(tx.amount))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.green)
                .monospacedDigit()
        }
    }

    /// 工资计时器卡（D1 占位，M1 末接入 Text(timerInterval:) 自走金额）
    private var WageTimerPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("工资计时器 · 本月已赚")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("¥ ——")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.green)
                .monospacedDigit()
            Text("M1 末接入：时薪 × 工作时长，每秒自走")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
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

    // MARK: 工具

    static func money(_ value: Decimal) -> String {
        let v = NSDecimalNumber(decimal: value).doubleValue
        return String(format: "%.2f", v)
    }

    /// CI 截图钩子：launch argument "-ci-demo-data" 注入样例数据（仓库无真实数据）
    private func seedDemoDataIfRequested() {
        guard ciArgs.contains("-ci-demo-data"), txs.isEmpty else { return }
        let calendar = Calendar.current
        let samples: [(String, String, Int, Mood?, TimeInterval)] = [
            ("needs", "meal", 1200, .normal, -2 * 3600),
            ("flexible", "coffee", 990, .satisfied, -1 * 3600),
            ("fixed", "commute", 400, nil, -26 * 3600),
        ]
        for (catID, subID, cents, mood, offset) in samples {
            modelContext.insert(Tx(
                amount: Decimal(cents) / 100,
                type: .out,
                categoryID: catID,
                subID: subID,
                note: "",
                mood: mood,
                date: calendar.date(byAdding: .second, value: Int(offset), to: .now) ?? .now
            ))
        }
        try? modelContext.save()
    }
}

#Preview { HomeView() }
