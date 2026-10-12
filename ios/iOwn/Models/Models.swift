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
    /// Asset Catalog 图标名（Microsoft Fluent Emoji 3D）：mood_normal / mood_satisfied / …
    var iconName: String { "mood_" + rawValue }
}

enum Source: String, Codable {
    case manual             // 手动记
    case autoNotification   // 自动记账（预留：搁置中，待调研后重启）
    case backTap            // 轻点背面（预留）
    case actionButton       // 操作按钮 / 辅助触控（预留）
    case repayment          // 还款自动生成（负债确认还款时写入；不计入消费统计）
}

/// 付款方式（2026-10-10 D18：记账 → 负债 的唯一联动入口）
///
/// 关键口径：**全额下期不需要建任何负债** —— 那笔钱已经通过 `Tx.accountID`
/// 扣减了信用账户余额，而「当期欠款 = max(|账户余额| − Σ分期剩余本金, 0)」
/// 会自动把它算进去。只有「分期」才需要在账户名下新建一条 `Liability`。
enum PayMethod: String, Codable {
    case normal             // 现金 / 储蓄卡 / 第三方余额：不产生负债
    case creditFull         // 信用支付，全额下期还（进当期欠款）
    case creditInstallment  // 信用支付，分期 N 期（自动建一笔分期并回链）
}

enum AccountKind: String, Codable {
    case cash, bankCard, wechat, alipay, creditCard
    // 2026-10-10（D14）：花呗 / 白条 / 其他信用，与信用卡同为「信用类」——
    // 用户心智里它们都是"每月要还多少钱的信用平台"，不再区分对待
    case huabei, baitiao, creditOther

    /// 品牌色 logo 块（视觉基准 v1.1 §4）
    var brandColorHex: UInt32 {
        switch self {
        case .cash: 0x3ABF58
        case .bankCard: 0xF59E0B
        case .wechat: 0x2AAE67
        case .alipay: 0x1677FF
        case .creditCard: 0x8E8E93
        case .huabei: 0x7F77DD
        case .baitiao: 0xE24B4A
        case .creditOther: 0x5F5E5A
        }
    }

    /// logo 块单字（原型 #assets：支/微/卡/信/花/白）
    var logoChar: String {
        switch self {
        case .cash: "现"; case .bankCard: "卡"; case .wechat: "微"
        case .alipay: "支"; case .creditCard: "信"
        case .huabei: "花"; case .baitiao: "白"; case .creditOther: "信"
        }
    }

    /// 建户默认名（B1：建户 <30 秒——选类型即填好）
    var defaultName: String {
        switch self {
        case .cash: "现金"; case .bankCard: "银行卡"; case .wechat: "微信支付"
        case .alipay: "支付宝"; case .creditCard: "信用卡"
        case .huabei: "花呗"; case .baitiao: "京东白条"; case .creditOther: "信用账户"
        }
    }

    /// 信用类：会累积欠款、有额度与账单日/还款日，负债即其"另一个视角"
    var isCredit: Bool {
        switch self {
        case .creditCard, .huabei, .baitiao, .creditOther: return true
        case .cash, .bankCard, .wechat, .alipay: return false
        }
    }

    /// 建户宫格顺序（含信用类）
    static let pickerOrder: [AccountKind] =
        [.cash, .bankCard, .wechat, .alipay, .creditCard, .huabei, .baitiao, .creditOther]

    /// 建户默认图标（2026-10-11：品牌类走真实 logo，通用类走 Fluent 3D）
    var defaultIcon: AccountIcon {
        switch self {
        case .cash: .cash
        case .bankCard: .bank
        case .wechat: .wechat
        case .alipay: .alipay
        case .creditCard: .card
        case .huabei: .huabei
        case .baitiao: .baitiao
        case .creditOther: .card
        }
    }
}

/// 账户图标
///
/// **两类来源**（2026-10-11 实测定案）：
/// ① 通用 = Microsoft Fluent Emoji 3D（`acct_*`）—— 语义类，无品牌归属
/// ② 品牌 = 真实品牌 logo（`logo_*`）—— 用户一眼认出是哪家银行/平台
///
/// ⭐ **所有图标入库前已做「内容 bbox 归一化」**：内容最大边统一到画布的 72%。
///    原因：素材天生留白不同（Fluent 的「卡片」只占画布高 56%，「购物」占 88%），
///    不归一化就会出现「有的很大有的很小」。归一化脚本 `reports/_build_brand_icons.py`。
///
/// ⚠️ 彩色贴图**不要加 `.renderingMode(.template)`**（会被染成单色）。
enum AccountIcon: String, CaseIterable, Codable, Identifiable {
    case none = ""

