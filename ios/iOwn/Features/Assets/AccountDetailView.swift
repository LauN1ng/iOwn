import SwiftUI
import SwiftData
import UIKit

/// 现金账户详情页（2026-10-11 新增）
///
/// 照用户参考图二：hero 卡面（**不放数字**）→ 余额卡 + 转账/编辑 → 该账户流水 → 编辑账户。
/// 补上「现金账户根本没有详情页」这个缺口 —— 此前现金账户点一下直接弹编辑 sheet，
/// 与信用账户「点进详情」的行为不一致。
struct AccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tx.date, order: .reverse) private var allTxs: [Tx]

    var account: Account

    /// 显式 init：@Query 会被 memberwise init 暴露成 `_allTxs`，屏蔽掉
    init(account: Account) { self.account = account }

    @State private var showEdit = false
    @State private var showTransfer = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    private var accountTxs: [Tx] {
        allTxs.filter { $0.accountID == account.id || $0.toAccountID == account.id }
    }
    /// 只展示最近 30 笔
    private var shownTxs: [Tx] { Array(accountTxs.prefix(30)) }
    private var balance: Decimal { BalanceEngine.displayBalance(of: account, txs: allTxs) }

    var body: some View {
        ScrollView {
            VStack(spacing: Radius.cardSpacing) {
                hero
                balanceCard
                flowSection
                editButton
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Theme.bg)
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            AddAccountSheet(editing: account)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showTransfer) {
            TransferSheet()
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: hero 卡面（只有品牌，不放数字）

    private var hero: some View {
        CardFaceView(face: account.cardFace, cornerRadius: Radius.large)
            .frame(height: 148)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.name)
                        .scaledFont(22, weight: .heavy)
                        .foregroundStyle(account.cardFace.foreground)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .scaledFont(11.5)
                            .foregroundStyle(account.cardFace.foregroundSoft)
                    }
                }
                .padding(18)
            }
            .overlay(alignment: .bottomTrailing) { iconBadge.padding(16) }
            .shadow(color: .black.opacity(0.16), radius: 10, y: 6)
    }

    private var subtitle: String {
        if !account.cardLast4.isEmpty { return "尾号 " + account.cardLast4 }
        return account.brand
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(account.cardFace.logoBackground)
                .frame(width: 36, height: 36)
            if !account.icon.asset.isEmpty, UIImage(named: account.icon.asset) != nil {
                // ⚠️ 彩色 Fluent 贴图：不要加 .renderingMode(.template)
                Image(account.icon.asset).resizable().scaledToFit().frame(width: 26, height: 26)
            } else {
                Text(account.kind.logoChar)
                    .scaledFont(14, weight: .heavy)
                    .foregroundStyle(account.cardFace.foreground)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: 余额卡 + 胶囊

    private var balanceCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("当前余额").scaledFont(12).foregroundStyle(.secondary)
                Text(balance < 0 ? "-¥ " + money(-balance) : "¥ " + money(balance))
                    .scaledFont(24, weight: .heavy)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(balance < 0 ? Theme.redText : Color.primary)
            }
            Spacer(minLength: 6)
            HStack(spacing: 8) {
                pill("转账") { Haptics.tap(); showTransfer = true }
                pill("编辑") { Haptics.tap(); showEdit = true }
            }
        }
        .padding(15)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .scaledFont(12.5, weight: .semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.iconBg)
                .cornerRadius(999)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
    }

    // MARK: 该账户流水

    @ViewBuilder
    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("流水").scaledFont(13, weight: .semibold)
                Spacer()
                Text("\(accountTxs.count) 笔").scaledFont(11.5).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if accountTxs.isEmpty {
                EmptyStateCard(icon: "🧾", title: "还没有流水",
                               hint: "记一笔时选「\(account.name)」就会出现在这里")
            } else {
                VStack(spacing: 0) {
                    // ⚠️ 用 indices 而不是 Array(enumerated())：元组元素**不能**做 KeyPath
                    ForEach(shownTxs.indices, id: \.self) { idx in
                        txRow(shownTxs[idx], divider: idx > 0)
                    }
                }
                .padding(.vertical, 4)
                .background(Theme.card)
                .cornerRadius(Radius.large)
            }
        }
    }

    private func txRow(_ tx: Tx, divider: Bool) -> some View {
        let cat = CategoryPresets.category(id: tx.categoryID)
        return HStack(spacing: 12) {
            CategoryIcon(asset: cat?.iconName, fallback: cat?.emoji ?? "💸", size: 22)
                .frame(width: 36, height: 36)
                .background(Theme.iconBg)
                .cornerRadius(11)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(rowTitle(tx, cat: cat))
                    .scaledFont(14.5, weight: .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(tx.note.isEmpty ? (cat?.name ?? "") : tx.note)
                    .scaledFont(11.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(amountText(tx))
                    .scaledFont(15, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(tx.type == .out ? Color.primary : Theme.greenText)
                Text(Self.dayFormatter.string(from: tx.date))
                    .scaledFont(10.5)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .top) {
            if divider {
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
            }
        }
    }

    private func rowTitle(_ tx: Tx, cat: CategoryDef?) -> String {
        if tx.source == .repayment { return "还款" }
        if tx.type == .transfer { return "转账" }
        return cat?.name ?? "记账"
    }

    private func amountText(_ tx: Tx) -> String {
        let m = money(tx.amount)
        switch tx.type {
        case .out: return "-¥ " + m
        case .in: return "+¥ " + m
        case .transfer: return "¥ " + m
        }
    }

    // MARK: 编辑账户

    private var editButton: some View {
        Button { Haptics.tap(); showEdit = true } label: {
            Text("编辑账户")
                .scaledFont(15, weight: .semibold)
                .foregroundStyle(Theme.greenText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.greenSoft)
                .cornerRadius(14)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .padding(.top, 4)
    }

    private func money(_ value: Decimal) -> String {
        Money.string(NSDecimalNumber(decimal: value).doubleValue)
    }
}

#Preview {
    NavigationStack {
        AccountDetailView(account: Account(name: "支付宝", brand: "默认 · 记账自动联动",
                                           initialBalance: 12368.20, kind: .alipay))
    }
}
