import Foundation

// MARK: - 自动记账 C1：账单解析（纯函数，Spec §2-C）
// 规则与校准记录见 docs/M3实施备忘-自动记账-v1.md §2；best-effort，真机样本到位后回填正则

struct PendingBill: Codable, Identifiable {
    var id = UUID().uuidString
    var channel: BillChannel
    var amountCents: Int
    var merchant: String
    var date: Date
    var suggestedCategoryID: String
    var suggestedSubID: String?
    var rawText: String
}

enum BillChannel: String, Codable {
    case wechat, alipay, bank

    var label: String {
        switch self {
        case .wechat: "微信支付"
        case .alipay: "支付宝"
        case .bank: "银行卡"
        }
    }

    var emoji: String {
        switch self {
        case .wechat: "💚"
        case .alipay: "💙"
        case .bank: "🏦"
        }
    }

    /// C3 白名单开关的 UserDefaults key
    var whitelistKey: String { "autoWhitelist.\(rawValue)" }

    var enabledByDefault: Bool { self != .bank }   // 银行类默认关，避免误入卡

    func isEnabled() -> Bool {
        // 未写入过时用默认值（object 不为 nil 则读 Bool）
        UserDefaults.standard.object(forKey: whitelistKey) as? Bool ?? enabledByDefault
    }

    /// 待确认卡默认挂的账户类型（按通道找同名 kind 账户）
    var preferredAccountKind: AccountKind {
        switch self {
        case .wechat: .wechat
        case .alipay: .alipay
        case .bank: .bankCard
        }
    }
}

enum BillParser {
    private static let payWords = ["支付成功", "付款成功", "交易成功", "已支付", "消费", "收款"]
    private static let marketingWords = ["优惠", "红包", "满减", "活动", "券", "领取", "抽奖"]

    /// 主入口：通知文本 → PendingBill；非支付/无法解析/白名单关闭 → nil（静默忽略，Spec C3）
    static func parse(_ raw: String, now: Date = .now) -> PendingBill? {
        let text = raw.replacingOccurrences(of: "\n", with: " ")
        guard let channel = detectChannel(text) else { return nil }
        guard looksLikePayment(text) else { return nil }
        guard let cents = parseAmountCents(text) else { return nil }
        let merchant = parseMerchant(text)
        let (catID, subID) = suggestCategory(text)
        return PendingBill(channel: channel, amountCents: cents, merchant: merchant,
                           date: now, suggestedCategoryID: catID, suggestedSubID: subID,
                           rawText: raw)
    }

    static func detectChannel(_ text: String) -> BillChannel? {
        if text.contains("微信支付") { return .wechat }
        if text.contains("支付宝") { return .alipay }
        if text.contains("银行") || text.contains("尾号") { return .bank }
        return nil
    }

    static func looksLikePayment(_ text: String) -> Bool {
        let isPay = payWords.contains { text.contains($0) }
        let isMarketing = marketingWords.contains { text.contains($0) }
        return isPay && !isMarketing
    }

    /// 金额（分）：正则 ¥xx.xx / 金额 xx.xx 兜底
    static func parseAmountCents(_ text: String) -> Int? {
        for pattern in [#"¥\s*([0-9,]+(?:\.[0-9]{1,2})?)"#,
                        #"金额\s*([0-9,]+(?:\.[0-9]{1,2})?)"#] {
            if let m = firstMatch(pattern, in: text) {
                let cleaned = m.replacingOccurrences(of: ",", with: "")
                if let v = Double(cleaned), v.isFinite, v > 0 {
                    return Int((v * 100).rounded())
                }
            }
        }
        return nil
    }

    /// 商家：收款方：… / 付款给… / 向…付款
    static func parseMerchant(_ text: String) -> String {
        for pattern in [#"收款方[:：]\s*([^ ,，。]{1,20})"#,
                        #"付款给\s*([^ ,，。]{1,20})"#,
                        #"向([^ ,，。]{1,20}?)付款"#] {
            if let m = firstMatch(pattern, in: text) {
                return m
            }
        }
        return ""
    }

    /// 分类联想：关键词 → (大类, 子类)；兜底「生活所需·吃饭」
    static func suggestCategory(_ text: String) -> (String, String?) {
        let table: [(String, String, String?)] = [
            ("咖啡", "flexible", "coffee"), ("瑞幸", "flexible", "coffee"), ("星巴克", "flexible", "coffee"),
            ("外卖", "needs", "meal"), ("美团", "needs", "meal"), ("饿了么", "needs", "meal"),
            ("肯德基", "needs", "meal"), ("麦当劳", "needs", "meal"), ("餐厅", "needs", "meal"),
            ("超市", "needs", "grocery"), ("便利", "needs", "grocery"), ("买菜", "needs", "grocery"),
            ("打车", "fixed", "commute"), ("滴滴", "fixed", "commute"), ("地铁", "fixed", "commute"),
            ("公交", "fixed", "commute"), ("出行", "fixed", "commute"), ("加油", "fixed", "commute"),
            ("话费", "fixed", "utility"), ("水电", "fixed", "utility"), ("燃气", "fixed", "utility"),
            ("房租", "fixed", "rent"),
            ("药", "needs", "medical"), ("医院", "needs", "medical"),
            ("电影", "flexible", "fun"), ("游戏", "flexible", "fun"), ("会员", "flexible", "fun"),
            ("酒店", "travel", "hotel"), ("机票", "travel", "transport"), ("火车", "travel", "transport"),
        ]
        for (keyword, cat, sub) in table where text.contains(keyword) {
            return (cat, sub)
        }
        return ("needs", "meal")
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, range: range),
              m.numberOfRanges > 1, Range(m.range(at: 1), in: text) != nil else { return nil }
        return String(text[Range(m.range(at: 1), in: text)!])
    }
}