    // MARK: 通用（Fluent Emoji 3D）
    case cash = "acct_cash"
    case bank = "acct_bank"
    case card = "acct_card"
    case wallet = "acct_wallet"
    case phone = "acct_phone"
    case shop = "acct_shop"

    // MARK: 品牌 · 平台与钱包（原色 logo）
    case wechat = "logo_wechat"
    case alipay = "logo_alipay"
    case qq = "logo_qq"
    case taobao = "logo_taobao"
    case meituan = "logo_meituan"
    case xiaohongshu = "logo_xiaohongshu"
    case bilibili = "logo_bilibili"
    case kuaishou = "logo_kuaishou"

    // MARK: 品牌 · 银行（已去掉「汉字+字组」，只保留图形符号）
    case icbc = "logo_icbc"
    case cmbchina = "logo_cmbchina"
    case ccb = "logo_ccb"
    case boc = "logo_boc"
    case abchina = "logo_abchina"
    case psbc = "logo_psbc"
    case pingan = "logo_pingan"
    case citicbank = "logo_citicbank"

    // MARK: 品牌 · 信用（源库里没有，用品牌色合成，见文档待办）
    case huabei = "logo_huabei"
    case baitiao = "logo_baitiao"

    var id: String { rawValue }
    /// Asset Catalog 名
    var asset: String { rawValue }

    /// 是否品牌 logo（真实品牌 / 合成品牌色块）
    var isBrand: Bool { rawValue.hasPrefix("logo_") }

    var displayName: String {
        switch self {
        case .none: "无"
        case .cash: "现金"
        case .bank: "银行"
        case .card: "信用卡"
        case .wallet: "钱包"
        case .phone: "手机支付"
        case .shop: "购物平台"
        case .wechat: "微信支付"
        case .alipay: "支付宝"
        case .qq: "QQ钱包"
        case .taobao: "淘宝"
        case .meituan: "美团"
        case .xiaohongshu: "小红书"
        case .bilibili: "哔哩哔哩"
        case .kuaishou: "快手"
        case .icbc: "工商银行"
        case .cmbchina: "招商银行"
        case .ccb: "建设银行"
        case .boc: "中国银行"
        case .abchina: "农业银行"
        case .psbc: "邮储银行"
        case .pingan: "平安银行"
        case .citicbank: "中信银行"
        case .huabei: "花呗"
        case .baitiao: "京东白条"
        }
    }

    /// asset 缺失时的 emoji 兜底
    var emoji: String {
        switch self {
        case .none: ""
        case .cash: "💵"
        case .bank: "🏦"
        case .card: "💳"
        case .wallet: "💰"
        case .phone: "📱"
        case .shop: "🛍️"
        case .wechat: "💬"
        case .alipay: "🅰️"
        case .qq: "🐧"
        case .taobao: "🛒"
        case .meituan: "🍱"
        case .xiaohongshu: "📕"
        case .bilibili: "📺"
        case .kuaishou: "🎬"
        case .icbc, .cmbchina, .ccb, .boc, .abchina, .psbc, .pingan, .citicbank: "🏦"
        case .huabei, .baitiao: "💳"
        }
    }

    /// 通用图标（Fluent 3D）
    static let generalIcons: [AccountIcon] = [.cash, .bank, .card, .wallet, .phone, .shop]
    /// 品牌 · 平台与钱包
    static let platformIcons: [AccountIcon] =
        [.wechat, .alipay, .qq, .taobao, .meituan, .xiaohongshu, .bilibili, .kuaishou]
    /// 品牌 · 银行
    static let bankIcons: [AccountIcon] =
        [.icbc, .cmbchina, .ccb, .boc, .abchina, .psbc, .pingan, .citicbank]
    /// 品牌 · 信用（合成）
    static let creditIcons: [AccountIcon] = [.huabei, .baitiao]

    /// 选择器顺序（分组展示用）
    static let pickerOrder: [AccountIcon] =
        [.none] + generalIcons + platformIcons + bankIcons + creditIcons
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
    var payMethodRaw: String = PayMethod.normal.rawValue   // 付款方式
    var liabilityID: String?                               // 分期时关联的负债项 id

