import SwiftUI
import SwiftData

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
    @Query private var txs: [Tx]

    var account: Account

    /// 显式 init：@Query 会被 memberwise init 暴露成 `_liabilities` / `_txs`，屏蔽掉
    init(account: Account) { self.account = account }

    @State private var showAdd = false
    @State private var editingPlan: Liability?
    @State private var showPaidConfirm = false

    // MARK: 派生值（全部纯函数，改账/删账自动回滚）

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

    var body: some View {
        ScrollView {
            VStack(spacing: Radius.cardSpacing) {
                heroCard
                currentBillCard
                plansSection
                if !plans.isEmpty { totalRow }
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
                    Image(systemName: "plus").scaledFont(16, weight: .semibold)
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
        .confirmationDialog("标记本月已还款？", isPresented: $showPaidConfirm, titleVisibility: .visible) {
            Button("已还完 ¥\(Money.string(dec(monthlyDue)))") { markPaid() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("每笔分期的期数各 +1，并自动记一笔还款流水（不计入消费统计）")
        }
    }

    // MARK: 绿卡

    private var heroCard: some View {
        LinearGradient(colors: [Theme.green, Theme.greenDeep], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                Ellipse().fill(Color.white.opacity(0.14))
                    .frame(height: 44).frame(maxWidth: .infinity).offset(y: 34)
            }
            .overlay {
                VStack(alignment: .leading, spacing: 0) {
                    Text("本月应还").scaledFont(12).foregroundStyle(.white.opacity(0.88))
                    Text("¥ \(Money.string(dec(monthlyDue)))")
                        .scaledFont(32, weight: .heavy, design: .rounded)
                        .foregroundStyle(.white).monospacedDigit()
                        .padding(.top, 4)
                    Text("已用 ¥\(Money.string(dec(used)))" + limitText)
                        .scaledFont(11.5).foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 5)
                    HStack {
                        Text("账单日 \(dayText(account.billDay))")
                        Spacer()
                        Text("还款日 \(dayText(account.dueDay))")
                    }
                    .scaledFont(11).foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 12)
                }
                .padding(18)
            }
            .frame(height: 178)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large))
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
                Text("当期欠款").scaledFont(13, weight: .semibold)
                Text("只读 · 来自记账")
                    .scaledFont(10, weight: .medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 1.5)
                    .background(Theme.iconBg).cornerRadius(6)
                Spacer()
                Text("¥\(Money.string(dec(currentBill)))")
                    .scaledFont(18, weight: .bold).monospacedDigit()
            }
            Text("选「\(account.name)」支付的记账会自动汇总到这里，不需要你录入。")
                .scaledFont(11.5).foregroundStyle(.secondary)
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
            EmptyStateCard(icon: "🧾", title: "还没有分期",
                           hint: "点右上角 ＋ 添加；已还一半的老账也能补录")
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("分期").scaledFont(13, weight: .semibold)
                    Spacer()
                    Text("\(plans.count) 笔 · 剩余共 \(remainingPeriodsTotal) 期")
                        .scaledFont(11.5).foregroundStyle(.secondary)
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
                    Text(l.name).scaledFont(14, weight: .semibold)
                    Text("分期 \(l.totalPeriods) 期")
                        .scaledFont(10, weight: .medium)
                        .foregroundStyle(Color(hex: 0x8A5A0B))
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .background(Color(hex: 0xFCF3E2)).cornerRadius(6)
                    Spacer(minLength: 6)
                    Text("¥\(Money.string(dec(DebtEngine.perPeriod(l))))")
                        .scaledFont(15, weight: .semibold).monospacedDigit()
                }
                Text("第 \(l.paidPeriods)/\(l.totalPeriods) 期 · 剩 \(DebtEngine.remainingPeriods(l)) 期")
                    .scaledFont(11).foregroundStyle(.secondary)
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
                Text("当期欠款").scaledFont(12.5).foregroundStyle(.secondary)
                Spacer()
                Text("¥\(Money.string(dec(currentBill)))").scaledFont(12.5).monospacedDigit()
            }
            HStack {
                Text("分期月供").scaledFont(12.5).foregroundStyle(.secondary)
                Spacer()
                Text("¥\(Money.string(dec(planDue)))").scaledFont(12.5).monospacedDigit()
            }
            Divider().overlay(Theme.hairline)
            HStack {
                Text("本月应还合计").scaledFont(13.5, weight: .semibold)
                Spacer()
                Text("¥ \(Money.string(dec(monthlyDue)))")
                    .scaledFont(15, weight: .bold).monospacedDigit()
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
                        .scaledFont(15, weight: .semibold)
                        .foregroundStyle(Theme.greenText)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.greenSoft).cornerRadius(14)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.985))
            }
            if monthlyDue > 0 {
                Button { Haptics.tap(); showPaidConfirm = true } label: {
                    Text("标记本月已还款")
                        .scaledFont(15, weight: .semibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.green)
                        .cornerRadius(14)
                        .shadow(color: Theme.green.opacity(0.32), radius: 10, y: 5)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.985))
                Text("只推进分期期数并记一笔还款流水，当期欠款靠记账自动更新")
                    .scaledFont(11).foregroundStyle(.secondary)
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
