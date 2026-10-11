import Foundation
import SwiftData

/// 记一笔的落库草稿（值类型，与 View 状态解耦）
struct TxDraft {
    var amount: Decimal
    var isOut: Bool
    var categoryID: String
    var subID: String?
    var note: String
    var mood: Mood?
    var accountID: String?
    var date: Date
    var payMethod: PayMethod
    var installmentPeriods: Int          // 仅 payMethod == .creditInstallment 时有意义
    var installmentFeeRate: Decimal      // 同上（总费率，如 8.8 表示 8.8%）
}

/// 记一笔的落库核心（D18）。
///
/// **为什么单独成层**：原先这段逻辑埋在 `AddEntrySheet.save()` 里，是 private，
/// 结果「记账 → 负债」的联动行为**无法被自动验证**（CI 只能截图、不能点击）。
/// 抽出来之后，UI 与 `SelfTest` 走的是**同一段代码**，自检才有意义。
enum EntryWriter {
    /// 新建一笔：入库 + 按付款方式落地负债
    @discardableResult
    static func insert(_ d: TxDraft, into context: ModelContext) -> Tx {
        let tx = Tx(amount: d.amount,
                    type: d.isOut ? .out : .in,
                    categoryID: d.categoryID,
                    subID: d.subID,
                    note: d.note,
                    mood: d.mood,
                    accountID: d.accountID,     // 挂账户 → 余额自动联动
                    date: d.date,
                    source: .manual,
                    payMethod: d.payMethod)
        context.insert(tx)
        syncLiability(for: tx, draft: d, into: context)
        return tx
    }

    /// 改账：原地更新字段（余额是推导值，无需手动回滚），并同步分期笔本金
    static func update(_ tx: Tx, with d: TxDraft, into context: ModelContext) {
        tx.amount = d.amount
        tx.type = d.isOut ? .out : .in
        tx.categoryID = d.categoryID
        tx.subID = d.subID
        tx.note = d.note
        tx.mood = d.mood
        tx.accountID = d.accountID
        tx.date = d.date
        tx.payMethodRaw = d.payMethod.rawValue
        syncLiability(for: tx, draft: d, into: context)
    }

    /// 按付款方式落地负债。**关键口径**：
    /// - `.normal` / `.creditFull`：**不新建任何负债** —— 那笔钱已经通过 `Tx.accountID`
    ///   扣减了信用账户余额，会被 `DebtEngine.currentBill`（= max(|余额| − Σ分期剩余本金, 0)）
    ///   自动算进「当期欠款」。若这里再建一条负债，就是**双计**。
    /// - `.creditInstallment`：在该信用账户名下新建一笔分期并回链 `tx.liabilityID`；
    ///   已回链过（改账）则只同步本金。
    static func syncLiability(for tx: Tx, draft d: TxDraft, into context: ModelContext) {
        guard d.payMethod == .creditInstallment else { return }
        guard let accID = d.accountID,
              let acc = account(id: accID, in: context),
              acc.kind.isCredit else { return }

        // 改账：已有分期笔 → 只同步本金/名称，不重复建档
        if let lid = tx.liabilityID,
           let existing = liabilities(in: context).first(where: { $0.id == lid }) {
            existing.principal = tx.amount
            if !tx.note.isEmpty { existing.name = tx.note }
            return
        }

        _ = LiabilityLinker.apply(tx: tx, account: acc,
                                  periods: d.installmentPeriods,
                                  feeRate: d.installmentFeeRate,
                                  context: context)
    }

    // MARK: 查询（统一走 context，避免依赖 @Query）

    static func account(id: String, in context: ModelContext) -> Account? {
        (try? context.fetch(FetchDescriptor<Account>()))?.first { $0.id == id }
    }

    static func liabilities(in context: ModelContext) -> [Liability] {
        (try? context.fetch(FetchDescriptor<Liability>())) ?? []
    }

    // MARK: 还款

    /// 标记本月已还款：分期各推进 1 期 + 记一笔还款流水。
    ///
    /// ⚠️ **还款流水的方向极易写反 → 必须记成 `.in`（挂在该信用账户上）**。
    /// `BalanceEngine` 的约定是「支出 −amount / 收入 +amount」，而信用账户
    /// **余额为负 = 欠款**；所以「还款让欠款减少」在这套符号里等价于给余额 **加** amount。
    /// 写成 `.out` 会得到「越还欠越多」——这个 bug 2026-10-11 由 `BehaviorSelfTest` 抓到
    /// （自检第一轮就派上用场）。
    ///
    /// 还款**不是消费**：打 `source = .repayment`，洞察统计与首页日合计均排除它。
    /// 本期结清后 `currentBill` 会归零（因为 |余额| 掉到分期剩余本金之下被 clamp），
    /// 下月消费重新累积 —— 即「本期结清、下月重来」。
    @discardableResult
    static func recordRepayment(account: Account, plans: [Liability], amount: Decimal,
                               into context: ModelContext) -> Tx? {
        guard amount > 0 else { return nil }
        for l in plans where l.kind == .installment && DebtEngine.remainingPeriods(l) > 0 {
            l.paidPeriods = min(l.paidPeriods + 1, l.totalPeriods)
        }
        let tx = Tx(amount: amount, type: .in,
                    categoryID: "fixed", subID: "repay",
                    note: "还款 · \(account.name)", date: .now, source: .repayment)
        tx.accountID = account.id
        context.insert(tx)
        return tx
    }
}
