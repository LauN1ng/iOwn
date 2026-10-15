import SwiftUI
import SwiftData
import UIKit

/// 资产页（2026-10-11 去卡片化 · B 方案「分组列表」）
///
/// 结构：净资产汇总行 → **现金账户分组** → **信用账户分组** → 固定支出入口 → 转账胶囊。
///
/// 为什么去掉卡堆（用户 2026-10-11 定）：
/// 卡堆「太重 / 没有美术资源去绘制卡面 / 浅色化后又失去原本的样子」——三个症状同源：
/// **仿真卡面是个无底洞**。参考的 4 款同类 App 全是列表，没有一家做仿真卡面；
/// 资产页的重点是「一眼看清我有多少、欠多少」，不是炫卡面。
///
/// ⭐ 图标统一走「**内容 bbox 归一化**」的素材（见 `reports/_build_brand_icons.py`）：
///    通用账户 = Fluent 3D（`acct_*`），品牌账户 = 真实 logo（`logo_*`）。
///    两类素材的「内容最大边」都是画布的 72%，所以**第一眼看过去大小一致** ——
///    这比「统一材质风格」更决定观感（40pt 下人眼分辨不出材质，但对大小极敏感）。
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
    @State private var showInstallments = false

    private let ciArgs = ProcessInfo.processInfo.arguments

    private var cashAccounts: [Account] { accounts.filter { !$0.kind.isCredit } }
    private var creditAccounts: [Account] { accounts.filter { $0.kind.isCredit } }
    private var totals: BalanceEngine.Totals { BalanceEngine.totals(accounts: accounts, txs: txs) }
    /// 还有未还期的分期（有才显示「分期总览」入口）
    private var activePlans: [Liability] {
        liabilities.filter { $0.kind == .installment && DebtEngine.remainingPeriods($0) > 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    netSummary

                    if accounts.isEmpty {
                        EmptyStateCard(icon: "acct_card", title: "还没有账户",
                                       hint: "点右上角 ＋ 添加第一个账户")
                    } else {
                        // 信用在前：负债是「资产页的另一个视角」，且是需要关注的数字
                        if !creditAccounts.isEmpty {
                            accountGroup(title: "信用账户", list: creditAccounts)
                        }
                        if !cashAccounts.isEmpty {
                            accountGroup(title: "现金账户", list: cashAccounts)
                        }
                    }

                    if !activePlans.isEmpty { installmentEntry }

                    fixedEntry

                    if accounts.count >= 2 {
                        transferPill
                    }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 4)
                // 110 = 避开悬浮 TabBar + 底部内容不被遮挡（对齐 InsightView）
                .padding(.bottom, 110)
            }
            .background(Theme.bg)
            .navigationTitle("资产")
            // 建户入口（原右下琥珀 $ FAB 已删——它会盖住账户行金额；与信用账户详情页「添加分期」同位置）
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showAddAccount = true } label: {
                        Image(systemName: "plus").scaledFont(.title, weight: .semibold)
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
            .navigationDestination(isPresented: $showInstallments) {
                InstallmentOverviewView()
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
            if ciArgs.contains("-ci-open-account") {
                showAddAccount = true
            }
            guard ciArgs.contains("-ci-open-credit")
                || ciArgs.contains("-ci-open-cash")
                || ciArgs.contains("-ci-open-fixed")
                || ciArgs.contains("-ci-open-installments") else { return }
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
                if ciArgs.contains("-ci-open-installments") {
                    showInstallments = true
                }
            }
        }
    }

    // MARK: 净资产汇总行（纯文本，不是绿色重卡）

    private var netSummary: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("净资产").scaledFont(.sm).foregroundStyle(.secondary)
                Text(hidden ? "¥ ****" : "¥ " + money(totals.net))
                    .scaledFont(.xl, weight: .heavy, design: .rounded)
                    .monospacedDigit()
                    .foregroundStyle(totals.net < 0 ? Theme.redText : Color.primary)
                Text(hidden
                     ? "总资产 ¥ **** · 总负债 ¥ ****"
                     : "总资产 ¥" + money(totals.totalAssets) + " · 总负债 ¥" + money(totals.totalDebt))
                    .scaledFont(.xs)
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
                        .scaledFont(.sm)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.9))
                .accessibilityLabel(hidden ? "显示金额" : "隐藏金额")

                Button { Haptics.tap(); onOpenInsight() } label: {
                    Text("净资产趋势 ›")
                        .scaledFont(.sm, weight: .semibold)
                        .foregroundStyle(Theme.blueText)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.97))
                .accessibilityLabel("查看净资产趋势")
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: 账户分组（B 方案核心：白卡分组 + 行式账户）

    private func accountGroup(title: String, list: [Account]) -> some View {
        VStack(spacing: 0) {
            // 头部：标题 + 右侧汇总小字
            HStack(alignment: .firstTextBaseline) {
                Text(title).scaledFont(.sm, weight: .semibold)
                Spacer(minLength: 8)
                Text(groupSubtitle(title: title, list: list))
                    .scaledFont(.xs)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            // 账户行（⚠️ 用 indices 而不是 Array(enumerated())：元组元素不能做 KeyPath）
            ForEach(list.indices, id: \.self) { idx in
                accountRow(list[idx], divider: idx > 0)
            }
        }
        .padding(.bottom, 6)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    /// 分组右上角小字：个数 · 合计
    private func groupSubtitle(title: String, list: [Account]) -> String {
        if hidden { return "\(list.count) 个 · ¥ ****" }
        if title == "信用账户" {
            let due = list.reduce(Decimal(0)) { $0 + DebtEngine.monthlyDue(account: $1, liabilities: liabilities, txs: txs) }
            return "\(list.count) 个 · 本月应还 ¥" + money(due)
        }
        let sum = list.reduce(Decimal(0)) { $0 + BalanceEngine.displayBalance(of: $1, txs: txs) }
        return "\(list.count) 个 · 合计 ¥" + money(sum)
    }

    private func accountRow(_ acc: Account, divider: Bool) -> some View {
        NavigationLink {
            destination(for: acc)
        } label: {
            HStack(spacing: 12) {
                accountIcon(acc)

                VStack(alignment: .leading, spacing: 1) {
                    Text(acc.name)
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(rowSubtitle(acc))
                        .scaledFont(.xs)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(rowAmount(acc))
                    .scaledFont(.body, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(acc.kind.isCredit ? Theme.redText : Color.primary)
                    .lineLimit(1)

                Text("›").scaledFont(.title).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if divider {
                    Rectangle().fill(Theme.hairline).frame(height: 0.5).padding(.leading, 16)
                }
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .accessibilityLabel("\(acc.name)，\(rowAmount(acc))")
        .accessibilityHint("打开账户详情")
    }

    /// 账户图标（归一化素材：通用 Fluent 3D / 品牌真实 logo）
    ///
    /// ⚠️ 彩色贴图**不加 `.renderingMode(.template)`**（会被染成单色）。
    /// 无 asset 时退回**单字字块**（M 徽标语族，暂时保留）；emoji 兜底层已于 2026-10-15 删除。
    private func accountIcon(_ acc: Account) -> some View {
        Group {
            if !acc.icon.asset.isEmpty, UIImage(named: acc.icon.asset) != nil {
                Image(acc.icon.asset).resizable().scaledToFit()
            } else {
                Text(acc.kind.logoChar).scaledFont(.body, weight: .heavy).foregroundStyle(.secondary)
            }
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func destination(for acc: Account) -> some View {
        if acc.kind.isCredit {
            CreditedAccountView(account: acc)
        } else {
            AccountDetailView(account: acc)
        }
    }

    /// 行副标题：信用类看账单；现金类看尾号/备注
    private func rowSubtitle(_ acc: Account) -> String {
        if hidden { return "金额已隐藏" }
        if acc.kind.isCredit {
            var parts: [String] = []
            if let day = acc.dueDay { parts.append("\(day) 日还款") }
            else if let day = acc.billDay { parts.append("\(day) 日账单") }
            if !acc.cardLast4.isEmpty { parts.append("尾号 " + acc.cardLast4) }
            return parts.isEmpty ? "信用账户" : parts.joined(separator: " · ")
        }
        if !acc.cardLast4.isEmpty { return "尾号 " + acc.cardLast4 }
        return acc.brand.isEmpty ? "记账自动联动" : acc.brand
    }

    /// 行金额：信用类 = 本月应还；现金类 = 余额
    private func rowAmount(_ acc: Account) -> String {
        if hidden { return "¥ ****" }
        if acc.kind.isCredit {
            let due = DebtEngine.monthlyDue(account: acc, liabilities: liabilities, txs: txs)
            return "¥ " + money(due)
        }
        let bal = BalanceEngine.displayBalance(of: acc, txs: txs)
        return bal < 0 ? "-¥ " + money(-bal) : "¥ " + money(bal)
    }

    // MARK: 分期总览入口（2026-10-11：补上「所有分期藏在各账户详情里、看不到全貌」的缺口）

    private var installmentEntry: some View {
        let total = activePlans.reduce(Decimal(0)) { $0 + DebtEngine.remaining($1) }
        let months = DebtEngine.payoffMonths(activePlans)
        return Button { Haptics.tap(); showInstallments = true } label: {
            HStack(spacing: 12) {
                CategoryIcon(asset: "cur_tear_off_calendar", size: 26)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("分期总览").scaledFont(.body, weight: .semibold).foregroundStyle(.primary)
                    Text(hidden
                         ? "金额已隐藏"
                         : "\(activePlans.count) 笔 · 还剩 \(months) 期 · 还欠 ¥" + money(total))
                        .scaledFont(.xs).foregroundStyle(.secondary).monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("›").scaledFont(.title).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(Radius.large)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .accessibilityHint("查看全部分期与还清时间")
    }

    // MARK: 固定支出 / 订阅入口（独立模块 —— 不是负债）

    private var fixedEntry: some View {
        let total = fixedExpenses.reduce(Decimal(0)) { $0 + $1.amount }
        return NavigationLink { FixedExpenseView() } label: {
            HStack(spacing: 12) {
                CategoryIcon(asset: "cat_fixed", size: 26)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("固定支出 / 订阅").scaledFont(.body, weight: .semibold).foregroundStyle(.primary)
                    Text(fixedExpenses.isEmpty ? "房租、会员等每月固定扣 · 不是负债"
                                               : "\(fixedExpenses.count) 项 · 每月固定扣")
                        .scaledFont(.xs).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if !fixedExpenses.isEmpty {
                    Text(hidden ? "¥ ****" : "¥" + money(total))
                        .scaledFont(.body, weight: .semibold).monospacedDigit()
                        .foregroundStyle(.primary)
                }
                Text("›").scaledFont(.title).foregroundStyle(.tertiary)
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
                .scaledFont(.body, weight: .semibold)
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
