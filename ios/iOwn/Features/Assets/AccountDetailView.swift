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
    @State private var showAdjust = false

    private var accountTxs: [Tx] {
        allTxs.filter { $0.accountID == account.id || $0.toAccountID == account.id }
    }
    private var balance: Decimal { BalanceEngine.displayBalance(of: account, txs: allTxs) }

    var body: some View {
        ScrollView {
            VStack(spacing: Radius.cardSpacing) {
                hero
                balanceCard
                AccountFlowSection(accountName: account.name, txs: accountTxs)
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
        .sheet(isPresented: $showAdjust) {
            AdjustBalanceSheet(account: account)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: 头部（图标 + 名称 + 副标题）
    //
    // 原 hero 卡面已删除 —— 2026-10-11 去卡片化（见 `AssetsView` 文件头）。

    private var hero: some View {
        HStack(spacing: 14) {
            accountIconLarge
            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .scaledFont(22, weight: .heavy)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .scaledFont(12)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var subtitle: String {
        if !account.cardLast4.isEmpty { return "尾号 " + account.cardLast4 }
        return account.brand
    }

    /// 大号账户图标（归一化素材：通用 Fluent 3D / 品牌真实 logo）
    private var accountIconLarge: some View {
        Group {
            if !account.icon.asset.isEmpty, UIImage(named: account.icon.asset) != nil {
                // ⚠️ 彩色贴图：不要加 .renderingMode(.template)
                Image(account.icon.asset).resizable().scaledToFit()
            } else if !account.icon.emoji.isEmpty {
                Text(account.icon.emoji).scaledFont(40)
            } else {
                Text(account.kind.logoChar).scaledFont(26, weight: .heavy).foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
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
                // 「调整」= 对账（编辑初始余额，不产生流水）—— 编辑账户入口在底部按钮
                pill("调整") { Haptics.tap(); showAdjust = true }
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
