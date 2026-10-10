import Foundation
import SwiftData

// MARK: - 数据模型（Spec §4 草案落地）
// 预留：onboardingCompleted: Bool（UserDefaults）；App Group "group.jizhan.shared"（小组件后置）

enum TxType: String, Codable { case out, `in`, transfer }

enum Mood: String, Codable, CaseIterable {
    case normal    // 😐 普普通通
    case satisfied // 🥰 超满足
    case impulsive // 🤯 上头了
    case lesson    // 😤 买教训

    var emoji: String {
        switch self {
        case .normal: "😐"; case .satisfied: "🥰"; case .impulsive: "🤯"; case .lesson: "😤"
        }
    }
    var label: String {
        switch self {
        case .normal: "普普通通"; case .satisfied: "超满足"; case .impulsive: "上头了"; case .lesson: "买教训"
        }
    }
}

enum Source: String, Codable {
    case manual             // 手动记
    case autoNotification   // 自动记账（预留：搁置中，待调研后重启）
    case backTap            // 轻点背面（预留）
    case actionButton       // 操作按钮 / 辅助触控（预留）
    case repayment          // 还款自动生成（负债确认还款时写入；不计入消费统计）
}

enum AccountKind: String, Codable {
    case cash, bankCard, wechat, alipay, creditCard

    /// 品牌色 logo 块（视觉基准 v1.1 §4）
    var brandColorHex: UInt32 {
        switch self {
        case .cash: 0x3ABF58
        case .bankCard: 0xF59E0B
        case .wechat: 0x2AAE67
        case .alipay: 0x1677FF
        case .creditCard: 0x8E8E93
        }
    }

    /// logo 块单字（原型 #assets：支/微/卡/信）
    var logoChar: String {
        switch self {
        case .cash: "现"; case .bankCard: "卡"; case .wechat: "微"
        case .alipay: "支"; case .creditCard: "信"
        }
    }

    /// 建户默认名（B1：建户 <30 秒——选类型即填好）
    var defaultName: String {
        switch self {
        case .cash: "现金"; case .bankCard: "银行卡"; case .wechat: "微信支付"
        case .alipay: "支付宝"; case .creditCard: "信用卡"
        }
    }

    var isCredit: Bool { self == .creditCard }
}

@Model
final class Tx {
    var amount: Decimal
    var type: TxType                 // .out / .in / .transfer
    var categoryID: String           // 大类 id（六大消费意图）
    var subID: String?               // 二级分类 id
    var note: String
    var mood: Mood?                  // 可空
    var accountID: String?           // 付款账户
    var toAccountID: String?         // 转账目标账户
    var date: Date
    var source: Source

    init(amount: Decimal, type: TxType, categoryID: String, subID: String? = nil,
         note: String = "", mood: Mood? = nil, accountID: String? = nil,
         toAccountID: String? = nil, date: Date = .now, source: Source = .manual) {
        self.amount = amount; self.type = type; self.categoryID = categoryID
        self.subID = subID; self.note = note; self.mood = mood
        self.accountID = accountID; self.toAccountID = toAccountID
        self.date = date; self.source = source
    }
}

@Model
final class Account {
    var id: String               // Tx.accountID 引用此 id（改名不影响关联）
    var name: String
    var brand: String                // 品牌/备注小字（如"工资卡 · ··1234"）
    var initialBalance: Decimal      // 初始余额；展示余额 = initialBalance + Σ交易推导（BalanceEngine）
    var kind: AccountKind
    var billDay: Int?                // 信用账户账单日
    var creditLimit: Decimal?        // 仅信用卡；剩余额度 = creditLimit - |展示余额|

    init(id: String = UUID().uuidString, name: String, brand: String = "",
         initialBalance: Decimal, kind: AccountKind,
         billDay: Int? = nil, creditLimit: Decimal? = nil) {
        self.id = id; self.name = name; self.brand = brand
        self.initialBalance = initialBalance; self.kind = kind
        self.billDay = billDay; self.creditLimit = creditLimit
    }
}

