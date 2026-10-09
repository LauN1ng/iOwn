import SwiftUI
import SwiftData

/// 资产页（M2-B3/B4）：绿色净资产卡 + 四指标卡 + 现金/信用账户组 + 转账胶囊
/// 视觉对照：site/prototype.html #assets（视觉基准 v1.1 §5——全 App 唯一绿色重卡片）
struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Tx.date, order: .reverse) private var txs: [Tx]

    @State private var showAddAccount = false
    @State private var editingAccount: Account?
    @State private var showTransfer = false
    @State private var hidden = false          // 👁 隐私遮挡
    @State private var cashExpanded = true
    @State private var creditExpanded = true

    private var cashAccounts: [Account] { accounts.filter { !$0.kind.isCredit } }
    private var creditAccounts: [Account] { accounts.filter { $0.kind.isCredit } }
    private var totals: BalanceEngine.Totals { BalanceEngine.totals(accounts: accounts, txs: txs) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    header
                    netCard
                    trendLink
                    metricCard

                    if accounts.isEmpty {
                        EmptyStateCard(icon: "💳", title: "还没有账户",
                                       hint: "点右上 💳 或右下 $ 添加第一个账户")
                    } else {
                        if !cashAccounts.isEmpty {
                            accountGroup(title: "现金账户", list: cashAccounts,
                                         expanded: $cashExpanded)
                        }
                        if !creditAccounts.isEmpty {
                            accountGroup(title: "信用账户", list: creditAccounts,
                                         expanded: $creditExpanded)
                        }
                        if accounts.count >= 2 {
                            transferPill
                        }
                    }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 150)   // 让开右下 FAB（底 76 + 高 56）与 TabBar，避免转账胶囊被切
            }
            .background(Theme.bg)
        }
        // 半屏 sheet（与记一笔统一）：不盖主屏，保留背后资产页上下文；可上拖全屏
        .sheet(isPresented: $showAddAccount) { AddAccountSheet() }
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.hidden)   // 自绘 grabber 已有，隐藏系统把手防双条
        .sheet(item: $editingAccount) { acc in
            AddAccountSheet(editing: acc)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showTransfer) { TransferSheet() }
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.hidden)
    }

    // MARK: 头部（居中标题 + 右上 💳 建户）

    private var header: some View {
        ZStack {
            Text("资产").font(.system(size: 24, weight: .bold))
            HStack {
                Spacer()
                Button { Haptics.tap(); showAddAccount = true } label: {
                    Text("💳").font(.system(size: 15))
                        .frame(width: 34, height: 34)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.9))
            }
        }
        .padding(.top, 4)
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
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.9))
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis")   // 净资产趋势（M4 接洞察）
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("净资产").font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                    Text(hidden ? "¥ ****" : "¥ \(money(totals.net))")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
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
            Text(k).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
            Text(v).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 趋势链接（M4 接洞察页）

    private var trendLink: some View {
        Text("净资产趋势 ›")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.blue)
            .frame(maxWidth: .infinity)
            .padding(.top, -2)
    }

    // MARK: 四指标卡（2×2）：可支配/负债/借出/借入

    private var metricCard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                  spacing: 14) {
            metric("可支配", hidden ? "¥ ****" : "¥ \(money(totals.disposable))", .green)
            metric("负债", hidden ? "¥ ****" : "-¥ \(money(totals.totalDebt))", .red)
            metric("借出", hidden ? "¥ ****" : "¥ \(money(totals.lent))", .blue)
            metric("借入", hidden ? "¥ ****" : "¥ \(money(totals.borrowed))", .blue)
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    private func metric(_ k: String, _ v: String, _ color: ThemeAccent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.system(size: 12.5)).foregroundStyle(.secondary)
            Text(v).font(.system(size: 19, weight: .bold)).foregroundStyle(color.color).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 账户组（现金/信用）

    private func accountGroup(title: String, list: [Account], expanded: Binding<Bool>) -> some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(Motion.disclosure) { expanded.wrappedValue.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(.primary)
                    Spacer()
                    Text(groupTotalText(title: title, list: list) + (expanded.wrappedValue ? " ⌄" : " ›"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.98))

            if expanded.wrappedValue {
                VStack(spacing: 0) {
                    ForEach(list, id: \.id) { acc in
                        accountRow(acc)
                    }
                }
                .padding(.vertical, 4)
                .background(Theme.card)
                .cornerRadius(Radius.large)
            }
        }
        .padding(.horizontal, 4)
    }

    private func groupTotalText(title: String, list: [Account]) -> String {
        let sum = list.reduce(Decimal(0)) { $0 + BalanceEngine.displayBalance(of: $1, txs: txs) }
        if hidden { return "¥ ****" }
        if sum < 0 { return "-¥ \(money(-sum))" }
        return "¥ \(money(sum))"
    }

    private func accountRow(_ acc: Account) -> some View {
        let bal = BalanceEngine.displayBalance(of: acc, txs: txs)
        let negative = bal < 0
        return Button {
            Haptics.tap()
            editingAccount = acc
        } label: {
            HStack(spacing: 12) {
                Text(acc.kind.logoChar)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: acc.kind.brandColorHex))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 1) {
                    Text(acc.name).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(.primary)
                    Text(subLine(acc, bal: bal))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(hidden ? "¥ ****" : (negative ? "-¥ \(money(-bal))" : "¥ \(money(bal))"))
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(negative ? Theme.red : Theme.green)
                    .monospacedDigit()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
    }

    /// 副注：现金类 = 备注或"记账自动联动"；信用类 = 剩余额度 · 账单日（B4）
    private func subLine(_ acc: Account, bal: Decimal) -> String {
        if acc.kind.isCredit {
            var parts: [String] = []
            if let limit = acc.creditLimit, limit > 0 {
                let remaining = limit - abs(bal)
                parts.append("剩余额度 ¥ \(money(max(remaining, 0)))")
            }
            if let day = acc.billDay { parts.append("账单日 \(day) 日") }
            return parts.isEmpty ? (acc.brand.isEmpty ? "信用账户" : acc.brand) : parts.joined(separator: " · ")
        }
        return acc.brand.isEmpty ? "记账自动联动" : acc.brand
    }

    // MARK: 转账胶囊

    private var transferPill: some View {
        Button { Haptics.tap(); showTransfer = true } label: {
            Text("转账")
                .font(.system(size: 15.5, weight: .semibold))
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

    private enum ThemeAccent {
        case green, red, blue
        var color: Color {
            switch self {
            case .green: Theme.green; case .red: Theme.red; case .blue: Theme.blue
            }
        }
    }

    /// 千分位金额（资产页数值大，¥ 38,642.55）
    private func money(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}

#Preview { AssetsView() }
