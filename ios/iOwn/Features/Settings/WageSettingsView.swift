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
    @AppStorage(WageKeys.workdays) private var workdaysCSV: String = "2,3,4,5,6"

    @State private var salaryText = ""

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
                        ForEach(1...28, id: \.self) { Text("每月 \($0) 日").tag($0) }
                    }
                } header: {
                    Text("收入")
                } footer: {
                    Text("发薪日暂用于账期划分（M2 资产联动时启用）")
                }

                Section("工作时段") {
                    Stepper(value: $startHour, in: 0...23) {
                        LabeledContent("上班", value: Money.hhmm(startHour, startMinute))
                    }
                    Stepper(value: $startMinute, in: 0...59) {
                        LabeledContent("上班分钟", value: "\(startMinute)")
                    }
                    Stepper(value: $endHour, in: 0...23) {
                        LabeledContent("下班", value: Money.hhmm(endHour, endMinute))
                    }
                    Stepper(value: $endMinute, in: 0...59) {
                        LabeledContent("下班分钟", value: "\(endMinute)")
                    }
                }

                Section("工作日") {
                    HStack(spacing: 6) {
                        ForEach(Self.weekdayOptions, id: \.value) { item in
                            Button {
                                toggle(item.value)
                            } label: {
                                Text(item.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(workdays.contains(item.value) ? Theme.green : Theme.iconBg)
                                    .foregroundStyle(workdays.contains(item.value) ? Color.white : Color.primary)
                                    .cornerRadius(Radius.small)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("时薪预览") {
                    LabeledContent("时薪", value: previewHourly)
                    LabeledContent("每日工时", value: String(format: "%.1f 小时", previewConfig.dailyHours))
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
