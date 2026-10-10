import Foundation

// MARK: - 工资计时器参数（D1 / E3）——UserDefaults 持久化

enum WageKeys {
    /// 到手指薪（月，元）——v1.6：口径由「税前月薪」改为「到手薪资」，
    /// 不再计算五险一金/个税（不同地区/个税规则差异大，避免算不准；用户直接填到手值）
    static let takeHomePay   = "wage.monthlySalary"   // 复用旧 key，"月薪"→"到手薪资"改名不改存储位
    static let payday        = "wage.payday"          // Int 1-31（账期起点，M2 资产用）
    static let startHour     = "wage.startHour"       // Int 0-23
    static let startMinute   = "wage.startMinute"     // Int 0-59
    static let endHour       = "wage.endHour"
    static let endMinute     = "wage.endMinute"
    static let lunchStartHour  = "wage.lunchStartHour"   // 午休开始 Int 0-23
    static let lunchStartMinute = "wage.lunchStartMinute"
    static let lunchMinutes  = "wage.lunchMinutes"    // 午休时长（分钟），0 = 不扣
    static let workdays      = "wage.workdays"        // CSV，1=周日 … 7=周六，如 "2,3,4,5,6"
    /// 调休手动标记（CSV，yyyy-MM-dd）：用户强制这些日期上班（覆盖休息日规则 + 国家数据）
    static let makeupWorkdays = "wage.makeupWorkdays"
    /// 调休手动标记（CSV，yyyy-MM-dd）：用户强制这些日期放假（覆盖工作日规则 + 国家数据）
    static let extraOffDays   = "wage.extraOffDays"
}

struct WageConfig {
    var takeHomePay: Double                 // 到手薪资/月（元）
    var payday: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var lunchStartHour: Int
    var lunchStartMinute: Int
    var lunchMinutes: Int
    var workdays: Set<Int>
    /// 手动标记为「上班」的日期（yyyy-MM-dd）——公司不按国家调休时用
    var makeupWorkdays: Set<String>
    /// 手动标记为「放假」的日期（yyyy-MM-dd）
    var extraOffDays: Set<String>

    // MARK: 读写

