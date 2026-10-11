import SwiftUI
import SwiftData

/// 分期总览 —— 2026-10-11（资产页去卡片化三尾巴之一 · 同时兑现「债有尽头」）
///
/// 两个缺口在这里一起补上：
/// ① 资产页此前**没有「分期总览」入口** —— 所有分期藏在各信用账户详情里，看不到全貌；
/// ② `DebtEngine.forecast` 早已写好却**从未被调用**（orphan）——「债有尽头」缺的就是这个界面。
///
/// 功能性优先：先让数字可信、口径正确，美术与动效留到功能稳定之后再打磨。
struct InstallmentOverviewView: View {
    @Query(sort: \Liability.sortOrder) private var liabilities: [Liability]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @AppStorage(WageKeys.takeHomePay) private var takeHomePay: Double = 0

    /// 只看**还没还完**的分期
    private var activePlans: [Liability] {
        liabilities.filter { $0.kind == .installment && DebtEngine.remainingPeriods($0) > 0 }
    }
    private var remainingTotal: Decimal {
        activePlans.reduce(Decimal(0)) { $0 + DebtEngine.remaining($1) }
    }
    private var monthsLeft: Int { DebtEngine.payoffMonths(activePlans) }

    var body: some View {
        ScrollView {
            VStack(spacing: Radius.cardSpacing) {
                if activePlans.isEmpty {
                    EmptyStateCard(icon: "🎉", title: "没有未还完的分期",
                                   hint: "债已经到头了")
                } else {
                    payoffCard
                    forecastSection
                    plansSection
                }
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 110)   // 避开悬浮 TabBar
        }
        .background(Theme.bg)
        .navigationTitle("分期总览")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 全部还清（「债有尽头」的门面）

    private var payoffCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered").scaledFont(12)
                Text("全部还清").scaledFont(12, weight: .semibold)
            }
            .foregroundStyle(Theme.greenText)

            Text(payoffDateText)
                .scaledFont(28, weight: .heavy, design: .rounded)
                .foregroundStyle(.primary)

            Text("还剩 \(monthsLeft) 期 · 一共还欠 ¥" + money(remainingTotal))
                .scaledFont(11.5).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.greenSoft)
        .cornerRadius(Radius.large)
    }

    // MARK: 未来 12 个月（`DebtEngine.forecast` 的落点）

    private var forecastSection: some View {
        let rows = DebtEngine.forecast(takeHomePay: Decimal(takeHomePay),
                                       liabilities: activePlans, months: 12)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("未来 12 个月").scaledFont(13, weight: .semibold)
                Spacer()
                Text("每月应还 · 剩余债务").scaledFont(11.5).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // ⚠️ 用 indices：元组元素不能做 KeyPath
                ForEach(rows.indices, id: \.self) { i in
                    forecastRow(offset: rows[i].0, due: rows[i].2, divider: i > 0)
                }
            }
            .padding(.vertical, 4)
            .background(Theme.card)
            .cornerRadius(Radius.large)
        }
    }

    private func forecastRow(offset: Int, due: Decimal, divider: Bool) -> some View {
        let date = Calendar.current.date(byAdding: .month, value: offset, to: .now) ?? .now
        let left = DebtEngine.remainingAfter(activePlans, months: offset)
        return HStack(spacing: 10) {
            Text(Self.monthFormatter.string(from: date))
                .scaledFont(12.5).foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(due > 0 ? "¥ " + money(due) : "已还完")
                .scaledFont(13.5, weight: .semibold).monospacedDigit()
                .foregroundStyle(due > 0 ? Color.primary : Theme.greenText)
            Spacer(minLength: 8)
            Text("余 ¥" + money(left))
                .scaledFont(12).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(alignment: .top) {
            if divider {
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
            }
        }
    }

    // MARK: 每一笔

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("每一笔").scaledFont(13, weight: .semibold)
                Spacer()
                Text("\(activePlans.count) 笔").scaledFont(11.5).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            ForEach(activePlans, id: \.id) { l in planRow(l) }
        }
    }

    private func planRow(_ l: Liability) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(l.name).scaledFont(14, weight: .semibold).lineLimit(1)
                Spacer(minLength: 6)
                Text("¥" + money(DebtEngine.perPeriod(l)))
                    .scaledFont(15, weight: .semibold).monospacedDigit()
            }
            HStack(spacing: 6) {
                Text(accountName(of: l)).scaledFont(11).foregroundStyle(.secondary).lineLimit(1)
                Text("·").scaledFont(11).foregroundStyle(.secondary)
                Text("第 \(DebtEngine.currentPeriod(l))/\(l.totalPeriods) 期 · 剩 \(DebtEngine.remainingPeriods(l)) 期")
                    .scaledFont(11).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xF0F0EE)).frame(height: 5)
                    Capsule().fill(Theme.green)
                        .frame(width: max(geo.size.width * DebtEngine.progress(l), 0), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(Radius.medium)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    // MARK: 工具

    private func accountName(of l: Liability) -> String {
        guard let id = l.linkedAccountID,
              let acc = accounts.first(where: { $0.id == id }) else { return "未归属账户" }
        return acc.name
    }

    private var payoffDateText: String {
        guard let d = DebtEngine.payoffDate(activePlans) else { return "—" }
        return Self.monthFormatter.string(from: d)
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 M 月"
        return f
    }()

    private func money(_ value: Decimal) -> String {
        Money.string(NSDecimalNumber(decimal: value).doubleValue)
    }
}

#Preview { InstallmentOverviewView() }
