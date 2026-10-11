import Foundation
import SwiftData

/// 一条自检用例的结果
struct SelfTestResult {
    let name: String
    let expected: String
    let actual: String
    var passed: Bool { expected == actual }
}

/// CI 行为自检（launch argument `-ci-selftest` 触发）
///
/// **为什么需要**：编译通过 + 截图只证明了两件事 —— 能编译、界面长这样。
/// 它证明不了「**算得对、写得对**」。而 SwiftData 的写入 + 派生值
/// （`currentBill` / 双计 / 还款归零 / 改账删除回滚）恰恰是最容易错、
/// 又最看不出来的部分，偏偏 CI 无法点击 UI。
///
/// **做法**：让 App 自己跑一遍**真实写路径**（与 UI 共用 `EntryWriter`，
/// 见 `Data/EntryWriter.swift`），把断言结果画成一屏截图回传。
/// 跑在**独立的内存容器**里 —— 不污染真实数据，也不受 demo 数据干扰。
///
/// **口径提示**（期望值就按这套算）：
/// - 信用账户余额为负 = 欠款；支出 −amount、收入 +amount（`BalanceEngine`）
/// - 当期欠款（未分期部分）= `max(|账户余额| − Σ分期剩余本金, 0)`，只读
/// - 本月应还 = 当期欠款 + Σ分期每期金额；用**本金**相减，避免手续费漂移
enum BehaviorSelfTest {

    // MARK: 入口

    static func run() -> [SelfTestResult] {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: Tx.self, Account.self,
                                                  Liability.self, FixedExpense.self,
                                                  configurations: config) else {
            return [SelfTestResult(name: "内存容器初始化", expected: "成功", actual: "失败")]
        }
        let ctx = ModelContext(container)
        var out: [SelfTestResult] = []

        // 一张干净的信用账户（余额 0 = 不欠钱）
        let acc = Account(name: "自检卡", initialBalance: 0, kind: .creditCard,
                          billDay: 1, dueDay: 20)
        ctx.insert(acc)
        try? ctx.save()

        // ── ① 全额下期：不应建负债，但必须进「当期欠款」
        let txFull = EntryWriter.insert(draft(amount: 500, accountID: acc.id, method: .creditFull),
                                       into: ctx)
        try? ctx.save()
        var plans = linked(ctx, acc.id)
        out.append(checkCount("① 全额下期 · 不建负债", 0, plans.count))
        out.append(checkNil("① 全额下期 · 不回链", txFull.liabilityID))
        out.append(checkMoney("① 全额下期 · 当期欠款 = 该笔", 500, currentBill(acc, ctx)))

        // ── ② 分期：建 1 笔 + 回链 + 每期换算 + 只算一次（不双计）
        let txIns = EntryWriter.insert(draft(amount: 1200, accountID: acc.id,
                                             method: .creditInstallment),
                                       into: ctx)
        try? ctx.save()
        plans = linked(ctx, acc.id)
        let plan = plans.first
        out.append(checkCount("② 分期 · 建 1 笔", 1, plans.count))
        out.append(checkEqual("② 分期 · 回链 tx → 分期",
                              plan?.id ?? "(无)", txIns.liabilityID ?? "(无)"))
        out.append(checkMoney("② 分期 · 本金", 1200, plan?.principal ?? 0))
        out.append(checkMoney("② 每期 = (本金+手续费)÷12", dec("108.8"),
                              plan.map { DebtEngine.perPeriod($0) } ?? 0))
        out.append(checkMoney("② 当期欠款只含未分期部分", 500, currentBill(acc, ctx)))
        out.append(checkMoney("② 本月应还 = 500 + 108.80", dec("608.8"), monthlyDue(acc, ctx)))
        out.append(checkMoney("② 待还总额不双计（= |余额|）", 1700,
                              DebtEngine.totalRemainingAll(accounts: [acc],
                                                           liabilities: plans, txs: txs(ctx))))