    init(amount: Decimal, type: TxType, categoryID: String, subID: String? = nil,
         note: String = "", mood: Mood? = nil, accountID: String? = nil,
         toAccountID: String? = nil, date: Date = .now, source: Source = .manual,
         payMethod: PayMethod = .normal, liabilityID: String? = nil) {
        self.amount = amount; self.type = type; self.categoryID = categoryID
        self.subID = subID; self.note = note; self.mood = mood
        self.accountID = accountID; self.toAccountID = toAccountID
        self.date = date; self.source = source
        self.payMethodRaw = payMethod.rawValue; self.liabilityID = liabilityID
    }

    var payMethod: PayMethod { PayMethod(rawValue: payMethodRaw) ?? .normal }
}

@Model
final class Account {
    var id: String               // Tx.accountID 引用此 id（改名不影响关联）
    var name: String
    var brand: String                // 品牌/备注小字（如"工资卡 · ··1234"）
    var initialBalance: Decimal      // 初始余额；展示余额 = initialBalance + Σ交易推导（BalanceEngine）
    var kind: AccountKind
    var billDay: Int?                // 信用账户账单日
    var dueDay: Int?                 // 信用账户还款日（2026-10-10 新增，D8：账单日/还款日分开）
    var creditLimit: Decimal?        // 仅信用卡；剩余额度 = creditLimit - |展示余额|

    // 2026-10-11 账户图标
    /// ⚠️ 历史遗留：曾是「卡面 id」。2026-10-11 资产页去卡片化后**不再读取**，
    ///    仅保留存储属性以避免 SwiftData schema 变更导致旧数据迁移问题。
    var cardFaceRaw: String = ""
    var iconRaw: String = ""         // 账户图标（acct_* 通用 / logo_* 品牌）；空 = 无
    var cardLast4: String = ""       // 卡号后四位（可选）
    var isSelectable: Bool = true    // 记账时可选择（关闭后不在记一笔的付款方式里出现）
    /// 创建时间 —— **资产页分组内排序依据**（用户 2026-10-11 定：按创建时间，不按信用/现金）
    var createdAt: Date = Date.now

    init(id: String = UUID().uuidString, name: String, brand: String = "",
         initialBalance: Decimal, kind: AccountKind,
         billDay: Int? = nil, dueDay: Int? = nil, creditLimit: Decimal? = nil,
         icon: AccountIcon? = nil,
         cardLast4: String = "", isSelectable: Bool = true,
         createdAt: Date = .now) {
        self.id = id; self.name = name; self.brand = brand
        self.initialBalance = initialBalance; self.kind = kind
        self.billDay = billDay; self.dueDay = dueDay; self.creditLimit = creditLimit
        self.iconRaw = (icon ?? kind.defaultIcon).rawValue
        self.cardLast4 = cardLast4
        self.isSelectable = isSelectable
        self.createdAt = createdAt
    }

    /// 已解析图标（rawValue 失效时退回「无」，由视图层再退到 emoji / 字块）
    var icon: AccountIcon { AccountIcon(rawValue: iconRaw) ?? .none }
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

    // MARK: - 分期新模型（2026-10-11：补录账单 —— 只抄「第 x/n 期 + 每期金额」）
    // 旧模型要求用户知道「本金 + 期数 + 费率」；实际用户手上只有账单，上面写的是
    // 「第 2/12 期 ¥120.03」。所以改为**直接存每期金额**，不再反推本金与费率。
    /// 每期金额 —— 直接抄账单。`> 0` 时优先于旧的「(本金 + 手续费) ÷ 期数」推导。
    var perPeriodAmount: Decimal = 0
    /// 首期金额 —— 仅当首期与其余期**不同**时填：
    /// 尾差（花呗 / 白条：余数计入首期）/ 手续费一次性收取（几十到几百，必须填）。
    /// `0` = 首期与其余期相同。
    var firstPeriodAmount: Decimal = 0

    /// 合计（本金 ＋ 手续费/利息）—— 2026-10-12 新增（方案 A）。
    ///
    /// 用途：**反解末期差额**。各平台「本金 ÷ 期数」除不尽时的余数落点不同：
    ///   · 花呗 / 京东白条 → 计入**首期**（由 `firstPeriodAmount` 直接录）
    ///   · 银行信用卡（招 / 建 / 农 / 汇丰…）→ 计入**最后一期**（本字段反解）
    /// 只需抄一个「合计」（花呗详情页直接叫「分期总额」；白条 = 本金 ＋ 服务费；
    /// 银行 = 分期金额 ＋ 分期利息），`DebtEngine.lastAmount` 就能把末期算准。
    /// `0` = 未填（末期与其余期相同）。
    var totalRepayAmount: Decimal = 0

