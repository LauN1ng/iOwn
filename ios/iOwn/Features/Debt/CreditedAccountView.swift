import SwiftUI
import SwiftData
import UIKit

/// 信用账户详情 = 原来的「负债页」（2026-10-10 v4 定案：负债并入信用账户）
///
/// 结构：绿卡（本月应还 + 已用/额度 + 账单日·还款日）
///      + 当期欠款卡（**只读**，由记账派生）
///      + 分期笔列表（每期金额 / 第 x/n 期 / 进度条）
///      + 本月应还合计 + 标记本月已还款
///
/// 视觉对照：site/prototype-v3.html 「信用账户详情」
struct CreditedAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var liabilities: [Liability]
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]

    var account: Account

    /// 显式 init：@Query 会被 memberwise init 暴露成 `_liabilities` / `_txs`，屏蔽掉
    init(account: Account) { self.account = account }

    @State private var showAdd = false
    @State private var editingPlan: Liability?
    @State private var showPaidConfirm = false
    @State private var showAdjust = false

    // MARK: 派生值（全部纯函数，改账/删账自动回滚）

    /// 该账户的流水（含转入转出）—— 2026-10-11 补上「信用账户没有流水」这个缺口
    private var accountTxs: [Tx] {
        txs.filter { $0.accountID == account.id || $0.toAccountID == account.id }
    }

    private var plans: [Liability] {
        DebtEngine.bills(of: account.id, liabilities: liabilities)
            .filter { $0.kind == .installment }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    private var used: Decimal { abs(BalanceEngine.displayBalance(of: account, txs: txs)) }
    private var currentBill: Decimal {
        DebtEngine.currentBill(account: account, liabilities: liabilities, txs: txs)
    }
    private var planDue: Decimal {
        DebtEngine.installmentDue(accountID: account.id, liabilities: liabilities)
    }
    private var monthlyDue: Decimal { currentBill + planDue }
    private var remainingPeriodsTotal: Int {
        plans.reduce(0) { $0 + DebtEngine.remainingPeriods($1) }
    }
    /// 已分期部分（未偿还金额，含手续费/利息）—— 与 currentBill 相减的口径一致
    private var planRemaining: Decimal {
        plans.reduce(Decimal(0)) { $0 + DebtEngine.remainingPrincipal($1) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Radius.cardSpacing) {
                heroCard
                totalOwedCard
                currentBillCard
                plansSection
                if !plans.isEmpty { totalRow }
                AccountFlowSection(accountName: account.name, txs: accountTxs)
                actions
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 40)   // 资产 Tab 已无 FAB（FAB 只在非资产 Tab 显示）
        }
        .background(Theme.bg)
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.tap(); showAdd = true } label: {
                    Image(systemName: "plus").scaledFont(.title, weight: .semibold)
                }
                .accessibilityLabel("添加分期")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddInstallmentSheet(defaultAccountID: account.id)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editingPlan) { l in
            AddInstallmentSheet(defaultAccountID: account.id, editing: l)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showAdjust) {
            AdjustBalanceSheet(account: account)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .confirmationDialog("标记本月已还款？", isPresented: $showPaidConfirm, titleVisibility: .visible) {
            Button("已还完 ¥\(Money.string(dec(monthlyDue)))") { markPaid() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("每笔分期的期数各 +1，并自动记一笔还款流水（不计入消费统计）")
        }
    }

    // MARK: 本月应还（2026-10-11 去卡片化：原卡面 hero → 白卡）

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                accountIcon
                Text(account.name)
                    .scaledFont(.sm, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                // 「调整」= 对账（平移初始余额，不产生流水）
                Button { Haptics.tap(); showAdjust = true } label: {
                    Text("调整")
                        .scaledFont(.sm, weight: .semibold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 13).padding(.vertical, 7)
                        .background(Theme.iconBg)
                        .cornerRadius(999)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.95))
                .accessibilityLabel("调整余额（对账）")
            }
            .padding(.bottom, 12)

            Text("本月应还").scaledFont(.sm).foregroundStyle(.secondary)
            Text("¥ \(Money.string(dec(monthlyDue)))")
                .scaledFont(.display, weight: .heavy, design: .rounded)
                .foregroundStyle(Theme.redText).monospacedDigit()
                .padding(.top, 4)
            Text("已用 ¥\(Money.string(dec(used)))" + limitText)
                .scaledFont(.xs).foregroundStyle(.secondary)
                .padding(.top, 5)
            // ⭐「债有尽头」——预计还清日（`DebtEngine.payoffDate`，此前无界面）
            if let payoff = payoffText {
                HStack(spacing: 5) {
                    // 2026-10-15：SF Symbol → Fluent 3D（原 10pt 太小，3D 体积读不出，提到 15pt）
                    Image("nav_flag").renderingMode(.original).resizable().scaledToFit()
                        .frame(width: 15, height: 15)
                    Text(payoff)
                }
                .scaledFont(.xs, weight: .semibold)
                .foregroundStyle(Theme.greenText)
                .padding(.top, 7)
            }
            HStack {
                Text("账单日 \(dayText(account.billDay))")
                Spacer()
                Text("还款日 \(dayText(account.dueDay))")
            }
            .scaledFont(.xs).foregroundStyle(.secondary)
            .padding(.top, 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    /// ⭐「债有尽头」——预计还清日 + 还剩几期。
    /// 取该账户**最后一笔**分期还完的月份（`DebtEngine.payoffMonths` / `payoffDate`）。
    /// 没有未还完的分期时返回 `nil`（不显示这一行）。
    private var payoffText: String? {
        let months = DebtEngine.payoffMonths(plans)
        guard months > 0, let date = DebtEngine.payoffDate(plans) else { return nil }
        return "还清日 " + Self.payoffFormatter.string(from: date) + " · 还剩 \(months) 期"
    }

    private static let payoffFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 M 月"
        return f
    }()

    /// 账户图标（归一化素材：通用 Fluent 3D / 品牌真实 logo）
    private var accountIcon: some View {
        Group {
            if !account.icon.asset.isEmpty, UIImage(named: account.icon.asset) != nil {
                // ⚠️ 彩色贴图：不要加 .renderingMode(.template)
                Image(account.icon.asset).resizable().scaledToFit()
            } else {
                // 2026-10-15：emoji 兜底层已删 → 落到单字字块（暂时保留）
                Text(account.kind.logoChar).scaledFont(.sm, weight: .heavy).foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    /// 一共还欠（账户属性 —— 不是分期的属性）= 已分期未还本金 + 没分期的当期欠款
    private var totalOwedCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("一共还欠").scaledFont(.sm).foregroundStyle(.secondary)
                Spacer()
                Text("¥\(Money.string(dec(used)))")
                    .scaledFont(.title, weight: .bold).monospacedDigit()
            }
            Text("其中 已分期 ¥" + Money.string(dec(planRemaining))
                 + " · 没分期 ¥" + Money.string(dec(currentBill)))
                .scaledFont(.xs).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    private var limitText: String {
        guard let limit = account.creditLimit, limit > 0 else { return "" }
        return " / 额度 ¥\(Money.string(dec(limit)))"
    }

    private func dayText(_ d: Int?) -> String {
        guard let d else { return "—" }
        return "\(d) 日"
    }

    // MARK: 当期欠款（只读）

    private var currentBillCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("当期欠款").scaledFont(.sm, weight: .semibold)
                Text("只读 · 来自记账")
                    .scaledFont(.micro, weight: .medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 1.5)
                    .background(Theme.iconBg).cornerRadius(6)
                Spacer()
                Text("¥\(Money.string(dec(currentBill)))")
                    .scaledFont(.title, weight: .bold).monospacedDigit()
            }
            Text("选「\(account.name)」支付的记账会自动汇总到这里，不需要你录入。")
                .scaledFont(.xs).foregroundStyle(.secondary)
        }
        .padding(15)
        .background(Theme.card)
        .cornerRadius(Radius.large)
        .overlay(RoundedRectangle(cornerRadius: Radius.large)
            .stroke(Theme.hairline, lineWidth: 1))
    }

    // MARK: 分期列表

    @ViewBuilder
    private var plansSection: some View {
        if plans.isEmpty {
            EmptyStateCard(icon: "cur_receipt", title: "还没有分期",
                           hint: "点右上角 ＋ 添加；已还一半的老账也能补录")
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("分期").scaledFont(.sm, weight: .semibold)
                    Spacer()
                    Text("\(plans.count) 笔 · 剩余共 \(remainingPeriodsTotal) 期")
                        .scaledFont(.xs).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                ForEach(plans, id: \.id) { l in planRow(l) }
            }
        }
    }

    private func planRow(_ l: Liability) -> some View {
        Button { Haptics.tap(); editingPlan = l } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(l.name).scaledFont(.body, weight: .semibold)
                    Text("分期 \(l.totalPeriods) 期")
                        .scaledFont(.micro, weight: .medium)
                        .foregroundStyle(Color(hex: 0x8A5A0B))
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .background(Color(hex: 0xFCF3E2)).cornerRadius(6)
                    Spacer(minLength: 6)
                    Text("¥\(Money.string(dec(DebtEngine.displayDue(l))))")
                        .scaledFont(.body, weight: .semibold).monospacedDigit()
                }
                Text("第 \(DebtEngine.currentPeriod(l))/\(l.totalPeriods) 期 · 剩 \(DebtEngine.remainingPeriods(l)) 期")
                    .scaledFont(.xs).foregroundStyle(.secondary)
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
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .accessibilityHint("打开编辑，长按可删除")
        .contextMenu {
            Button { Haptics.tap(); editingPlan = l } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Haptics.tap()
                modelContext.delete(l)
                try? modelContext.save()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: 合计 + 操作

    private var totalRow: some View {
        VStack(spacing: 8) {
            HStack {
                Text("当期欠款").scaledFont(.sm).foregroundStyle(.secondary)
                Spacer()
                Text("¥\(Money.string(dec(currentBill)))").scaledFont(.sm).monospacedDigit()
            }
            HStack {
                Text("分期月供").scaledFont(.sm).foregroundStyle(.secondary)
                Spacer()
                Text("¥\(Money.string(dec(planDue)))").scaledFont(.sm).monospacedDigit()
            }
            Divider().overlay(Theme.hairline)
            HStack {
                Text("本月应还合计").scaledFont(.sm, weight: .semibold)
                Spacer()
                Text("¥ \(Money.string(dec(monthlyDue)))")
                    .scaledFont(.body, weight: .bold).monospacedDigit()
            }
        }
        .padding(15)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            if plans.isEmpty {
                Button { Haptics.tap(); showAdd = true } label: {
                    Text("＋ 添加一笔分期")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.greenText)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.greenSoft).cornerRadius(14)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.985))
            }
            if monthlyDue > 0 {
                Button { Haptics.tap(); showPaidConfirm = true } label: {
                    Text("标记本月已还款")
                        .scaledFont(.body, weight: .semibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .green3D()
                }
                .buttonStyle(PressableButtonStyle(scale: 0.985))
                Text("只推进分期期数并记一笔还款流水，当期欠款靠记账自动更新")
                    .scaledFont(.xs).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 6)
    }

    // MARK: 还款

    private func markPaid() {
        Haptics.success()
        // 落库核心在 Data 层（EntryWriter）—— UI 与 `BehaviorSelfTest` 走同一段代码
        EntryWriter.recordRepayment(account: account, plans: plans,
                                    amount: monthlyDue, into: modelContext)
        try? modelContext.save()
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

#Preview { CreditedAccountView(account: Account(name: "花呗", initialBalance: -3000, kind: .huabei)) }