// MARK: - 负债与可支配（负债与可支配-方案-v1）
// 用户核心习惯：发薪日把花呗/信用卡/白条/房租全扣除，剩下的才是本月能花的钱。
// 建模三形态（D4）：
//   .installment  分期      —— 花呗/白条/信用卡分期：本金 × 总费率 → 每期固定金额
//   .currentBill  当期账单  —— 信用卡未分期部分：每月浮动、靠记账累加，无进度条
//   .fixed        固定金额  —— 房租等：每月固定扣，无期数
// 归类（D5）：.credit 信用负债（会还完）/ .fixedExpense 固定支出（持续发生）
// ⚠️ 手续费按原始本金计、不随已还递减 → 名义总费率 ≠ 实际年化（见 DebtEngine.apr）

enum LiabilityCategory: String, Codable {
    case credit        // 信用负债：信用卡 / 花呗 / 白条
    case fixedExpense  // 固定支出：房租 / 订阅

    var label: String { self == .credit ? "信用类" : "固定支出" }
}

enum LiabilityKind: String, Codable {
    case installment   // 分期：期数 + 每期固定
    case currentBill   // 当期账单：每月浮动
    case fixed         // 固定金额

    var label: String {
        switch self {
        case .installment: "分期"; case .currentBill: "当期账单"; case .fixed: "固定"
        }
    }
}

/// 手续费输入模式（D10）：给三种，App 自动换算每期金额
enum FeeMode: String, Codable {
    case none          // 免息
    case totalRate     // 填总费率（如 8.8%）—— 最贴近平台展示
    case apr           // 直接填年化利率

    var label: String {
        switch self {
        case .none: "免息"; case .totalRate: "总费率"; case .apr: "年化利率"
        }
    }
}

@Model
final class Liability {
    var id: String
    var name: String                 // 花呗 / 信用卡 / 房租
    var kindRaw: String              // LiabilityKind.rawValue
    var categoryRaw: String          // LiabilityCategory.rawValue
    var principal: Decimal           // 本金 / 当前欠款
    var totalPeriods: Int            // 分期总期数（.fixed 时 = 0）
    var paidPeriods: Int             // 已还期数
    var feeModeRaw: String           // FeeMode.rawValue
    var feeValue: Decimal            // 费率数值（totalRate=8.8 表示 8.8%；apr=15.86；none=0）
    var billDay: Int                 // 账单日（1-31）
    var dueDay: Int                  // 还款日（1-31）
    var startMonth: String           // 起始月 "yyyy-MM"
    var iconChar: String             // 图标字块单字（花/信/白/房）
    var iconHex: UInt32              // 图标底色
    var linkedAccountID: String?     // 关联信用账户（记账联动）
    var sortOrder: Int

    init(id: String = UUID().uuidString, name: String, kind: LiabilityKind,
         category: LiabilityCategory, principal: Decimal, totalPeriods: Int = 0,
         paidPeriods: Int = 0, feeMode: FeeMode = .none, feeValue: Decimal = 0,
         billDay: Int = 1, dueDay: Int = 25, startMonth: String = "",
         iconChar: String = "债", iconHex: UInt32 = 0x8E8E93,
         linkedAccountID: String? = nil, sortOrder: Int = 0) {
        self.id = id; self.name = name
        self.kindRaw = kind.rawValue; self.categoryRaw = category.rawValue
        self.principal = principal
        self.totalPeriods = totalPeriods; self.paidPeriods = paidPeriods
        self.feeModeRaw = feeMode.rawValue; self.feeValue = feeValue
        self.billDay = billDay; self.dueDay = dueDay
        self.startMonth = startMonth
        self.iconChar = iconChar; self.iconHex = iconHex
        self.linkedAccountID = linkedAccountID; self.sortOrder = sortOrder
    }

    var kind: LiabilityKind { LiabilityKind(rawValue: kindRaw) ?? .fixed }
    var category: LiabilityCategory { LiabilityCategory(rawValue: categoryRaw) ?? .credit }
    var feeMode: FeeMode { FeeMode(rawValue: feeModeRaw) ?? .none }
}

