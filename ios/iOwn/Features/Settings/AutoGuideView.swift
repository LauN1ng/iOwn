import SwiftUI

// MARK: - E4 自动记账引导（Spec §2-C2/C3）：四路触发引导 + 白名单开关 + 全链路测试

extension Notification.Name {
    /// E4 测试：RootTabView 监听，立即消费队列弹待确认卡
    static let autoTestBill = Notification.Name("autoTestBill")
}

struct AutoGuideView: View {
    @State private var wechatOn = BillChannel.wechat.isEnabled()
    @State private var alipayOn = BillChannel.alipay.isEnabled()
    @State private var bankOn = BillChannel.bank.isEnabled()

    var body: some View {
        List {
            Section("① 主链路 · iOS 通知自动化") {
                guideText([
                    "1. 打开「快捷指令」App → 自动化 → 新建",
                    "2. 选「App 收到通知时」，App 选支付宝 / 微信",
                    "3. 添加操作 → 搜「自动记账」(iOwn)",
                    "4. 把「通知文本」传入参数，关闭「运行前询问」",
                    "5. 支付成功 → iOwn 弹出待确认卡，点「记下来」入账",
                ])
            }
            Section("② 轻点背面两下") {
                guideText([
                    "设置 → 辅助功能 → 触控 → 轻点背面",
                    "轻点两下 → 快捷指令 → 「自动记账」",
                    "不带文本 → 直接打开记一笔键盘",
                ])
            }
            Section("③ 操作按钮 / ④ 辅助触控") {
                guideText([
                    "操作按钮：设置 → 操作按钮 → 快捷指令 → 自动记账",
                    "辅助触控：设置 → 辅助功能 → 触控 → 辅助触控",
                    "自定顶层菜单 → 加「快捷指令」→ 自动记账",
                ])
            }

            // C3 白名单
            Section("监听白名单") {
                Toggle(isOn: $wechatOn) { Label("微信支付通知", systemImage: "bubble.left") }
                Toggle(isOn: $alipayOn) { Label("支付宝通知", systemImage: "banknote") }
                Toggle(isOn: $bankOn) { Label("银行类通知", systemImage: "building.columns") }
                Text("关闭的渠道会静默忽略；营销推送（优惠/红包/活动）不会入卡。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .onChange(of: wechatOn) { BillChannel.wechat.setEnabled($0) }
            .onChange(of: alipayOn) { BillChannel.alipay.setEnabled($0) }
            .onChange(of: bankOn) { BillChannel.bank.setEnabled($0) }

            Section {
                Button {
                    Haptics.tap()
                    runTest()
                } label: {
                    Label("测试全链路（模拟一条支付通知）", systemImage: "play.circle.fill")
                        .scaledFont(15, weight: .semibold)
                        .foregroundStyle(Theme.greenText)
                }
            } footer: {
                Text("等效于收到一条真实通知：解析 → 待确认卡 → 确认入账。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(Theme.card)
        .listRowSeparatorTint(Theme.hairline)
        .background(Theme.bg)
        .navigationTitle("自动记账")
    }

    private func guideText(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line).scaledFont(13).foregroundStyle(.primary)
            }
        }
    }

    /// E4 测试：模拟真实通知文本走全链路（解析 → 队列 → 待确认卡）
    private func runTest() {
        let sample = "微信支付\n付款成功\n¥21.90\n收款方：瑞幸咖啡"
        if let bill = BillParser.parse(sample) {
            PendingBillStore.append(bill)
            NotificationCenter.default.post(name: .autoTestBill, object: nil)
        }
    }
}

extension BillChannel {
    fileprivate func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: whitelistKey)
    }
}