    init(id: String = UUID().uuidString, name: String, kind: LiabilityKind,
         category: LiabilityCategory, principal: Decimal, totalPeriods: Int = 0,
         paidPeriods: Int = 0, feeMode: FeeMode = .none, feeValue: Decimal = 0,
         billDay: Int = 1, dueDay: Int = 25, startMonth: String = "",
         iconChar: String = "债", iconHex: UInt32 = 0x8E8E93,
         linkedAccountID: String? = nil, sortOrder: Int = 0,
         perPeriodAmount: Decimal = 0, firstPeriodAmount: Decimal = 0,
         totalRepayAmount: Decimal = 0) {
        self.id = id; self.name = name
        self.kindRaw = kind.rawValue; self.categoryRaw = category.rawValue
        self.principal = principal
        self.totalPeriods = totalPeriods; self.paidPeriods = paidPeriods
        self.feeModeRaw = feeMode.rawValue; self.feeValue = feeValue
        self.billDay = billDay; self.dueDay = dueDay
        self.startMonth = startMonth
        self.iconChar = iconChar; self.iconHex = iconHex
        self.linkedAccountID = linkedAccountID; self.sortOrder = sortOrder
        self.perPeriodAmount = perPeriodAmount; self.firstPeriodAmount = firstPeriodAmount
        self.totalRepayAmount = totalRepayAmount
    }

    var kind: LiabilityKind { LiabilityKind(rawValue: kindRaw) ?? .fixed }
    var category: LiabilityCategory { LiabilityCategory(rawValue: categoryRaw) ?? .credit }
    var feeMode: FeeMode { FeeMode(rawValue: feeModeRaw) ?? .none }
}

// MARK: - 固定支出 / 订阅（2026-10-10 新增，D17）
//
// 房租、会员这类「每月固定扣、永远不结束」的支出 —— 它**不是负债**，独立成模块。
// 不进"待还总额"、不会还完，但会扣掉本月可支配。

@Model
final class FixedExpense {
    var id: String
    var name: String            // 房租 / 视频会员
    var amount: Decimal         // 每月金额
    var dueDay: Int             // 每月扣款日（1-31）
    var emoji: String           // 图标
    var sortOrder: Int

    init(id: String = UUID().uuidString, name: String, amount: Decimal,
         dueDay: Int = 1, emoji: String = "🏠", sortOrder: Int = 0) {
        self.id = id; self.name = name; self.amount = amount
        self.dueDay = dueDay; self.emoji = emoji; self.sortOrder = sortOrder
    }
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

    /// 每期应还 —— 新模型**直接抄账单**（`perPeriodAmount`）；
    /// 旧数据（只有本金 + 费率）回退到「(本金 + 总手续费) ÷ 期数」。
    static func perPeriod(_ l: Liability) -> Decimal {
        guard l.kind == .installment, l.totalPeriods > 0 else { return l.principal }
        if l.perPeriodAmount > 0 { return l.perPeriodAmount }
        return (l.principal + totalFee(l)) / Decimal(l.totalPeriods)
    }

    // MARK: 尾差（2026-10-12：首期 / 末期两类例外）
    //
    // 各平台「本金 ÷ 期数」除不尽时，余数落点**不同**（已查官方条款）：
    //   · 花呗 / 京东白条 → 余数计入 **首期**
    //   · 银行信用卡（招 / 建 / 农 / 汇丰…）→ 余数计入 **最后一期**
    // 一次分期只有**一期**是例外，所以建模成三档：首期金额 / 每期金额 / 末期金额。
    // 末期**不单独录**，由 `totalRepayAmount`（合计，含手续费/利息）反解：
    //   末期 = 合计 − 首期 − (期数 − 2) × 每期
    //
    // 用三张真实账单验证过（2026-10-12）：
    //   白条 12期 9.75 + 首期9.83 + 合计117.08      → 末期 9.75  ✅
    //   花呗 12期 120.03 + 首期120.06 + 合计1440.39  → 末期 120.03 ✅
    //   招行 3期 33.33 +（首期不填）+ 合计100.00     → 末期 33.34  ✅

