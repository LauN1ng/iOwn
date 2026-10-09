import SwiftUI

/// 工资计时器参数设置（E3）——月薪 / 发薪日 / 工作时段 / 工作日
/// 存 UserDefaults（WageConfig），首页顶卡与洞察页共用
struct WageSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(WageKeys.monthlySalary) private var monthlySalary: Double = 0
    @AppStorage(WageKeys.payday) private var payday: Int = 15
    @AppStorage(WageKeys.startHour) private var startHour: Int = 9
    @AppStorage(WageKeys.startMinute) private var startMinute: Int = 0
    @AppStorage(WageKeys.endHour) private var endHour: Int = 18
    @AppStorage(WageKeys.endMinute) private var endMinute: Int = 0
    @AppStorage(WageKeys.lunchStartHour) private var lunchStartHour: Int = 12
    @AppStorage(WageKeys.lunchStartMinute) private var lunchStartMinute: Int = 0
    @AppStorage(WageKeys.lunchMinutes) private var lunchMinutes: Int = 0
    @AppStorage(WageKeys.workdays) private var workdaysCSV: String = "2,3,4,5,6"

    @State private var salaryText = ""
    // 时间选择器用的 Date（与 AppStorage 的 时/分 双向同步）
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var lunchStartDate = Date()

    private var workdays: Set<Int> { WageConfig.parseWorkdays(workdaysCSV) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("月薪")
                        Spacer()
                        TextField("0", text: $salaryText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .frame(maxWidth: 140)
                            .onChange(of: salaryText) { _, newValue in
                                monthlySalary = Double(newValue.filter(\.isNumber)) ?? 0
                            }
                        Text("元").foregroundStyle(.secondary)
                    }
                    Picker("发薪日", selection: $payday) {
                        ForEach(1...31, id: \.self) { Text("每月 \($0) 日").tag($0) }
                    }
                } header: {
                    Text("收入")
                } footer: {
                    Text("部分月份没有 29–31 日时，按当月最后一天处理；发薪日暂用于账期划分（M2 资产联动时启用）")
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

                Section("工作日") {
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
                }

                Section("时薪预览") {
                    LabeledContent("时薪", value: previewHourly)
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
                salaryText = monthlySalary > 0 ? String(format: "%.0f", monthlySalary) : ""
                let c = Calendar.current
                startDate = c.date(bySettingHour: startHour, minute: startMinute, second: 0, of: .now) ?? .now
                endDate = c.date(bySettingHour: endHour, minute: endMinute, second: 0, of: .now) ?? .now
                lunchStartDate = c.date(bySettingHour: lunchStartHour, minute: lunchStartMinute, second: 0, of: .now) ?? .now
            }
        }
    }

    private var previewConfig: WageConfig {
        WageConfig.load()
    }

    private var previewHourly: String {
        let h = previewConfig.hourlyWage()
        return h > 0 ? "¥\(Money.compact(h))" : "—— 先填月薪"
    }

    private func toggle(_ weekday: Int) {
        var set = workdays
        if set.contains(weekday) { set.remove(weekday) } else { set.insert(weekday) }
        guard !set.isEmpty else { return }   // 至少保留一天
        workdaysCSV = set.sorted().map(String.init).joined(separator: ",")
    }

    /// 周一 → 周日（weekday: 1=周日）
    private static let weekdayOptions: [(label: String, value: Int)] = [
        ("一", 2), ("二", 3), ("三", 4), ("四", 5), ("五", 6), ("六", 7), ("日", 1),
    ]
}

#Preview { WageSettingsView() }
