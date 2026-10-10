import SwiftUI

/// 工资计时器参数设置（E3，v1.6 重构）——到手薪资 / 发薪日 / 工作时段 / 工作日 / 调休
/// 存 UserDefaults（WageConfig），首页顶卡与洞察页共用
///
/// v1.6：口径由「月薪」改为「到手薪资」（不含五险一金/个税计算）；新增「调休」手动标记节
struct WageSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(WageKeys.takeHomePay) private var takeHomePay: Double = 0
    @AppStorage(WageKeys.payday) private var payday: Int = 15
    @AppStorage(WageKeys.startHour) private var startHour: Int = 9
    @AppStorage(WageKeys.startMinute) private var startMinute: Int = 0
    @AppStorage(WageKeys.endHour) private var endHour: Int = 18
    @AppStorage(WageKeys.endMinute) private var endMinute: Int = 0
    @AppStorage(WageKeys.lunchStartHour) private var lunchStartHour: Int = 12
    @AppStorage(WageKeys.lunchStartMinute) private var lunchStartMinute: Int = 0
    @AppStorage(WageKeys.lunchMinutes) private var lunchMinutes: Int = 0
    @AppStorage(WageKeys.workdays) private var workdaysCSV: String = "2,3,4,5,6"
    @AppStorage(WageKeys.makeupWorkdays) private var makeupCSV: String = ""
    @AppStorage(WageKeys.extraOffDays) private var offCSV: String = ""

    @State private var salaryText = ""
    // 时间选择器用的 Date（与 AppStorage 的 时/分 双向同步）
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var lunchStartDate = Date()
    // 新增调休的日期草稿
    @State private var newDate = Date()
    // 节假日同步状态
    @State private var syncing = false
    @State private var syncResult: String?

    private var workdays: Set<Int> { WageConfig.parseWorkdays(workdaysCSV) }
    private var makeup: Set<String> { WageConfig.parseDateSet(makeupCSV) }
    private var extraOff: Set<String> { WageConfig.parseDateSet(offCSV) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                Section {
                    HStack {
                        Text("到手薪资")
                        Spacer()
                        TextField("0", text: $salaryText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(maxWidth: 140)
                            .onChange(of: salaryText) { _, newValue in
                                // 允许数字与一个小数点（最多两位小数）
                                let cleaned = Self.sanitizeAmount(newValue)
                                if cleaned != newValue { salaryText = cleaned }
                                takeHomePay = Double(cleaned) ?? 0
                            }
                        Text("元").foregroundStyle(.secondary)
                    }
                    Picker("发薪日", selection: $payday) {
                        ForEach(1...31, id: \.self) { Text("每月 \($0) 日").tag($0) }
                    }
                } header: {
                    Text("收入")
                } footer: {
                    Text("填每月实际到手的金额（已扣五险一金与个税后，可填小数如 6475.88）。本版不自动计算社保/个税，避免因各地政策差异算不准；发薪日用于账期划分（M2 资产联动时启用）")
                }

                Section("工作时段") {
                    DatePicker("上班", selection: $startDate, displayedComponents: .hourAndMinute)
                        .onChange(of: startDate) { _, newValue in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            startHour = c.hour ?? 9
                            startMinute = c.minute ?? 0
                        }
                    DatePicker("下班", selection: $endDate, displayedComponents: .hourAndMinute)
                        .onChange(of: endDate) { _, newValue in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            endHour = c.hour ?? 18
                            endMinute = c.minute ?? 0
                        }
                }

                Section {
                    DatePicker("午休开始", selection: $lunchStartDate, displayedComponents: .hourAndMinute)
                        .onChange(of: lunchStartDate) { _, newValue in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            lunchStartHour = c.hour ?? 12
                            lunchStartMinute = c.minute ?? 0
                        }
                    Stepper(value: $lunchMinutes, in: 0...180, step: 15) {
                        LabeledContent("午休时长", value: lunchMinutes == 0 ? "不扣除" : "\(lunchMinutes) 分钟")
                    }
                } header: {
                    Text("午休")
                } footer: {
                    Text("每日工时与已赚金额会自动扣除午休时间")
                }

                Section {
                    HStack(spacing: 6) {
                        ForEach(Self.weekdayOptions, id: \.value) { item in
                            Button {
                                Haptics.tap()
                                toggle(item.value)
                            } label: {
                                Text(item.label)
                                    .scaledFont(14, weight: .semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(workdays.contains(item.value) ? Theme.green : Theme.iconBg)
                                    .foregroundStyle(workdays.contains(item.value) ? Color.white : Color.primary)
                                    .cornerRadius(Radius.small)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.95))
                            .accessibilityLabel("周\(item.label)")
                            .accessibilityAddTraits(workdays.contains(item.value) ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("工作日")
                }

                // 调休（v1.6 新增）：公司不按国家调休时的兜底
                Section {
                    HStack {
                        DatePicker("选择日期", selection: $newDate, displayedComponents: .date)
                            .labelsHidden()
                        Spacer()
                        Button {
                            Haptics.tap()
                            makeupCSV = adding(newDate, to: makeupCSV)
                        } label: {
                            Label("补班", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        Button {
                            Haptics.tap()
                            offCSV = adding(newDate, to: offCSV)
                        } label: {
                            Label("放假", systemImage: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                    ForEach(makeup.sorted(), id: \.self) { key in
                        dayRow(key, badge: "补班", badgeColor: Theme.blue) { makeupCSV = removing(key, from: makeupCSV) }
                    }
                    ForEach(extraOff.sorted(), id: \.self) { key in
                        dayRow(key, badge: "放假", badgeColor: Theme.amber) { offCSV = removing(key, from: offCSV) }
                    }
                } header: {
                    Text("调休")
                } footer: {
                    Text("识别时间时会自动参考国家法定节假日与调休（来源 holiday-cn，启动时静默更新）。若你公司不按国家调休，可在此手动指定「补班」或「放假」，手动标记优先级最高")
                }

                Section {
                    Button {
                        Haptics.tap()
                        Task {
                            syncing = true
                            let ok = await HolidayStore.shared.fetch(year: Calendar.current.component(.year, from: .now))
                            syncResult = ok ? "已同步 \(Calendar.current.component(.year, from: .now)) 年节假日数据" : "同步失败，请检查网络后重试"
                            syncing = false
                        }
                    } label: {
                        HStack {
                            Label("同步节假日数据", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if syncing { ProgressView() }
                        }
                    }
                    if let msg = syncResult {
                        Text(msg)
                            .scaledFont(12)
                            .foregroundStyle(msg.hasPrefix("已同步") ? Theme.greenText : Theme.redText)
                    }
                    LabeledContent("本地数据", value: HolidayStore.shared.cachedYear == 0 ? "未同步" : "\(HolidayStore.shared.cachedYear) 年")
                } header: {
                    Text("节假日数据")
                }
                .id("holidaySection")

                Section("时薪预览") {
                    LabeledContent("到手时薪", value: previewHourly)
                    LabeledContent("每日工时", value: String(format: "%.1f 小时（已扣午休）", previewConfig.dailyHours))
                    LabeledContent("本月工作日", value: "\(previewConfig.workdaysInMonth(of: .now)) 天")
                }
            }
            .navigationTitle("工资计时器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                salaryText = takeHomePay > 0 ? Self.formatAmount(takeHomePay) : ""
                let c = Calendar.current
                startDate = c.date(bySettingHour: startHour, minute: startMinute, second: 0, of: .now) ?? .now
                endDate = c.date(bySettingHour: endHour, minute: endMinute, second: 0, of: .now) ?? .now
                lunchStartDate = c.date(bySettingHour: lunchStartHour, minute: lunchStartMinute, second: 0, of: .now) ?? .now
                // CI 截图钩子：滚到「节假日数据」节，便于核对调休同步结果
                if ProcessInfo.processInfo.arguments.contains("-ci-wage-bottom") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation { proxy.scrollTo("holidaySection", anchor: .center) }
                    }
                }
            }
            }
        }
    }

    // MARK: 子视图

    private func dayRow(_ key: String, badge: String, badgeColor: Color, onDelete: @escaping () -> Void) -> some View {
        HStack {
            Text(key)
                .scaledFont(15)
                .monospacedDigit()
            Text(badge)
                .scaledFont(11, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(badgeColor)
                .cornerRadius(999)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("删除 \(key) \(badge)")
        }
    }

    private var previewConfig: WageConfig { WageConfig.load() }

    private var previewHourly: String {
        let h = previewConfig.hourlyWage()
        return h > 0 ? "¥\(Money.compact(h))" : "—— 先填到手薪资"
    }

    // MARK: 操作

    private func toggle(_ weekday: Int) {
        var set = workdays
        if set.contains(weekday) { set.remove(weekday) } else { set.insert(weekday) }
        guard !set.isEmpty else { return }   // 至少保留一天
        workdaysCSV = set.sorted().map(String.init).joined(separator: ",")
    }

    /// 追加一个日期（返回新 CSV，避免对 @AppStorage 用 inout）
    private func adding(_ date: Date, to csv: String) -> String {
        var set = WageConfig.parseDateSet(csv)
        set.insert(WageConfig.dateKey(date))
        return set.sorted().joined(separator: ",")
    }

    /// 移除一个日期（返回新 CSV）
    private func removing(_ key: String, from csv: String) -> String {
        var set = WageConfig.parseDateSet(csv)
        set.remove(key)
        return set.sorted().joined(separator: ",")
    }

    /// 周一 → 周日（weekday: 1=周日）
    private static let weekdayOptions: [(label: String, value: Int)] = [
        ("一", 2), ("二", 3), ("三", 4), ("四", 5), ("五", 6), ("六", 7), ("日", 1),
    ]

    // MARK: 金额文本处理

    /// 清洗输入：只保留数字与一个小数点，小数最多两位
    static func sanitizeAmount(_ raw: String) -> String {
        var result = ""
        var hasDot = false
        var decimals = 0
        for ch in raw {
            if ch.isNumber {
                if hasDot {
                    if decimals >= 2 { continue }
                    decimals += 1
                }
                result.append(ch)
            } else if ch == ".", !hasDot {
                hasDot = true
                if result.isEmpty { result = "0" }   // ".5" → "0.5"
                result.append(".")
            }
        }
        return result
    }

    /// 展示：去掉无意义的小数（8000 → "8000"，6475.88 → "6475.88"）
    static func formatAmount(_ value: Double) -> String {
        if value == value.rounded() { return String(format: "%.0f", value) }
        return String(format: "%.2f", value)
    }
}

#Preview { WageSettingsView() }
