import Foundation

// MARK: - 工资计时器参数（D1 / E3）——UserDefaults 持久化

enum WageKeys {
    static let monthlySalary = "wage.monthlySalary"   // Double，元
    static let payday        = "wage.payday"          // Int 1-28（账期起点，M2 资产用）
    static let startHour     = "wage.startHour"       // Int 0-23
    static let startMinute   = "wage.startMinute"     // Int 0-59
    static let endHour       = "wage.endHour"
    static let endMinute     = "wage.endMinute"
    static let workdays      = "wage.workdays"        // CSV，1=周日 … 7=周六，如 "2,3,4,5,6"
}

struct WageConfig {
    var monthlySalary: Double
    var payday: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var workdays: Set<Int>

    // MARK: 读写

    static func load(from defaults: UserDefaults = .standard) -> WageConfig {
        WageConfig(
            monthlySalary: defaults.double(forKey: WageKeys.monthlySalary),
            payday: defaults.object(forKey: WageKeys.payday) as? Int ?? 15,
            startHour: defaults.object(forKey: WageKeys.startHour) as? Int ?? 9,
            startMinute: defaults.object(forKey: WageKeys.startMinute) as? Int ?? 0,
            endHour: defaults.object(forKey: WageKeys.endHour) as? Int ?? 18,
            endMinute: defaults.object(forKey: WageKeys.endMinute) as? Int ?? 0,
            workdays: parseWorkdays(defaults.string(forKey: WageKeys.workdays))
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(monthlySalary, forKey: WageKeys.monthlySalary)
        defaults.set(payday, forKey: WageKeys.payday)
        defaults.set(startHour, forKey: WageKeys.startHour)
        defaults.set(startMinute, forKey: WageKeys.startMinute)
        defaults.set(endHour, forKey: WageKeys.endHour)
        defaults.set(endMinute, forKey: WageKeys.endMinute)
        defaults.set(workdays.sorted().map(String.init).joined(separator: ","), forKey: WageKeys.workdays)
    }

    static func parseWorkdays(_ raw: String?) -> Set<Int> {
        guard let raw, !raw.isEmpty else { return [2, 3, 4, 5, 6] }   // 默认周一~周五
        return Set(raw.split(separator: ",").compactMap { Int($0) })
    }

    /// 展示用 CSV（界面上直接改）
    var workdaysCSV: String { workdays.sorted().map(String.init).joined(separator: ",") }

    // MARK: 计算

    var dailyHours: Double {
        max(0, Double((endHour * 60 + endMinute) - (startHour * 60 + startMinute)) / 60)
    }

    var isConfigured: Bool {
        monthlySalary > 0 && dailyHours > 0 && !workdays.isEmpty
    }

    /// 当月的工作日总数（决定时薪分母）
    func workdaysInMonth(of date: Date, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }
        var count = 0
        var day = interval.start
        while day < interval.end {
            if workdays.contains(calendar.component(.weekday, from: day)) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    /// 时薪 = 月薪 / （当月工作日数 × 每日工时）
    func hourlyWage(now: Date = .now, calendar: Calendar = .current) -> Double {
        let denom = Double(workdaysInMonth(of: now, calendar: calendar)) * dailyHours
        guard denom > 0 else { return 0 }
        return monthlySalary / denom
    }

    /// 本月已完成（含今天进行中）的工作秒数
    func workedSecondsThisMonth(now: Date = .now, calendar: Calendar = .current) -> Double {
        guard dailyHours > 0, let interval = calendar.dateInterval(of: .month, for: now) else { return 0 }
        let dailySeconds = dailyHours * 3600
        let today = calendar.startOfDay(for: now)
        var total: Double = 0
        var day = interval.start
        while day <= today {
            if workdays.contains(calendar.component(.weekday, from: day)) {
                if day == today {
                    // 今天：只计工作时段内已经过去的秒数（时段外为 0）
                    let start = calendar.date(byAdding: .minute,
                                              value: startHour * 60 + startMinute, to: day) ?? day
                    let end = calendar.date(byAdding: .minute,
                                            value: endHour * 60 + endMinute, to: day) ?? day
                    let cursor = min(max(now, start), end)
                    total += cursor.timeIntervalSince(start)
                } else {
                    total += dailySeconds
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    /// 本月已赚（随时间自走）
    func earnedThisMonth(now: Date = .now, calendar: Calendar = .current) -> Double {
        workedSecondsThisMonth(now: now, calendar: calendar) / 3600 * hourlyWage(now: now, calendar: calendar)
    }

    /// 本月已走过的（部分）工作日数，用于副注
    func daysTouchedThisMonth(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return 0 }
        let today = calendar.startOfDay(for: now)
        var count = 0
        var day = interval.start
        while day <= today {
            if workdays.contains(calendar.component(.weekday, from: day)) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    /// 是否正在工作时段内（副注提示用）
    func isWorkingNow(now: Date = .now, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: now)
        guard workdays.contains(weekday) else { return false }
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return minutes >= startHour * 60 + startMinute && minutes < endHour * 60 + endMinute
    }
}

// MARK: - 金额格式化（千分位 + 两位小数）

enum Money {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        return f
    }()

    static func string(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// 时薪副注用：整数显示（<100 保留一位小数）
    static func compact(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    static func hhmm(_ hour: Int, _ minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