    /// 首期金额（未单独填 = 与每期相同）
    static func firstAmount(_ l: Liability) -> Decimal {
        guard l.kind == .installment, l.totalPeriods > 0 else { return l.principal }
        return l.firstPeriodAmount > 0 ? l.firstPeriodAmount : perPeriod(l)
    }

    /// 末期金额（未填合计 = 与每期相同）
    static func lastAmount(_ l: Liability) -> Decimal {
        guard l.kind == .installment, l.totalPeriods > 0 else { return l.principal }
        let n = l.totalPeriods
        guard n > 1 else { return firstAmount(l) }
        guard l.totalRepayAmount > 0 else { return perPeriod(l) }
        let derived = l.totalRepayAmount - firstAmount(l) - Decimal(n - 2) * perPeriod(l)
        return derived > 0 ? derived : perPeriod(l)   // 填错合计时兜底，不产生负数期
    }

    /// 第 k 期应还（1-based）—— **全 App 取「某一期金额」的唯一入口**
    static func amount(of l: Liability, period k: Int) -> Decimal {
        guard l.kind == .installment, l.totalPeriods > 0 else { return l.principal }
        if k <= 1 { return firstAmount(l) }
        if k >= l.totalPeriods { return lastAmount(l) }
        return perPeriod(l)
    }

