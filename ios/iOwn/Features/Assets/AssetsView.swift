import SwiftUI
import SwiftData

/// 资产页（M2-B3/B4）：绿色净资产卡 + 四指标卡 + 现金/信用账户组 + 转账胶囊
/// 视觉对照：site/prototype.html #assets（视觉基准 v1.1 §5——全 App 唯一绿色重卡片）
struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]
    @Query(sort: \Liability.sortOrder) private var liabilities: [Liability]
    @Query(sort: \FixedExpense.sortOrder) private var fixedExpenses: [FixedExpense]

    /// 跳转洞察页（净资产趋势）——由 RootTabView 注入切换 Tab；默认空实现保证 `AssetsView()` 仍可构造
    var onOpenInsight: () -> Void = {}

    @State private var editingAccount: Account?
    @State private var showTransfer = false
    @State private var showAddAccount = false   // 右上角 ＋ → 建户（原先是右下琥珀 $ FAB）
    @State private var hidden = false          // 👁 隐私遮挡
    @State private var cashExpanded = true
    @State private var creditExpanded = true

    // CI 截图钩子：信用账户详情 / 固定支出都是 NavigationLink 目标，
    // 没有程序化入口就拍不到 → 用 isPresented 版本的下钻
    @State private var ciCredit: Account?
    @State private var showCreditDetail = false
    @State private var showFixedExpense = false

    private let ciArgs = ProcessInfo.processInfo.arguments

    private var cashAccounts: [Account] { accounts.filter { !$0.kind.isCredit } }
    private var creditAccounts: [Account] { accounts.filter { $0.kind.isCredit } }
    private var totals: BalanceEngine.Totals { BalanceEngine.totals(accounts: accounts, txs: txs) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    netCard
                    trendLink

                    if accounts.isEmpty {
                        EmptyStateCard(icon: "💳", title: "还没有账户",
                                       hint: "点右上角 ＋ 添加第一个账户")
                    } else {
                        // 信用账户在前：负债是"资产页的另一个视角"，且是需要关注的数字
                        if !creditAccounts.isEmpty {
                            accountGroup(title: "信用账户", list: creditAccounts,
                                         expanded: $creditExpanded, isCredit: true)
                        }
                        if !cashAccounts.isEmpty {
                            accountGroup(title: "现金账户", list: cashAccounts,
                                         expanded: $cashExpanded, isCredit: false)
                        }
                    }

                    fixedEntry

                    if accounts.count >= 2 {
                        transferPill
                    }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 40)   // 资产页已无 FAB（FAB 只在非资产 Tab 显示），无需再让开 56+76
            }
            .background(Theme.bg)
            // v1.4 头部统一：与线索/洞察/设置一致走系统 large title，不再自绘居中标题
            .navigationTitle("资产")
            // 建户入口（2026-10-11：右下琥珀 $ FAB 已删 —— 它会盖住账户行金额；
            // 改为导航栏 ＋，与信用账户详情页「添加分期」的 ＋ 位置一致）
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showAddAccount = true } label: {
                        Image(systemName: "plus").scaledFont(16, weight: .semibold)
                    }
                    .accessibilityLabel("添加账户")
                }
            }
            // CI 钩子下钻目标（正常使用走 NavigationLink，见 accountGroup / fixedEntry）
            .navigationDestination(isPresented: $showCreditDetail) {
                if let acc = ciCredit { CreditedAccountView(account: acc) }
            }
            .navigationDestination(isPresented: $showFixedExpense) {
                FixedExpenseView()
            }
        }
        // 半屏 sheet（与记一笔统一）：不盖主屏，保留背后资产页上下文；可上拖全屏
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editingAccount) { acc in
            AddAccountSheet(editing: acc)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showTransfer) { TransferSheet() }
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.hidden)
        .onAppear {
            // 建户 sheet 截图钩子（入口已从 FAB 移到本页右上角 ＋）
            if ciArgs.contains("-ci-open-account") { showAddAccount = true }
            guard ciArgs.contains("-ci-open-credit") || ciArgs.contains("-ci-open-fixed") else { return }
            // 等 RootTabView 把 demo 数据落库后再取账户（onAppear 顺序不保证）
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 900_000_000)
                if ciArgs.contains("-ci-open-credit"),
                   let acc = accounts.first(where: { $0.kind.isCredit }) {
                    ciCredit = acc
                    showCreditDetail = true
                }
                if ciArgs.contains("-ci-open-fixed") {
                    showFixedExpense = true
                }
            }
        }
    }

    // MARK: 绿色净资产卡（眼/趋势圆钮 + 波浪底 + 总资产/总负债分列）

    private var netCard: some View {
        LinearGradient(colors: [Theme.green, Theme.greenDeep], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                Ellipse()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .offset(y: 34)
            }
            .overlay {
                VStack(spacing: 0) {
                    HStack {
                        Button { Haptics.tap(); withAnimation(Motion.fade) { hidden.toggle() } } label: {
                            Image(systemName: hidden ? "eye.slash" : "eye")
                                .scaledFont(14)
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.9))
                        .tapTarget()                          // 命中区 44
                        .accessibilityLabel(hidden ? "显示金额" : "隐藏金额")
                        Spacer()
                        // 净资产趋势：原先是没有动作的 Image（看着像按钮），现接洞察页
                        Button { Haptics.tap(); onOpenInsight() } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .scaledFont(14)
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.9))
                        .tapTarget()                          // 命中区 44
                        .accessibilityLabel("查看净资产趋势")
                    }
                    Spacer()
                    Text("净资产").scaledFont(13).foregroundStyle(.white.opacity(0.85))
                    Text(hidden ? "¥ ****" : "¥ \(money(totals.net))")
                        .scaledFont(38, weight: .heavy, design: .rounded)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .tracking(-0.5)   // 大字收紧字距
                        .padding(.top, 2)

                    HStack(spacing: 0) {
                        splitCol("总资产", hidden ? "¥ ****" : "¥ \(money(totals.totalAssets))")
                        Rectangle().fill(Color.white.opacity(0.25)).frame(width: 0.5, height: 30)
                        splitCol("总负债", hidden ? "¥ ****" : "¥ \(money(totals.totalDebt))")
                    }
                    .padding(.top, 14)
                }
                .padding(18)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large))
    }

    private func splitCol(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(k).scaledFont(12).foregroundStyle(.white.opacity(0.8))
            Text(v).scaledFont(17, weight: .bold).foregroundStyle(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 趋势链接（M4 接洞察页）

    private var trendLink: some View {
        // 原先是纯 Text（看着是链接却点不动）——改为真按钮，跳洞察页；视觉尺寸保持不变
        Button { Haptics.tap(); onOpenInsight() } label: {
            Text("净资产趋势 ›")
                .scaledFont(14, weight: .semibold)
                .foregroundStyle(Theme.blueText)
                .frame(maxWidth: .infinity)
                .padding(.top, -2)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .accessibilityLabel("查看净资产趋势")
    }

    // MARK: 账户组（现金/信用）

    private func accountGroup(title: String, list: [Account], expanded: Binding<Bool>,
                              isCredit: Bool = false) -> some View {
        // ⚠️ 不要把字符串插值写跨行：单行字面量 "..." 的 \( ) 内不允许换行
        // （只有多行字面量 """ 才可以）→ 先算值再拼串
        let due = DebtEngine.monthlyDueAll(accounts: list, liabilities: liabilities, txs: txs)
        let headerRight: String = isCredit
            ? (hidden ? "¥ ****" : "本月应还 ¥\(money(due))")
            : groupTotalText(title: title, list: list)
        return VStack(spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(Motion.disclosure) { expanded.wrappedValue.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).scaledFont(16, weight: .bold).foregroundStyle(.primary)
                    Spacer()
                    Text(headerRight + (expanded.wrappedValue ? " ⌄" : " ›"))
                        .scaledFont(14, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.98))
            .accessibilityLabel("\(title)，\(headerRight)")
            .accessibilityValue(expanded.wrappedValue ? "已展开" : "已收起")
            .accessibilityHint("双击展开或收起")

            if expanded.wrappedValue {
                VStack(spacing: 0) {
                    ForEach(list, id: \.id) { acc in
                        if isCredit {
                            // 信用账户 = 负债的载体：点进去是账户详情（当期欠款 + 分期 + 还款）
                            NavigationLink { CreditedAccountView(account: acc) } label: {
                                accountRowContent(acc, isCredit: true)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.98))
                        } else {
                            Button {
                                Haptics.tap()
                                editingAccount = acc
                            } label: {
                                accountRowContent(acc, isCredit: false)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.98))
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(Theme.card)
                .cornerRadius(Radius.large)
            }
        }
        .padding(.horizontal, 4)
    }

    /// 固定支出 / 订阅入口（独立模块 —— 不是负债）
    private var fixedEntry: some View {
        let total = fixedExpenses.reduce(Decimal(0)) { $0 + $1.amount }
        return NavigationLink { FixedExpenseView() } label: {
            HStack(spacing: 12) {
                Text("📅")
                    .scaledFont(20)
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
                    Text(hidden ? "¥ ****" : "¥\(money(total))")
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

    private func groupTotalText(title: String, list: [Account]) -> String {
        let sum = list.reduce(Decimal(0)) { $0 + BalanceEngine.displayBalance(of: $1, txs: txs) }
        if hidden { return "¥ ****" }
        if sum < 0 { return "-¥ \(money(-sum))" }
        return "¥ \(money(sum))"
    }

    /// 账户行内容（信用账户：右侧显示「本月应还」；现金账户：显示余额）
    private func accountRowContent(_ acc: Account, isCredit: Bool) -> some View {
        let bal = BalanceEngine.displayBalance(of: acc, txs: txs)
        let negative = bal < 0
        let due = isCredit
            ? DebtEngine.monthlyDue(account: acc, liabilities: liabilities, txs: txs)
            : 0
        return HStack(spacing: 12) {
            Text(acc.kind.logoChar)
                .scaledFont(17, weight: .bold)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: acc.kind.brandColorHex))
                .cornerRadius(12)
                .accessibilityHidden(true)   // 装饰：品牌字块，账户名已在右侧念出

            VStack(alignment: .leading, spacing: 1) {
                Text(acc.name).scaledFont(15.5, weight: .semibold).foregroundStyle(.primary)
                Text(subLine(acc, bal: bal))
                    .scaledFont(11.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(rightAmount(bal: bal, due: due, isCredit: isCredit))
                    .scaledFont(15.5, weight: .bold)
                    .foregroundStyle(rightColor(negative: negative, isCredit: isCredit))
                    .monospacedDigit()
                if isCredit {
                    Text("本月应还").scaledFont(10).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityHint(isCredit ? "打开信用账户详情（负债）" : "打开账户编辑")
    }

    private func rightAmount(bal: Decimal, due: Decimal, isCredit: Bool) -> String {
        if hidden { return "¥ ****" }
        if isCredit { return "¥ \(money(due))" }
        return bal < 0 ? "-¥ \(money(-bal))" : "¥ \(money(bal))"
    }

    private func rightColor(negative: Bool, isCredit: Bool) -> Color {
        if hidden { return Theme.greenText }
        if isCredit { return Theme.redText }
        return negative ? Theme.redText : Theme.greenText
    }

    /// 副注：现金类 = 备注或"记账自动联动"；信用类 = 已用额度 · 还款日（B4 / M4）
    /// ⚠️ 信用类副注必须短：行内左侧可用宽约 160pt，写全「还款日 25 日」会被 lineLimit(1) 截成「已用 ¥7,000.00 · 还款日 2…」
    private func subLine(_ acc: Account, bal: Decimal) -> String {
        if acc.kind.isCredit {
            var parts: [String] = ["已用 ¥\(money(abs(bal)))"]
            if let day = acc.dueDay { parts.append("\(day) 日还款") }
            else if let day = acc.billDay { parts.append("\(day) 日账单") }
            return parts.joined(separator: " · ")
        }
        return acc.brand.isEmpty ? "记账自动联动" : acc.brand
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

    /// 千分位金额（资产页数值大，¥ 38,642.55）
    /// 统一走共享 Money.string —— 原先这里另建了一个 NumberFormatter，与首页/成功屏口径漂移
    private func money(_ value: Decimal) -> String {
        Money.string(NSDecimalNumber(decimal: value).doubleValue)
    }
}

#Preview { AssetsView() }