// MARK: - 负债推算引擎（纯函数，无存储副作用 → 改/删天然正确）

enum DebtEngine {
    /// 总手续费 = 本金 × 总费率（按原始本金计，不随已还递减）
    static func totalFee(_ l: Liability) -> Decimal {
        switch l.feeMode {
        case .none: return 0
        case .totalRate: return l.principal * l.feeValue / 100
        case .apr: return l.principal * nominalRate(l) / 100
        }
    }

    // MARK: 名义总费率 ⇄ 实际年化（IRR 口径，2026-10-10 统一）
    //
    // 花呗/白条类分期收的是「手续费」，按原始本金计、不随已还递减，
    // 所以「名义总费率」≠「实际年化」。精确换算只能解 IRR：
    //   本金按 1 计，每期还款 = (1 + R) / n（R = 总费率，n = 期数），
    //   求月利率 i 使 Σ_{k=1..n} 每期 / (1+i)^k = 1，再 ×12 年化。
    // 验证：R = 8.8%、n = 12 → i ≈ 1.32%/月 → 年化 ≈ 15.86%
    //   （旧的近似式「总费率 × 24 / (n+1)」会给出 16.25%，偏高，已弃用）

    /// 由名义总费率（%）与实际期数求实际年化（%）
    static func aprFromTotalRate(ratePercent: Decimal, periods: Int) -> Decimal {
        guard periods > 1, ratePercent > 0 else { return 0 }
        let r = NSDecimalNumber(decimal: ratePercent / 100).doubleValue
        let n = periods
        let payment = (1 + r) / Double(n)
        var lo = 0.0, hi = 0.4          // 月利率上界 40%，远超任何真实场景
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            var pv = 0.0
            for k in 1...n { pv += payment / pow(1 + mid, Double(k)) }
            if pv > 1 { lo = mid } else { hi = mid }   // 现值随利率单调递减
        }
        return Decimal(((lo + hi) / 2) * 12 * 100)
    }

    /// 由目标实际年化（%）反求名义总费率（%）—— 上面函数的数值逆
    static func totalRateFromApr(aprPercent: Decimal, periods: Int) -> Decimal {
        guard periods > 1, aprPercent > 0 else { return 0 }
        let target = NSDecimalNumber(decimal: aprPercent).doubleValue
        var lo = 0.0, hi = 300.0        // 总费率上界 300%
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            let v = NSDecimalNumber(decimal: aprFromTotalRate(ratePercent: Decimal(mid),
                                                              periods: periods)).doubleValue
            if v > target { hi = mid } else { lo = mid }
        }
        return Decimal((lo + hi) / 2)
    }

    /// 名义总费率（展示用）：填总费率时就是它；填年化时折算回它
    static func nominalRate(_ l: Liability) -> Decimal {
        switch l.feeMode {
        case .none: return 0
        case .totalRate: return l.feeValue
        case .apr: return totalRateFromApr(aprPercent: l.feeValue, periods: l.totalPeriods)
        }
    }

    /// 每期应还 = (本金 + 总手续费) / 期数
    static func perPeriod(_ l: Liability) -> Decimal {
        guard l.kind == .installment, l.totalPeriods > 0 else { return l.principal }
        return (l.principal + totalFee(l)) / Decimal(l.totalPeriods)
    }

    /// 实际年化利率（名义总费率 ≠ 实际）：统一走 IRR
    static func apr(_ l: Liability) -> Decimal {
        guard l.kind == .installment, l.totalPeriods > 1 else { return 0 }
        switch l.feeMode {
        case .none: return 0
        case .totalRate: return aprFromTotalRate(ratePercent: l.feeValue, periods: l.totalPeriods)
        case .apr: return l.feeValue
        }
    }

    /// 剩余待还总额 = 本金 + 总手续费 − 已还期数 × 每期
    static func remaining(_ l: Liability) -> Decimal {
        switch l.kind {
        case .installment:
            let left = Decimal(max(l.totalPeriods - l.paidPeriods, 0))
            return perPeriod(l) * left
        case .currentBill, .fixed:
            return l.principal
        }
    }

    /// 剩余期数
    static func remainingPeriods(_ l: Liability) -> Int {
        guard l.kind == .installment else { return 0 }
        return max(l.totalPeriods - l.paidPeriods, 0)
    }

    /// 本月应还（本项目中最简口径：分期=每期固定；当期账单=本金；固定=本金）
    static func dueThisMonth(_ l: Liability) -> Decimal {
        switch l.kind {
        case .installment: return remainingPeriods(l) > 0 ? perPeriod(l) : 0
        case .currentBill, .fixed: return l.principal
        }
    }

    /// 整体进度 0…1（分期才有意义）
    static func progress(_ l: Liability) -> Double {
        guard l.kind == .installment, l.totalPeriods > 0 else { return 0 }
        return min(max(Double(l.paidPeriods) / Double(l.totalPeriods), 0), 1)
    }

    /// 可支配 = 到手薪资 − Σ本月应还
    static func disposable(takeHomePay: Decimal, liabilities: [Liability]) -> Decimal {
        let due = liabilities.reduce(Decimal(0)) { $0 + dueThisMonth($1) }
        return takeHomePay - due
    }

    /// 全部待还合计
    static func totalRemaining(_ list: [Liability]) -> Decimal {
        list.reduce(Decimal(0)) { $0 + remaining($1) }
    }

    /// 未来 N 个月每月可支配（预测感，对应 Excel 表）
    /// 简化模型：每过一月，分期 paidPeriods +1；债务还完后该月应还归零。
    /// 返回 [(月偏移, 当月可支配, 当月应还)]
    static func forecast(takeHomePay: Decimal, liabilities: [Liability], months: Int = 12) -> [(Int, Decimal, Decimal)] {
        var out: [(Int, Decimal, Decimal)] = []
        for m in 0..<months {
            var due: Decimal = 0
            for l in liabilities {
                switch l.kind {
                case .installment:
                    if m < remainingPeriods(l) { due += perPeriod(l) }
                case .currentBill:
                    due += l.principal   // 当月账单持续（示例：按当前值平推）
                case .fixed:
                    due += l.principal
                }
            }
            out.append((m, takeHomePay - due, due))
        }
        return out
    }
}

