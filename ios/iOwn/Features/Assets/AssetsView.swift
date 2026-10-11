import SwiftUI
import SwiftData

/// 资产页（2026-10-11 卡包改造）
///
/// 结构：净资产文字行（不是绿色重卡）→ **卡堆** → 固定支出入口 → 转账胶囊。
/// 卡堆照用户参考图：整卡染卡面色、后一张压住前一张、**最后一张整张露出**。
/// ⚠️ 排序 = **创建时间**（用户 2026-10-11 定：不按信用/现金分组，信用不优先）。
/// 点任意卡片 → 账户详情：信用 → `CreditedAccountView`（含分期）；现金 → `AccountDetailView`。
struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]
    @Query(sort: \Liability.sortOrder) private var liabilities: [Liability]
    @Query(sort: \FixedExpense.sortOrder) private var fixedExpenses: [FixedExpense]

    /// 跳转洞察页（净资产趋势）——由 RootTabView 注入切换 Tab；默认空实现保证 `AssetsView()` 仍可构造
    var onOpenInsight: () -> Void = {}

    @State private var showTransfer = false
    @State private var showAddAccount = false   // 右上角 ＋ → 建户
    @State private var hidden = false           // 👁 隐私遮挡

    // CI 截图钩子：详情页都是 NavigationLink 目标，没有程序化入口就拍不到
    @State private var ciCredit: Account?
    @State private var ciCash: Account?
    @State private var showCreditDetail = false
    @State private var showCashDetail = false
    @State private var showFixedExpense = false

    private let ciArgs = ProcessInfo.processInfo.arguments

    private var totals: BalanceEngine.Totals { BalanceEngine.totals(accounts: accounts, txs: txs) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    netSummary

                    if accounts.isEmpty {
                        EmptyStateCard(icon: "💳", title: "还没有账户",
                                       hint: "点右上角 ＋ 添加第一个账户")
                    } else {
                        cardStack
                    }

                    fixedEntry

                    if accounts.count >= 2 {
                        transferPill
                    }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .navigationTitle("资产")
            // 建户入口（原右下琥珀 $ FAB 已删——它会盖住卡面金额；与信用账户详情页「添加分期」同位置）
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showAddAccount = true } label: {
                        Image(systemName: "plus").scaledFont(16, weight: .semibold)
                    }
                    .accessibilityLabel("添加账户")
                }
            }
            .navigationDestination(isPresented: $showCreditDetail) {
                if let acc = ciCredit { CreditedAccountView(account: acc) }
            }
            .navigationDestination(isPresented: $showCashDetail) {
                if let acc = ciCash { AccountDetailView(account: acc) }
            }
            .navigationDestination(isPresented: $showFixedExpense) {
                FixedExpenseView()
            }
        }
        // 半屏 sheet（与记一笔统一）：不盖主屏，保留背后资产页上下文；可上拖全屏
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showTransfer) { TransferSheet() }
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.hidden)
        .onAppear {
            if ciArgs.contains("-ci-open-account") || ciArgs.contains("-ci-open-face") {
                showAddAccount = true
            }
            guard ciArgs.contains("-ci-open-credit")
                || ciArgs.contains("-ci-open-cash")
                || ciArgs.contains("-ci-open-fixed") else { return }
            // 等 RootTabView 把 demo 数据落库后再取账户（onAppear 顺序不保证）
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                if ciArgs.contains("-ci-open-credit"),
                   let acc = accounts.first(where: { $0.kind.isCredit }) {
                    ciCredit = acc
                    showCreditDetail = true
                }
                if ciArgs.contains("-ci-open-cash"),
                   let acc = accounts.first(where: { !$0.kind.isCredit }) {
                    ciCash = acc
                    showCashDetail = true
                }
                if ciArgs.contains("-ci-open-fixed") {
                    showFixedExpense = true
                }
            }
        }
    }

    // MARK: 净资产汇总行（纯文本，不是绿色重卡）

    private var netSummary: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("净资产").scaledFont(12).foregroundStyle(.secondary)
                Text(hidden ? "¥ ****" : "¥ " + money(totals.net))
                    .scaledFont(30, weight: .heavy, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(totals.net < 0 ? Theme.redText : Color.primary)
                Text(hidden
                     ? "总资产 ¥ **** · 总负债 ¥ ****"
                     : "总资产 ¥" + money(totals.totalAssets) + " · 总负债 ¥" + money(totals.totalDebt))
                    .scaledFont(11.5)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 9) {
                Button {
                    Haptics.tap()
                    withAnimation(Motion.fade) { hidden.toggle() }
                } label: {
                    Image(systemName: hidden ? "eye.slash" : "eye")
                        .scaledFont(13)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.9))
                .accessibilityLabel(hidden ? "显示金额" : "隐藏金额")

                Button { Haptics.tap(); onOpenInsight() } label: {
                    Text("净资产趋势 ›")
                        .scaledFont(12.5, weight: .semibold)
                        .foregroundStyle(Theme.blueText)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.97))
                .accessibilityLabel("查看净资产趋势")
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: 卡堆（顺序 = 创建时间；最后一张整张露出）

    private var cardStack: some View {
        let step: CGFloat = 52
        let cardHeight: CGFloat = 152
        let last = accounts.count - 1
        return ZStack(alignment: .top) {
            // ⚠️ 用 indices 而不是 Array(enumerated())：元组元素**不能**做 KeyPath
            ForEach(accounts.indices, id: \.self) { idx in
                cardLink(idx: idx, step: step, cardHeight: cardHeight, lastIndex: last)
            }
        }
        .frame(height: step * CGFloat(max(last, 0)) + cardHeight)
    }

    private func cardLink(idx: Int, step: CGFloat, cardHeight: CGFloat, lastIndex: Int) -> some View {
        let acc = accounts[idx]
        // 只有整张露出的那张显示底部一行（被压住的只露卡头）
        let cap: String? = idx == lastIndex ? cardCaption(acc) : nil
        return NavigationLink {
            destination(for: acc)
        } label: {
            CardFront(name: acc.name,
                      amountText: cardAmount(acc),
                      face: acc.cardFace,
                      iconName: acc.icon.asset,
                      logoChar: acc.kind.logoChar,
                      caption: cap,
                      height: cardHeight)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .offset(y: CGFloat(idx) * step)
        .zIndex(Double(idx))
        .accessibilityLabel("\(acc.name)，\(cardAmount(acc))")
        .accessibilityHint("打开账户详情")
    }

    @ViewBuilder
    private func destination(for acc: Account) -> some View {
        if acc.kind.isCredit {
            CreditedAccountView(account: acc)
        } else {
            AccountDetailView(account: acc)
        }
    }

    /// 卡面主数字：信用类 = 本月要还；现金类 = 余额
    private func cardAmount(_ acc: Account) -> String {
        if hidden { return "¥ ****" }
        if acc.kind.isCredit {
            let due = DebtEngine.monthlyDue(account: acc, liabilities: liabilities, txs: txs)
            return "¥ " + money(due)
        }
        let bal = BalanceEngine.displayBalance(of: acc, txs: txs)
        return bal < 0 ? "-¥ " + money(-bal) : "¥ " + money(bal)
    }

    /// 卡面底部小字（只有整张露出的卡片会显示）
    private func cardCaption(_ acc: Account) -> String {
        if hidden { return "金额已隐藏" }
        if acc.kind.isCredit {
            let bal = BalanceEngine.displayBalance(of: acc, txs: txs)
            var parts: [String] = ["已用 ¥" + money(abs(bal))]
            if let day = acc.dueDay { parts.append("\(day) 日还款") }
            else if let day = acc.billDay { parts.append("\(day) 日账单") }
            return parts.joined(separator: " · ")
        }
        if !acc.cardLast4.isEmpty { return "尾号 " + acc.cardLast4 }
        return acc.brand.isEmpty ? "记账自动联动" : acc.brand
    }

    // MARK: 固定支出 / 订阅入口（独立模块 —— 不是负债）

    private var fixedEntry: some View {
        let total = fixedExpenses.reduce(Decimal(0)) { $0 + $1.amount }
        return NavigationLink { FixedExpenseView() } label: {
            HStack(spacing: 12) {
                CategoryIcon(asset: "cat_fixed", fallback: "🏡", size: 26)
                    .frame(width: 40, height: 40)
                    .background(Theme.iconBg)
                    .cornerRadius(12)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("固定支出 / 订阅").scaledFont(15, weight: .semibold).foregroundStyle(.primary)
                    Text(fixedExpenses.isEmpty ? "房租、会员等每月固定扣 · 不是负债"
                                               : "\(fixedExpenses.count) 项 · 每月固定扣")
                        .scaledFont(11.5).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if !fixedExpenses.isEmpty {
                    Text(hidden ? "¥ ****" : "¥" + money(total))
                        .scaledFont(15, weight: .semibold).monospacedDigit()
                        .foregroundStyle(.primary)
                }
                Text("›").scaledFont(16).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(Radius.large)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
    }

    // MARK: 转账胶囊

    private var transferPill: some View {
        Button { Haptics.tap(); showTransfer = true } label: {
            Text("转账")
                .scaledFont(15.5, weight: .semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 44).padding(.vertical, 13)
                .background(Theme.card)
                .cornerRadius(999)
                .shadow(color: .black.opacity(0.07), radius: 7, y: 4)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
        .padding(.top, 8)
    }

    // MARK: 工具

    /// 千分位金额（统一走共享 Money.string，避免与首页/成功屏口径漂移）
    private func money(_ value: Decimal) -> String {
        Money.string(NSDecimalNumber(decimal: value).doubleValue)
    }
}

#Preview { AssetsView() }
