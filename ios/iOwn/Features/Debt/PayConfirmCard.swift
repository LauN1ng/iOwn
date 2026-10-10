import SwiftUI
import SwiftData

/// 还款确认卡（负债与可支配-方案-v1 D6/D7）
/// 还款日自动弹 / 手动触发：确认「已还完」→ 进度 +1 + 自动记一笔还款支出
/// 兼容两种习惯：也可「还没还」（跳过，到期再提醒）
struct PayConfirmCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var liability: Liability
    var onPaid: (() -> Void)? = nil

    private var due: Decimal { DebtEngine.dueThisMonth(liability) }
    private var pay: Decimal { Decimal(WageConfig.load().takeHomePay) }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            VStack(spacing: 8) {
                Text(liability.iconChar)
                    .scaledFont(28, weight: .semibold).foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Color(hex: liability.iconHex))
                    .cornerRadius(16)

                Text("今天该还\(liability.name)了").scaledFont(16, weight: .bold)
                    .padding(.top, 4)
                Text(confirmSubLine).scaledFont(12).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text("¥ \(Money.string(dec(due)))")
                    .scaledFont(32, weight: .heavy, design: .rounded)
                    .foregroundStyle(Theme.greenText).monospacedDigit()
                    .padding(.top, 8)

                if liability.kind == .installment {
                    Text("已还 \(liability.paidPeriods)/\(liability.totalPeriods) 期 · 还完这期剩 \(max(liability.totalPeriods - liability.paidPeriods - 1, 0)) 期")
                        .scaledFont(11).foregroundStyle(.secondary)
                }

                if pay > 0 {
                    Text("本月可支配将变为 ¥\(Money.string(dec(pay - due)))")
                        .scaledFont(11.5).foregroundStyle(.secondary).padding(.top, 2)
                }
            }
            .padding(.top, 14)

            HStack(spacing: 10) {
                Button {
                    Haptics.tap(); dismiss()
                } label: {
                    Text("还没还").scaledFont(13.5, weight: .semibold).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.bg).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle(scale: 0.97))

                Button {
                    Haptics.success()
                    markPaid()
                    dismiss()
                } label: {
                    Text("已还完 ✓").scaledFont(13.5, weight: .semibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.green).cornerRadius(12)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.97))
            }
            .padding(.top, 20)

            Text("确认后：进度 +1 期 · 自动记一笔还款支出")
                .scaledFont(11).foregroundStyle(.secondary)
                .padding(.top, 12)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .background(Theme.bg)
    }

    private var confirmSubLine: String {
        if liability.kind == .installment {
            return "第 \(liability.paidPeriods + 1) 期 · 还款日 \(liability.dueDay) 日"
        }
        return "还款日 \(liability.dueDay) 日"
    }

    /// D7：推进进度 + 自动记一笔还款支出（进流水，影响统计/洞察口径）
    private func markPaid() {
        if liability.kind == .installment {
            liability.paidPeriods = min(liability.paidPeriods + 1, liability.totalPeriods)
        }
        // 自动记一笔支出：分类归「固定」的子类，挂在关联账户上
        let tx = Tx(amount: due, type: .out,
                    categoryID: "fixed", subID: "repay",
                    note: "还款 · \(liability.name)",
                    date: .now, source: .manual)
        tx.accountID = liability.linkedAccountID
        modelContext.insert(tx)
        try? modelContext.save()
        onPaid?()
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

/// 发薪日结算页（负债与可支配-方案-v1 屏幕 6）
/// 顶部大绿卡给出「结算后可支配」+ 一键勾选全部还清
struct SettleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Liability.sortOrder) private var liabilities: [Liability]

    @State private var checked: Set<String> = []

    private var pay: Decimal { Decimal(WageConfig.load().takeHomePay) }
    private var selected: [Liability] { liabilities.filter { checked.contains($0.id) } }
    private var selectedTotal: Decimal {
        selected.reduce(Decimal(0)) { $0 + DebtEngine.dueThisMonth($1) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("发薪日结算").scaledFont(13).foregroundStyle(.white.opacity(0.9))
                    Text("¥ \(Money.string(dec(pay - selectedTotal)))")
                        .scaledFont(44, weight: .heavy, design: .rounded)
                        .foregroundStyle(.white).monospacedDigit().padding(.top, 8)
                    Text("到手 ¥\(Money.string(dec(pay))) − 本月应还 ¥\(Money.string(dec(selectedTotal)))\n这就是你这个月能花的钱")
                        .scaledFont(12.5).foregroundStyle(.white.opacity(0.88))
                        .lineSpacing(4).padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22).padding(.top, 60).padding(.bottom, 30)
                .background(LinearGradient(colors: [Theme.green, Theme.greenDeep],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))

                VStack(spacing: 9) {
                    HStack {
                        Text("一键还清").scaledFont(13, weight: .semibold)
                        Spacer()
                        Button {
                            Haptics.tap()
                            if checked.count == liabilities.count { checked.removeAll() }
                            else { checked = Set(liabilities.map(\.id)) }
                        } label: {
                            Text(checked.count == liabilities.count ? "取消全选" : "全选")
                                .scaledFont(12).foregroundStyle(Theme.blueText)
                        }
                    }
                    .padding(.horizontal, 4).padding(.top, 18)

                    ForEach(liabilities, id: \.id) { l in
                        Button {
                            Haptics.tap()
                            if checked.contains(l.id) { checked.remove(l.id) } else { checked.insert(l.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: checked.contains(l.id) ? "checkmark.circle.fill" : "circle")
                                    .scaledFont(20)
                                    .foregroundStyle(checked.contains(l.id) ? Theme.green : Color(hex: 0xC9CDD1))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.name).scaledFont(13.5, weight: .semibold)
                                    Text(paySubline(l)).scaledFont(11).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("¥\(Money.string(dec(DebtEngine.dueThisMonth(l))))")
                                    .scaledFont(13.5, weight: .semibold).monospacedDigit()
                            }
                            .padding(14)
                            .background(Theme.card).cornerRadius(Radius.medium)
                            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.985))
                    }

                    HStack {
                        Text("合计还出").scaledFont(13.5, weight: .semibold)
                        Spacer()
                        Text("¥\(Money.string(dec(selectedTotal)))")
                            .scaledFont(13.5, weight: .semibold).monospacedDigit()
                    }
                    .padding(.horizontal, 4).padding(.top, 8)

                    Button {
                        Haptics.success()
                        settleAll()
                        dismiss()
                    } label: {
                        Text("一键结清本月")
                            .scaledFont(15, weight: .semibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(selected.isEmpty ? Theme.disabled : Theme.green)
                            .cornerRadius(14)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.985))
                    .disabled(selected.isEmpty)
                    .padding(.top, 12)
                }
                .padding(.horizontal, 18)
            }
        }
        .background(Theme.bg)
        .ignoresSafeArea(edges: .top)
        .onAppear { checked = Set(liabilities.map(\.id)) }
    }

    private func paySubline(_ l: Liability) -> String {
        l.kind == .installment
            ? "第 \(l.paidPeriods + 1)/\(l.totalPeriods) 期"
            : "还款日 \(l.dueDay) 日"
    }

    /// 批量结清：逐条推进进度 + 各记一笔支出
    private func settleAll() {
        for l in selected {
            let due = DebtEngine.dueThisMonth(l)
            if l.kind == .installment {
                l.paidPeriods = min(l.paidPeriods + 1, l.totalPeriods)
            }
            let tx = Tx(amount: due, type: .out,
                        categoryID: "fixed", subID: "repay",
                        note: "还款 · \(l.name)", date: .now, source: .manual)
            tx.accountID = l.linkedAccountID
            modelContext.insert(tx)
        }
        try? modelContext.save()
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

#Preview { SettleView() }