        // ── ③ 改账联动：全额笔 500 → 300，当期欠款应同步
        EntryWriter.update(txFull, with: draft(amount: 300, accountID: acc.id,
                                               method: .creditFull), into: ctx)
        try? ctx.save()
        out.append(checkMoney("③ 改账 500→300 · 当期欠款", 300, currentBill(acc, ctx)))

        // ── ④ 还款（关键）：本月应还结清 + 欠款总额必须**减少**
        let balanceBefore = abs(balance(acc, ctx))
        let due = monthlyDue(acc, ctx)
        EntryWriter.recordRepayment(account: acc, plans: linked(ctx, acc.id),
                                    amount: due, into: ctx)
        try? ctx.save()
        plans = linked(ctx, acc.id)
        out.append(checkMoney("④ 还款 · 本期结清（当期欠款归零）", 0, currentBill(acc, ctx)))
        out.append(checkMoney("④ 还款 · |欠款| 减少一个 due", balanceBefore - due,
                              abs(balance(acc, ctx))))
        out.append(checkMoney("④ 还款 · 本月应还只剩分期月供", dec("108.8"), monthlyDue(acc, ctx)))

        // ── ⑤ 删账回滚：余额是推导值，删掉全额笔 → |欠款| 立刻回落
        let beforeDelete = abs(balance(acc, ctx))
        ctx.delete(txFull)
        try? ctx.save()
        out.append(checkMoney("⑤ 删账 · |欠款| 回落一笔", beforeDelete - 300,
                              abs(balance(acc, ctx))))

        return out
    }

    // MARK: 断言构造

    private static func checkMoney(_ name: String, _ expected: Decimal, _ actual: Decimal) -> SelfTestResult {
        SelfTestResult(name: name, expected: money(expected), actual: money(actual))
    }
    private static func checkCount(_ name: String, _ expected: Int, _ actual: Int) -> SelfTestResult {
        SelfTestResult(name: name, expected: "\(expected) 笔", actual: "\(actual) 笔")
    }
    private static func checkNil(_ name: String, _ value: String?) -> SelfTestResult {
        SelfTestResult(name: name, expected: "nil", actual: value == nil ? "nil" : "有值")
    }
    private static func checkEqual(_ name: String, _ expected: String, _ actual: String) -> SelfTestResult {
        SelfTestResult(name: name, expected: expected, actual: actual)
    }

    // MARK: 取值辅助

    private static func draft(amount: Decimal, accountID: String,
                              method: PayMethod) -> TxDraft {
        TxDraft(amount: amount, isOut: true, categoryID: "needs", subID: "meal",
                note: "", mood: nil, accountID: accountID, date: .now,
                payMethod: method, installmentPeriods: 12, installmentFeeRate: 8.8)
    }

    private static func linked(_ ctx: ModelContext, _ accountID: String) -> [Liability] {
        EntryWriter.liabilities(in: ctx).filter { $0.linkedAccountID == accountID }
    }
    private static func txs(_ ctx: ModelContext) -> [Tx] {
        (try? ctx.fetch(FetchDescriptor<Tx>())) ?? []
    }
    private static func balance(_ acc: Account, _ ctx: ModelContext) -> Decimal {
        BalanceEngine.displayBalance(of: acc, txs: txs(ctx))
    }
    private static func currentBill(_ acc: Account, _ ctx: ModelContext) -> Decimal {
        DebtEngine.currentBill(account: acc, liabilities: linked(ctx, acc.id), txs: txs(ctx))
    }
    private static func monthlyDue(_ acc: Account, _ ctx: ModelContext) -> Decimal {
        DebtEngine.monthlyDue(account: acc, liabilities: linked(ctx, acc.id), txs: txs(ctx))
    }

    private static func dec(_ s: String) -> Decimal { Decimal(string: s) ?? 0 }
    private static func money(_ d: Decimal) -> String {
        Money.string(NSDecimalNumber(decimal: d).doubleValue)
    }
}