    /// 已还完的分期在列表里仍要显示一个数 → 用「每期」；没还完 → 用**本期应还**
    static func displayDue(_ l: Liability) -> Decimal {
        remainingPeriods(l) > 0 ? dueThisMonth(l) : perPeriod(l)
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

    /// 剩余待还总额 = Σ **未偿还各期**的金额（首期 / 中间期 / 末期各不相同）
    static func remaining(_ l: Liability) -> Decimal {
        switch l.kind {
        case .installment:
            let n = l.totalPeriods
            guard n > 0 else { return l.principal }
            guard l.paidPeriods < n else { return 0 }
            var sum: Decimal = 0
            for k in (l.paidPeriods + 1)...n { sum += amount(of: l, period: k) }
            return sum
        case .currentBill, .fixed:
            return l.principal
        }
    }

    /// 剩余期数
    static func remainingPeriods(_ l: Liability) -> Int {
        guard l.kind == .installment else { return 0 }
        return max(l.totalPeriods - l.paidPeriods, 0)
    }

    /// 账单上的「第 x 期」= 已还期数 + 1（还完时期号封顶在 n）。
    /// ⚠️ 显示口径统一用它 —— 用户抄账单写「第 2/12 期」，内部存 `paidPeriods = 1`。
    static func currentPeriod(_ l: Liability) -> Int {
        guard l.kind == .installment, l.totalPeriods > 0 else { return 0 }
        return min(l.paidPeriods + 1, l.totalPeriods)
    }

    /// 本月应还 —— 分期 = **当前这一期**的金额（首期 / 中间期 / 末期各不同）
    static func dueThisMonth(_ l: Liability) -> Decimal {
        switch l.kind {
        case .installment:
            guard remainingPeriods(l) > 0 else { return 0 }
            return amount(of: l, period: currentPeriod(l))
        case .currentBill, .fixed:
            return l.principal
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

    // MARK: - 债有尽头（2026-10-11：`forecast` 落地的第一层）
    //
    // 产品故事「钱有去处，债有尽头」的**唯一引擎侧兑现点**。
    // 此前 `forecast` 写好了但没有任何视图调用（orphan）—— 缺的不是能力，是界面。

    /// 还剩几个月还完 —— 取**最后一笔**分期还完的月份。`0` = 已无未还完的分期。
    static func payoffMonths(_ liabilities: [Liability]) -> Int {
        liabilities.filter { $0.kind == .installment }
            .map { remainingPeriods($0) }
            .max() ?? 0
    }

    /// 预计还清日 —— `nil` = 没有未还完的分期（"债已经到头了"）
    static func payoffDate(_ liabilities: [Liability], from date: Date = .now) -> Date? {
        let m = payoffMonths(liabilities)
        guard m > 0 else { return nil }
        return Calendar.current.date(byAdding: .month, value: m, to: date)
    }

    /// 第 m 个月**月末**的剩余债务（`m = 0` 即本月末，即本月应还已扣除）。
    /// 用于「债有尽头」看板把「逐月递减到 0」画出来。
    static func remainingAfter(_ liabilities: [Liability], months m: Int) -> Decimal {
        liabilities.filter { $0.kind == .installment }
            .reduce(Decimal(0)) { acc, l in
                let n = l.totalPeriods
                guard n > 0 else { return acc }
                let paid = min(l.paidPeriods + m + 1, n)
                guard paid < n else { return acc }
                var sum: Decimal = 0
                for k in (paid + 1)...n { sum += amount(of: l, period: k) }
                return acc + sum
            }
    }

    /// 未来 N 个月每月可支配（预测感，对应 Excel《还款计划》表）
    /// 简化模型：每过一月，分期 `paidPeriods + 1`；还完后该月应还归零。
    /// ⚠️ **只预测 `.installment` 分期** —— 当期账单每月浮动、固定支出属另一模块，
    ///    两者都无法按月外推（旧实现按当前值"平推"，会让数字永远不降，已修正）。
    /// 每个月取的是**该月对应那一期**的金额，所以首期 / 末期的尾差会落在正确的月份。
    /// 返回 [(月偏移, 当月可支配, 当月应还)]
    static func forecast(takeHomePay: Decimal, liabilities: [Liability], months: Int = 12) -> [(Int, Decimal, Decimal)] {
        var out: [(Int, Decimal, Decimal)] = []
        for m in 0..<months {
            var due: Decimal = 0
            for l in liabilities where l.kind == .installment {
                let k = l.paidPeriods + m + 1
                if k <= l.totalPeriods { due += amount(of: l, period: k) }
            }
            out.append((m, takeHomePay - due, due))
        }
        return out
    }

    // MARK: - 账户级聚合（2026-10-10 v4：负债并入信用账户）
    //
    // 核心口径：负债 = 信用账户的"另一个视角"。
    //   |账户余额|        = 该账户总欠款（含未还完的分期本金）
    //   分期剩余本金       = Σ 各笔分期尚未偿还的**本金**部分
    //   当期欠款（未分期）  = max(|余额| − Σ分期剩余本金, 0)   ← 由记账派生，只读
    //   本月应还          = 当期欠款 + Σ各笔分期的每期金额
    // 用「本金」而非「本金+手续费」相减，避免手续费造成口径漂移。

    /// 一笔分期尚未偿还的**本金**（不含手续费/利息）。
    /// ⚠️ 口径纪律：账户余额（`|余额|`）里只有本金（记账金额），不含手续费，
    ///    所以这里必须按本金推算，否则「当期欠款 = |余额| − Σ分期未还本金」会漂。
    ///    （2026-10-12 一度改成含手续费的 `remaining`，会破坏 `BehaviorSelfTest` ②，
    ///     已回退 —— 手续费只在 `remaining` / `dueThisMonth` / `forecast` 里体现。）
    static func remainingPrincipal(_ l: Liability) -> Decimal {
        switch l.kind {
        case .installment:
            guard l.totalPeriods > 0 else { return l.principal }
            let left = Decimal(max(l.totalPeriods - l.paidPeriods, 0))
            return l.principal / Decimal(l.totalPeriods) * left
        case .currentBill, .fixed:
            return l.principal
        }
    }

    /// 挂在某账户下的全部还款计划
    static func bills(of accountID: String, liabilities: [Liability]) -> [Liability] {
        liabilities.filter { $0.linkedAccountID == accountID }
    }

    /// 某信用账户的「当期欠款」= 未分期部分（只读，由记账派生）
    static func currentBill(account: Account, liabilities: [Liability], txs: [Tx]) -> Decimal {
        let total = abs(BalanceEngine.displayBalance(of: account, txs: txs))
        let planned = bills(of: account.id, liabilities: liabilities)
            .filter { $0.kind == .installment }
            .reduce(Decimal(0)) { $0 + remainingPrincipal($1) }
        let raw = total - planned
        return raw > 0 ? raw : 0
    }

    /// 某信用账户下、本月要还的分期月供
    static func installmentDue(accountID: String, liabilities: [Liability]) -> Decimal {
        bills(of: accountID, liabilities: liabilities)
            .filter { $0.kind == .installment }
            .reduce(Decimal(0)) { $0 + dueThisMonth($1) }
    }

    /// 某信用账户本月应还 = 当期欠款 + 分期月供
    static func monthlyDue(account: Account, liabilities: [Liability], txs: [Tx]) -> Decimal {
        currentBill(account: account, liabilities: liabilities, txs: txs)
            + installmentDue(accountID: account.id, liabilities: liabilities)
    }

    /// 全部信用账户本月应还合计
    static func monthlyDueAll(accounts: [Account], liabilities: [Liability], txs: [Tx]) -> Decimal {
        accounts.filter { $0.kind.isCredit }
            .reduce(Decimal(0)) { $0 + monthlyDue(account: $1, liabilities: liabilities, txs: txs) }
    }

    /// 全部信用账户待还总额 = Σ|信用账户余额| + Σ未挂账户的分期剩余
    /// （已挂账户的分期本金已含在账户余额里，不重复计）
    static func totalRemainingAll(accounts: [Account], liabilities: [Liability], txs: [Tx]) -> Decimal {
        let accountIDs = Set(accounts.map(\.id))
        let balance = accounts.filter { $0.kind.isCredit }
            .reduce(Decimal(0)) { $0 + abs(BalanceEngine.displayBalance(of: $1, txs: txs)) }
        let orphan = liabilities.filter { l in
            guard let sid = l.linkedAccountID else { return true }
            return !accountIDs.contains(sid)
        }.reduce(Decimal(0)) { $0 + remaining($1) }
        return balance + orphan
    }

    /// 可支配 = 到手薪资 − Σ信用账户本月应还 − Σ固定支出
    static func disposable(takeHomePay: Decimal,
                           accounts: [Account],
                           liabilities: [Liability],
                           txs: [Tx],
                           fixedExpenses: [FixedExpense]) -> Decimal {
        let fixed = fixedExpenses.reduce(Decimal(0)) { $0 + $1.amount }
        return takeHomePay
            - monthlyDueAll(accounts: accounts, liabilities: liabilities, txs: txs)
            - fixed
    }
}

// MARK: - 记账 → 负债 联动（D18）

enum LiabilityLinker {
    /// 记账保存后按付款方式落地负债。
    /// - `.normal` / `.creditFull`：**不新建负债** —— 全额下期那笔已经通过
    ///   `Tx.accountID` 扣减了账户余额，会被 `DebtEngine.currentBill` 自动算进当期欠款
    /// - `.creditInstallment`：在该信用账户名下新建一笔分期，并回链 `tx.liabilityID`
    @discardableResult
    static func apply(tx: Tx, account: Account?, periods: Int, feeRate: Decimal,
                      context: ModelContext) -> Liability? {
        guard let account, account.kind.isCredit else { return nil }
        guard tx.payMethod == .creditInstallment, periods > 1, tx.amount > 0 else { return nil }
        let order = (try? context.fetchCount(FetchDescriptor<Liability>())) ?? 0
        let plan = Liability(
            name: tx.note.isEmpty ? "分期" : tx.note,
            kind: .installment, category: .credit,
            principal: tx.amount, totalPeriods: periods, paidPeriods: 0,
            feeMode: feeRate > 0 ? .totalRate : .none, feeValue: feeRate,
            billDay: 1, dueDay: 25, startMonth: "",
            iconChar: "分", iconHex: 0x8E8E93,
            linkedAccountID: account.id, sortOrder: order,
            totalRepayAmount: tx.amount * (1 + feeRate / 100))   // 合计 = 本金 ×(1 + 总费率)
        context.insert(plan)
        tx.liabilityID = plan.id
        return plan
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

    /// 资产负债表口径（存量）。**不含「可支配」** ——
    /// 可支配是月度流量（到手薪资 − 信用应还 − 固定支出），见 `DebtEngine.disposable(takeHomePay:accounts:liabilities:txs:fixedExpenses:)`；
    /// 旧版本这里有个 `disposable = net` 的字段，导致资产页把净资产当可支配显示，2026-10-11 已删除。
    /// 「借出/借入」也待有真实功能时再加（原先恒为 0，白占指标卡）。
    struct Totals {
        var totalAssets: Decimal      // Σ现金类余额
        var totalDebt: Decimal        // Σ|信用类余额|
        var net: Decimal              // 总资产 - 总负债
    }

    static func totals(accounts: [Account], txs: [Tx]) -> Totals {
        var assets: Decimal = 0, debt: Decimal = 0
        for acc in accounts {
            let bal = displayBalance(of: acc, txs: txs)
            if acc.kind.isCredit { debt += abs(bal) } else { assets += bal }
        }
        return Totals(totalAssets: assets, totalDebt: debt, net: assets - debt)
    }
}
