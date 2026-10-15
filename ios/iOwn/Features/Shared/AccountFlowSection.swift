import SwiftUI

/// 通用「账户流水」区块（2026-10-11 抽出为共享组件）
///
/// 现金账户详情（`AccountDetailView`）原本自带流水；**信用账户详情此前没有**
/// —— 这是资产页去卡片化后留下的三条尾巴之一。抽成共享组件后两处共用同一套行样式，
/// 避免以后再次漂移。
///
/// ⚠️ 行内用 `indices` 而非 `Array(enumerated())`：SwiftUI 元组元素**不能**做 KeyPath。
struct AccountFlowSection: View {
    /// 账户名 —— 只用于空态提示文案
    let accountName: String
    /// 已按账户过滤、并**按日期倒序**排好的流水
    let txs: [Tx]
    var shownLimit: Int = 30
    var emptyTitle: String = "还没有流水"

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    private var shownTxs: [Tx] { Array(txs.prefix(shownLimit)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("流水").scaledFont(.sm, weight: .semibold)
                Spacer()
                Text("\(txs.count) 笔").scaledFont(.xs).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            if txs.isEmpty {
                EmptyStateCard(icon: "cur_receipt", title: emptyTitle,
                               hint: "记一笔时选「\(accountName)」就会出现在这里")
            } else {
                VStack(spacing: 0) {
                    ForEach(shownTxs.indices, id: \.self) { idx in
                        row(shownTxs[idx], divider: idx > 0)
                    }
                }
                .padding(.vertical, 4)
                .background(Theme.card)
                .cornerRadius(Radius.large)

                if txs.count > shownLimit {
                    Text("只显示最近 \(shownLimit) 笔")
                        .scaledFont(.xs).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func row(_ tx: Tx, divider: Bool) -> some View {
        let cat = CategoryPresets.category(id: tx.categoryID)
        return HStack(spacing: 12) {
            CategoryIcon(asset: cat?.iconName, size: 22)
                .frame(width: 36, height: 36)
                .background(Theme.iconBg)
                .cornerRadius(11)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(Self.title(tx, cat: cat))
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(tx.note.isEmpty ? (cat?.name ?? "") : tx.note)
                    .scaledFont(.xs)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(Self.amount(tx))
                    .scaledFont(.body, weight: .bold)
                    .monospacedDigit()
                    .foregroundStyle(tx.type == .out ? Color.primary : Theme.greenText)
                Text(Self.dayFormatter.string(from: tx.date))
                    .scaledFont(.micro)
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

    private static func title(_ tx: Tx, cat: CategoryDef?) -> String {
        if tx.source == .repayment { return "还款" }
        if tx.type == .transfer { return "转账" }
        return cat?.name ?? "记账"
    }

    private static func amount(_ tx: Tx) -> String {
        let m = Money.string(NSDecimalNumber(decimal: tx.amount).doubleValue)
        switch tx.type {
        case .out: return "-¥ " + m
        case .in: return "+¥ " + m
        case .transfer: return "¥ " + m
        }
    }
}
