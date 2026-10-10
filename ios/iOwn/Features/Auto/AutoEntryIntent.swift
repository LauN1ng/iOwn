import AppIntents
import Foundation

// MARK: - C2 四路触发统一入口（M3 备忘 §1）
// 通知自动化传通知文本 → 解析入队；背面轻点/操作按钮/辅助触控不传文本 → 弹记一笔。
// openAppWhenRun=true：Intent 与 App 同 target，直接拉起 App（无需扩展进程/App Group）。

struct AutoEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "自动记账"
    static var description = IntentDescription(
        "支付通知自动进 iOwn 待确认卡；不带文本时直接打开记一笔。"
    )
    static var openAppWhenRun = true

    @Parameter(title: "通知文本") var text: String?

    init() {}

    init(text: String?) {
        self.text = text
    }

    func perform() async throws -> some IntentResult {
        if let text, !text.isEmpty, let bill = BillParser.parse(text) {
            // 通道白名单（C3）：关闭则静默丢弃
            if bill.channel.isEnabled() {
                PendingBillStore.append(bill)
            }
        } else {
            // 无文本或解析失败但明确是手动触发 → 打开记一笔
            PendingBillStore.requestOpenAdd()
        }
        return .result()
    }
}
