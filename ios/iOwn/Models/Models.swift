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
