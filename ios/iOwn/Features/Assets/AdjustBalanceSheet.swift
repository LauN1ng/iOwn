import SwiftUI
import SwiftData

/// 余额调整 · 对账（2026-10-11 去卡片化三尾巴之一）
///
/// **场景**：App 里的余额和真实账户对不上（漏记、记错、账户自身的利息 / 手续费）。
/// **做法**：输入**实际余额**，App 把差额写进 `initialBalance`（整体平移）。
///
/// **不产生流水** —— 余额 = `initialBalance + Σ交易`，平移初始值即可；
/// 而且不会污染任何统计口径（洞察页只统计 `type == .out`）。
struct AdjustBalanceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tx.date, order: .reverse) private var allTxs: [Tx]

    var account: Account

    /// 显式 init：@Query 会被 memberwise init 暴露成 `_allTxs`，屏蔽掉
    init(account: Account) { self.account = account }

    @State private var actualStr = ""

    private var current: Decimal { BalanceEngine.displayBalance(of: account, txs: allTxs) }

    /// 用户填的「实际」值。信用账户按**欠款正数**填写，内部取负以对齐余额口径。
    private var actual: Decimal? {
        let trimmed = actualStr.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let v = Decimal(string: trimmed) else { return nil }
        return account.kind.isCredit ? -abs(v) : v
    }

    private var diff: Decimal? {
        guard let a = actual else { return nil }
        return a - current
    }

    private var canSave: Bool {
        guard let d = diff else { return false }
        return d != 0
    }

    var body: some View {
        // 把手必须在 ScrollView **之外**（D3 §5.2）：放里面会跟着内容一起滚走
        VStack(spacing: 0) {
            SheetGrabber()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("调整余额（对账）")
                        .scaledFont(.title, weight: .bold)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("App 里的余额").scaledFont(.sm).foregroundStyle(.secondary)
                            Spacer()
                            Text(moneyText(current))
                                .scaledFont(.body, weight: .semibold).monospacedDigit()
                        }
                        Divider().overlay(Theme.hairline)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(account.kind.isCredit ? "实际欠款（填正数）" : "实际余额")
                                .scaledFont(.xs).foregroundStyle(.secondary)
                            TextField("0.00", text: $actualStr)
                                .keyboardType(.decimalPad)
                                .scaledFont(.lg, weight: .bold)
                                .monospacedDigit()
                        }
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card)
                    .corner(Radius.large)

                    if let d = diff, d != 0 {
                        let up = d > 0
                        Text((up ? "将上调 ¥" : "将下调 ¥") + moneyText(abs(d)))
                            .scaledFont(.sm, weight: .semibold)
                            .foregroundStyle(up ? Theme.greenText : Theme.redText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Theme.card)
                            .corner(Radius.small)
                    }

                    Text("调整只平移「初始余额」，不会产生流水，也不影响洞察页的任何统计。")
                        .scaledFont(.xs).foregroundStyle(.secondary)

                    Button {
                        Haptics.success()
                        save()
                        dismiss()
                    } label: {
                        Text("确认调整")
                            .scaledFont(.body, weight: .semibold).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .green3D(enabled: canSave)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.985))
                    .disabled(!canSave)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .background(Theme.bg)
        .onAppear {
            let v = account.kind.isCredit ? abs(current) : current
            actualStr = NSDecimalNumber(decimal: v).stringValue
        }
    }

    private func save() {
        guard let d = diff else { return }
        account.initialBalance += d
        try? modelContext.save()
    }

    private func moneyText(_ d: Decimal) -> String {
        "¥ " + Money.string(NSDecimalNumber(decimal: abs(d)).doubleValue)
    }
}

#Preview {
    AdjustBalanceSheet(account: Account(name: "支付宝", initialBalance: 12368.20, kind: .alipay))
}