    static func load(from defaults: UserDefaults = .standard) -> WageConfig {
        WageConfig(
            takeHomePay: defaults.double(forKey: WageKeys.takeHomePay),
            payday: defaults.object(forKey: WageKeys.payday) as? Int ?? 15,
            startHour: defaults.object(forKey: WageKeys.startHour) as? Int ?? 9,
            startMinute: defaults.object(forKey: WageKeys.startMinute) as? Int ?? 0,
            endHour: defaults.object(forKey: WageKeys.endHour) as? Int ?? 18,
            endMinute: defaults.object(forKey: WageKeys.endMinute) as? Int ?? 0,
            lunchStartHour: defaults.object(forKey: WageKeys.lunchStartHour) as? Int ?? 12,
            lunchStartMinute: defaults.object(forKey: WageKeys.lunchStartMinute) as? Int ?? 0,
            lunchMinutes: defaults.object(forKey: WageKeys.lunchMinutes) as? Int ?? 0,
            workdays: parseWorkdays(defaults.string(forKey: WageKeys.workdays)),
            makeupWorkdays: parseDateSet(defaults.string(forKey: WageKeys.makeupWorkdays)),
            extraOffDays: parseDateSet(defaults.string(forKey: WageKeys.extraOffDays))
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(takeHomePay, forKey: WageKeys.takeHomePay)
        defaults.set(payday, forKey: WageKeys.payday)
        defaults.set(startHour, forKey: WageKeys.startHour)
        defaults.set(startMinute, forKey: WageKeys.startMinute)
        defaults.set(endHour, forKey: WageKeys.endHour)
        defaults.set(endMinute, forKey: WageKeys.endMinute)
        defaults.set(lunchStartHour, forKey: WageKeys.lunchStartHour)
        defaults.set(lunchStartMinute, forKey: WageKeys.lunchStartMinute)
        defaults.set(lunchMinutes, forKey: WageKeys.lunchMinutes)
        defaults.set(workdays.sorted().map(String.init).joined(separator: ","), forKey: WageKeys.workdays)
        defaults.set(makeupWorkdays.sorted().joined(separator: ","), forKey: WageKeys.makeupWorkdays)
        defaults.set(extraOffDays.sorted().joined(separator: ","), forKey: WageKeys.extraOffDays)
    }

    static func parseWorkdays(_ raw: String?) -> Set<Int> {
        guard let raw, !raw.isEmpty else { return [2, 3, 4, 5, 6] }   // 默认周一~周五
        return Set(raw.split(separator: ",").compactMap { Int($0) })
    }

    static func parseDateSet(_ raw: String?) -> Set<String> {
        guard let raw, !raw.isEmpty else { return [] }
        return Set(raw.split(separator: ",").map(String.init))
    }

    /// 展示用 CSV（界面上直接改）
    var workdaysCSV: String { workdays.sorted().map(String.init).joined(separator: ",") }

    // MARK: 计算

    /// 每日工时（分钟）= 下班 - 上班 - 午休
    var dailyWorkMinutes: Int {
        max(0, (endHour * 60 + endMinute) - (startHour * 60 + startMinute) - lunchMinutes)
    }

    var dailyHours: Double { Double(dailyWorkMinutes) / 60 }

    var isConfigured: Bool {
        takeHomePay > 0 && dailyHours > 0 && !workdays.isEmpty
    }

    /// 当月的工作日总数（决定时薪分母）
    func workdaysInMonth(of date: Date, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return 0 }
        var count = 0
        var day = interval.start
        while day < interval.end {
            if isWorkday(day, calendar: calendar) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    /// 时薪 = 到手薪资 / （当月工作日数 × 每日工时）
    func hourlyWage(now: Date = .now, calendar: Calendar = .current) -> Double {
        let denom = Double(workdaysInMonth(of: now, calendar: calendar)) * dailyHours
        guard denom > 0 else { return 0 }
        return takeHomePay / denom
    }

    /// 本月已完成（含今天进行中）的工作秒数（已扣除午休）
    func workedSecondsThisMonth(now: Date = .now, calendar: Calendar = .current) -> Double {
        guard dailyHours > 0, let interval = calendar.dateInterval(of: .month, for: now) else { return 0 }
        let dailySeconds = dailyHours * 3600
        let today = calendar.startOfDay(for: now)
        var total: Double = 0
        var day = interval.start
        while day <= today {
            if isWorkday(day, calendar: calendar) {
                if day == today {
                    // 今天：只计工作时段内已经过去的秒数（时段外为 0），再扣掉已过去的午休
                    let start = calendar.date(byAdding: .minute,
                                              value: startHour * 60 + startMinute, to: day) ?? day
                    let end = calendar.date(byAdding: .minute,
                                            value: endHour * 60 + endMinute, to: day) ?? day
                    let cursor = min(max(now, start), end)
                    var elapsed = cursor.timeIntervalSince(start)
                    if lunchMinutes > 0 {
                        let lunchStart = calendar.date(byAdding: .minute,
                                                       value: lunchStartHour * 60 + lunchStartMinute, to: day) ?? day
                        let lunchEnd = lunchStart.addingTimeInterval(Double(lunchMinutes) * 60)
                        if cursor > lunchStart {
                            let overlap = min(cursor, lunchEnd).timeIntervalSince(lunchStart)
                            elapsed -= max(0, overlap)
                        }
                    }
                    total += max(0, elapsed)
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
            if isWorkday(day, calendar: calendar) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    // MARK: - 工作日判定（调休优先级：手动标记 > 国家数据 > 默认周规则）

    /// 供状态机/统计共用的「这一天算不算上班日」判定。
    /// 优先级：手动标记（最高）> HolidayStore 国家数据 > 默认 weekday 规则。
    func isWorkday(_ date: Date, calendar: Calendar = .current, holiday: HolidayStore = .shared) -> Bool {
        let key = Self.dateKey(date, calendar: calendar)
        if makeupWorkdays.contains(key) { return true }      // 手动补班
        if extraOffDays.contains(key) { return false }       // 手动放假
        if let off = holiday.isOffDay(key) { return !off }   // 国家数据有则以其为准
        return workdays.contains(calendar.component(.weekday, from: date))
    }

    /// yyyy-MM-dd（用固定 locale/时区，避免受系统区域影响）
    static func dateKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - 今日状态机（App 内卡片 + 未来小组件共用）

    /// 判断时间 → 今日状态（上班/午休/下班/休息/调休）
    func todayStatus(now: Date = .now, calendar: Calendar = .current, holiday: HolidayStore = .shared) -> WorkState {
        let key = Self.dateKey(now, calendar: calendar)
        let isManualMakeup = makeupWorkdays.contains(key)
        guard isWorkday(now, calendar: calendar, holiday: holiday) else {
            return .rest
        }
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        let lunchStart = lunchStartHour * 60 + lunchStartMinute
        let lunchEnd = lunchStart + lunchMinutes
        // 调休上班（手动补班，或国家数据标记为补班但落在默认休息日）记为「调休上班」
        let isMakeup = isManualMakeup || (!workdays.contains(calendar.component(.weekday, from: now)))

        if minutes < start { return isMakeup ? .makeupBefore : .beforeWork }
        if minutes >= end { return isMakeup ? .makeupAfter : .afterWork }
        if lunchMinutes > 0, minutes >= lunchStart, minutes < lunchEnd { return .lunch }
        return isMakeup ? .makeupWorking : .working
    }
}

/// 今日工作状态（卡片状态区 / 小组件共用）
enum WorkState {
    case beforeWork       // 未到上班（工作日）
    case working          // 工作中
    case lunch            // 午休中
    case afterWork        // 已下班
    case rest             // 休息日
    case makeupBefore     // 调休上班：未到
    case makeupWorking    // 调休上班：工作中
    case makeupAfter      // 调休上班：已下班

    /// 是否处于「视为上班日」（调休三态也算）
    var isWorkingDay: Bool {
        switch self {
        case .beforeWork, .working, .lunch, .afterWork, .makeupBefore, .makeupWorking, .makeupAfter: return true
        case .rest: return false
        }
    }

    /// 是否正在计时（工作中，含调休）
    var isTicking: Bool {
        self == .working || self == .makeupWorking
    }

    var isMakeup: Bool {
        switch self {
        case .makeupBefore, .makeupWorking, .makeupAfter: return true
        default: return false
        }
    }

    /// 状态胶囊文案
    var label: String {
        switch self {
        case .beforeWork, .makeupBefore: return "未上班"
        case .working, .makeupWorking:   return "工作中"
        case .lunch:                     return "午休中"
        case .afterWork, .makeupAfter:   return "已下班"
        case .rest:                      return "休息日"
        }
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
