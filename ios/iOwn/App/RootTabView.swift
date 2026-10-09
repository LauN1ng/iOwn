import SwiftUI
import SwiftData

/// 4 Tab 骨架：线索 / 洞察 / 资产 / 设置 + 绿 FAB（资产页琥珀 $ FAB → 建户）
/// 视觉对照物：site/prototype.html；Tab 规范见视觉基准 v1.1 §5
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection = 0
    @State private var showAdd = false
    @State private var showAddAccount = false      // M2：资产页 $ FAB → 建户
    @State private var savedInfo: SavedEntryInfo?
    @State private var showSuccess = false

    private let ciArgs = ProcessInfo.processInfo.arguments

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                HomeView().tabItem { Label("线索", systemImage: "list.bullet") }.tag(0)
                InsightView().tabItem { Label("洞察", systemImage: "chart.bar") }.tag(1)
                AssetsView().tabItem { Label("资产", systemImage: "creditcard") }.tag(2)
                SettingsView().tabItem { Label("设置", systemImage: "gearshape") }.tag(3)
            }
            .tint(Theme.green)

            // FAB：线索/洞察/设置 = 绿 +（记一笔）；资产页 = 琥珀 $（建户）
            Button {
                Haptics.tap()
                if selection == 2 {
                    showAddAccount = true
                } else {
                    showAdd = true
                }
            } label: {
                Image(systemName: selection == 2 ? "dollarsign" : "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(selection == 2 ? Theme.amber : Theme.green)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.92))
            // 切 Tab 时 FAB 换色/换图标：让颜色渐变而非硬切
            .animation(Motion.fade, value: selection)
            .padding(.trailing, 18)
            .padding(.bottom, 76)

            // 成功屏（A4）：覆盖全屏，1.9s 自动返回（CI 截图模式常驻）
            if showSuccess, let info = savedInfo {
                SuccessOverlay(info: info)
                    .transition(.opacity)
                    .task {
                        guard !ciArgs.contains("-ci-show-done") else { return }
                        try? await Task.sleep(nanoseconds: 1_900_000_000)
                        withAnimation(.easeOut(duration: 0.25)) { showSuccess = false }
                    }
            }
        }
        // 半屏 sheet（用户需求：记一笔不盖住主屏，保留背后主页上下文）
        // 0.68 = 阶段2（宫格滑走后）键盘+金额区完整放下的最小比例；可上拖全屏
        // ⚠️ 真机验证点：iOS 26 曾 detents 不生效（当时因此退回 fullScreenCover），iOS 27 待验
        .sheet(isPresented: $showAdd) {
            AddEntrySheet { info, showOverlay in
                guard showOverlay else { return }   // 再记：sheet 保持打开
                savedInfo = info
                showAdd = false
                withAnimation { showSuccess = true }
            }
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.hidden)   // 自绘 grabber 已有，隐藏系统把手防双条
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            seedDemoDataIfRequested()
            // CI 截图钩子：自动打开记一笔 / 直接展示成功屏 / 直达资产页
            if ciArgs.contains("-ci-tab-assets") {
                selection = 2
            }
            if ciArgs.contains("-ci-show-done") {
                savedInfo = SavedEntryInfo(
                    amount: 12, isOut: true, categoryName: "生活所需",
                    subName: "三餐", mood: .normal, todayCount: 1, streak: 1
                )
                showSuccess = true
            }
            if ciArgs.contains("-ci-open-sheet") {
                showAdd = true
            }
            // 金额页截图钩子：直接进 stage 1（验证金额两位小数 + 账户 chip）
            if ciArgs.contains("-ci-open-amount") {
                showAdd = true
            }
            // 建户半屏 sheet 截图钩子（资产页 + 自动展开 AddAccountSheet）
            if ciArgs.contains("-ci-open-account") {
                selection = 2
                showAddAccount = true
            }
        }
    }

    /// CI 截图钩子：launch argument "-ci-demo-data" 注入样例数据（仓库无真实数据）
    /// 放在 RootTabView（而非各页 onAppear）：直达任意 tab 的截图都能拿到完整样例
    private func seedDemoDataIfRequested() {
        guard ciArgs.contains("-ci-demo-data") else { return }
        // 工资计时器参数（仅首次未配置时注入样例）
        if UserDefaults.standard.double(forKey: WageKeys.monthlySalary) == 0 {
            WageConfig(monthlySalary: 8000, payday: 15, startHour: 9, startMinute: 0,
                       endHour: 18, endMinute: 0, lunchStartHour: 12, lunchStartMinute: 0,
                       lunchMinutes: 60, workdays: [2, 3, 4, 5, 6]).save()
        }
        let txCount = (try? modelContext.fetchCount(FetchDescriptor<Tx>())) ?? 0
        guard txCount == 0 else { return }
        let calendar = Calendar.current

        // M2-B3：样例账户（与原型 #assets 演示数字一致，便于截图比对）
        let accountCount = (try? modelContext.fetchCount(FetchDescriptor<Account>())) ?? 0
        if accountCount == 0 {
            let demoAccounts: [(String, String, Decimal, AccountKind, Int?, Decimal?)] = [
                ("支付宝", "默认 · 记账自动联动", 12368.20, .alipay, nil, nil),
                ("微信支付", "默认 · 记账自动联动", 3274.35, .wechat, nil, nil),
                ("招商银行", "工资卡 · ··1234", 24500.00, .bankCard, nil, nil),
                ("信用卡", "账单日 5 日", -1500.00, .creditCard, 5, 15000),
            ]
            for (name, brand, balance, kind, billDay, limit) in demoAccounts {
                modelContext.insert(Account(name: name, brand: brand, initialBalance: balance,
                                            kind: kind, billDay: billDay, creditLimit: limit))
            }
        }

        let samples: [(String, String, Int, Mood?, TimeInterval)] = [
            ("needs", "meal", 1200, .normal, -2 * 3600),
            ("flexible", "coffee", 990, .satisfied, -1 * 3600),
            ("fixed", "commute", 400, nil, -26 * 3600),
        ]
        for (catID, subID, cents, mood, offset) in samples {
            modelContext.insert(Tx(
                amount: Decimal(cents) / 100,
                type: .out,
                categoryID: catID,
                subID: subID,
                note: "",
                mood: mood,
                date: calendar.date(byAdding: .second, value: Int(offset), to: .now) ?? .now
            ))
        }
        try? modelContext.save()
    }
}

#Preview { RootTabView() }
