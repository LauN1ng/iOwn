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
    case autoNotification   // iOS 27 通知自动化（主链路）
    case backTap            // 轻点背面
    case actionButton       // 操作按钮 / 辅助触控
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
    var name: String
    var brand: String                // 品牌/备注小字
    var balance: Decimal             // 信用账户余额为负 → 负债
    var kind: AccountKind
    var billDay: Int?                // 信用账户账单日；额度 = 固定字段额度 - 已用
    var creditLimit: Decimal?        // 仅信用卡

    init(name: String, brand: String, balance: Decimal, kind: AccountKind,
         billDay: Int? = nil, creditLimit: Decimal? = nil) {
        self.name = name; self.brand = brand; self.balance = balance
        self.kind = kind; self.billDay = billDay; self.creditLimit = creditLimit
    }
}