// MARK: - 余额推导（B2 核心定案，Spec §4）

enum BalanceEngine {
    /// 展示余额 = initialBalance + Σ交易影响。
    /// 支出 -amount / 收入 +amount（挂 accountID）；转出 -amount（accountID）/ 转入 +amount（toAccountID）。
    /// 纯推导、无存储副作用 → 改账/删账天然回滚正确（B2 by construction）。
    static func displayBalance(of account: Account, txs: [Tx]) -> Decimal {
        var sum = account.initialBalance
        for tx in txs {
            switch tx.type {
            case .out where tx.accountID == account.id:     sum -= tx.amount
            case .in where tx.accountID == account.id:      sum += tx.amount
            case .transfer:
                if tx.accountID == account.id { sum -= tx.amount }
                if tx.toAccountID == account.id { sum += tx.amount }
            default: break
            }
        }
        return sum
    }

    struct Totals {
        var totalAssets: Decimal      // Σ现金类余额
        var totalDebt: Decimal        // Σ|信用类余额|
        var net: Decimal              // 总资产 - 总负债
        var disposable: Decimal       // 净资产 + 借入 - 借出（借出/借入预留 0）
        var lent: Decimal             // 借出（预留）
        var borrowed: Decimal         // 借入（预留）
    }

    static func totals(accounts: [Account], txs: [Tx]) -> Totals {
        var assets: Decimal = 0, debt: Decimal = 0
        for acc in accounts {
            let bal = displayBalance(of: acc, txs: txs)
            if acc.kind.isCredit { debt += abs(bal) } else { assets += bal }
        }
        let net = assets - debt
        return Totals(totalAssets: assets, totalDebt: debt, net: net,
                      disposable: net, lent: 0, borrowed: 0)
    }
}
