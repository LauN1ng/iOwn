import SwiftUI
import SwiftData

/// 线索（首页）—— A2：按日分组流水（日期+日合计 / emoji+意图分类+名称+心情胶囊+金额）
/// 顶卡 = 工资计时器趣味卡（D1，M1 末接入）；视觉对照：site/prototype.html #home
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Liability.sortOrder) private var liabilities: [Liability]
    @Query(sort: \FixedExpense.sortOrder) private var fixedExpenses: [FixedExpense]

    @State private var editingTx: Tx?

    /// 本月可支配 = 到手薪资 − Σ信用账户本月应还 − Σ固定支出
    /// （2026-10-10 v4：负债并入信用账户后，口径由账户余额派生，不再是"手填的负债表"）
    private var disposable: Decimal {
        let pay = Decimal(WageConfig.load().takeHomePay)
        return DebtEngine.disposable(takeHomePay: pay, accounts: accounts,
                                     liabilities: liabilities, txs: txs,
                                     fixedExpenses: fixedExpenses)
    }
    /// 信用账户本月应还合计
    private var creditDue: Decimal {
        DebtEngine.monthlyDueAll(accounts: accounts, liabilities: liabilities, txs: txs)
    }
    /// 固定支出每月合计
    private var fixedDue: Decimal {
        fixedExpenses.reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    WageTimerCard()   // D1 工资计时器：每秒自走（点卡片进参数设置）

                    if !liabilities.isEmpty || !fixedExpenses.isEmpty {
                        disposableCard   // D1：压缩版「本月可支配」，不铺明细
                    }

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
                .padding(.bottom, 140)   // 让开右下 FAB，末条流水不被遮挡
            }
            .background(Theme.bg)
            .navigationTitle("线索")
            .sheet(item: $editingTx) { tx in
                AddEntrySheet(editing: tx) { _, _ in editingTx = nil }   // B2 改账：原地更新，不弹成功屏
                    .presentationDetents([.fraction(0.68), .large])       // 与记一笔统一半屏
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: 本月可支配（压缩版，不铺明细——保护记账流可读性）

    private var disposableCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("本月可支配").scaledFont(11.5).foregroundStyle(.secondary)
                Text("¥ \(Money.string(dec(disposable)))")
                    .scaledFont(26, weight: .heavy, design: .rounded)
                    .foregroundStyle(Theme.greenText).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("信用应还 ¥\(Money.string(dec(creditDue)))")
                    .scaledFont(11.5, weight: .semibold).monospacedDigit()
                Text("固定支出 ¥\(Money.string(dec(fixedDue)))")
                    .scaledFont(11.5).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(15)
        .background(Theme.card)
        .cornerRadius(Radius.large)
        .overlay(RoundedRectangle(cornerRadius: Radius.large)
            .stroke(Color(hex: 0xD6EDDC), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("本月可支配 ¥\(Money.string(dec(disposable)))，信用应还 ¥\(Money.string(dec(creditDue)))，固定支出 ¥\(Money.string(dec(fixedDue)))")
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }

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
                Text(Self.signedMoney(group.net))
                    .scaledFont(16, weight: .bold)
                    .foregroundStyle(Theme.greenText)
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

    /// 英文月份缩写（静态 FormatStyle，避免每行渲染都新建 DateFormatter）
    private static let monthStyle = Date.FormatStyle.dateTime
        .month(.abbreviated)
        .locale(Locale(identifier: "en_US_POSIX"))

    /// HeyCost 式日期：英文月份小字 + 大号日数字（视觉基准 §3）
    private func dayText(_ day: Date) -> some View {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.month, .day], from: day)
        let dayStr = String(format: "%02d", comps.day ?? 0)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(day.formatted(Self.monthStyle) + ".")
                .scaledFont(15, weight: .bold)
            Text(dayStr)
                .scaledFont(24, weight: .heavy, design: .rounded)
                .monospacedDigit()
        }
        .foregroundStyle(.primary)
    }

    private func txRow(_ tx: Tx) -> some View {
        let row = txRowContent(tx)
        return row
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)     // 合并读作一条流水，而非逐段
            .accessibilityHint("长按可编辑或删除")
            .contextMenu {
                if tx.type != .transfer {
                    Button { editingTx = tx } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                }
                Button(role: .destructive) {
                    // B2 删账：余额为推导值，删除即自动"回滚"
                    modelContext.delete(tx)
                    try? modelContext.save()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
    }

    @ViewBuilder
    private func txRowContent(_ tx: Tx) -> some View {
        if tx.type == .transfer {
            // 转账行：🔄 资产互转（不计收支，日合计已排除）
            let fromName = accounts.first { $0.id == tx.accountID }?.name ?? "?"
            let toName = accounts.first { $0.id == tx.toAccountID }?.name ?? "?"
            HStack(spacing: 12) {
                Text("🔄")
                    .scaledFont(20)
                    .frame(width: 42, height: 42)
                    .background(Theme.iconBg)
                    .cornerRadius(14)
                    .accessibilityHidden(true)   // 装饰：转账语义已由「资产互转」文字承载

                VStack(alignment: .leading, spacing: 3) {
                    Text("资产互转")
                        .scaledFont(11)
                        .foregroundStyle(.secondary)
                    Text("\(fromName) → \(toName)")
                        .scaledFont(15, weight: .semibold)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("¥ \(Self.money(tx.amount))")
                    .scaledFont(15, weight: .bold)
                    .foregroundStyle(Theme.greenText)
                    .monospacedDigit()
            }
        } else {
            let cat = CategoryPresets.category(id: tx.categoryID)
            let sub = cat?.subs.first { $0.id == tx.subID }
            let title = tx.note.isEmpty ? (sub?.name ?? cat?.name ?? "记录") : tx.note
            let sign = tx.type == .out ? "" : "+"
            let accountName = accounts.first { $0.id == tx.accountID }?.name
            HStack(spacing: 12) {
                Text(sub?.emoji ?? cat?.emoji ?? "🏷️")
                    .scaledFont(20)
                    .frame(width: 42, height: 42)
                    .background(Theme.iconBg)
                    .cornerRadius(14)
                    .accessibilityHidden(true)   // 装饰：分类名已在小字里念出

                VStack(alignment: .leading, spacing: 3) {
                    Text(accountName.map { "\(cat?.name ?? "") · \($0)" } ?? (cat?.name ?? ""))
                        .scaledFont(11)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .scaledFont(15, weight: .semibold)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let mood = tx.mood {
                    Text("\(mood.label) \(mood.emoji)")
                        .scaledFont(11)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.bg)
                        .cornerRadius(999)
                }

                // 还款流水标注：它不是消费，洞察统计已排除（Source.repayment）
                if tx.source == .repayment {
                    Text("还款")
                        .scaledFont(10, weight: .medium)
                        .foregroundStyle(Theme.blueText)
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .background(Color(hex: 0xEAF1FE))
                        .cornerRadius(6)
                }

                Text("\(sign)¥ \(Self.money(tx.amount))")
                    .scaledFont(15, weight: .bold)
                    .foregroundStyle(Theme.greenText)
                    .monospacedDigit()
            }
        }
    }

    // MARK: 工具

    /// 千分位/两位小数金额（统一走共享 Money.string，与工资卡/资产页同口径）
    static func money(_ value: Decimal) -> String {
        Money.string(NSDecimalNumber(decimal: value).doubleValue)
    }

    /// 日合计：符号在 ¥ 前（-¥21.90 / +¥12.00 / ¥0.00）
    static func signedMoney(_ value: Decimal) -> String {
        let v = NSDecimalNumber(decimal: value).doubleValue
        if v < 0 { return "-¥" + Money.string(-v) }
        if v > 0 { return "+¥" + Money.string(v) }
        return "¥ 0.00"
    }
}

#Preview { HomeView() }
