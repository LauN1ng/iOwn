import Foundation

/// 中国法定节假日/调休数据源（holiday-cn）
///
/// 设计要点（与工资卡重构备忘一致）：
/// - 数据源：开源项目 holiday-cn 的年度 JSON，结构 `{ year, days: [{date, name, isOffDay}] }`
/// - 拉取时机：App 启动时静默拉取当前年份（若本地已有且年份匹配则跳过），写入本地缓存
/// - 本地缓存：UserDefaults（字符串 JSON），离线可用，永不阻塞 UI
/// - 覆盖优先级（见 `WageConfig.isWorkday`）：用户手动标记 > 本数据 > 默认周规则
/// - 纯读取：`isOffDay(_ key: String) -> Bool?`（nil = 无数据，交由默认规则）
///
/// ⚠️ 为什么不用 EventKit 读系统日历：系统节假日日历是只读订阅日历，
///    事件只有标题，读不到「今天补班/放假」语义，且需日历权限（对一个记账 App 过重）。
///
/// 线程安全：读取路径（`isOffDay`）可能来自任意线程，写入只在异步 fetch 完成后，
/// 用 NSLock 保护 `offDayMap`，避免数据竞争。
final class HolidayStore: @unchecked Sendable {
    static let shared = HolidayStore()

    private let cacheKey = "holiday.cn.cache"      // UserDefaults key：缓存 JSON
    private let yearKey  = "holiday.cn.year"       // 缓存所属年份
    private let lock = NSLock()

    /// date(yyyy-MM-dd) → isOffDay。true = 放假，false = 补班（调休上班）
    private var _offDayMap: [String: Bool] = [:]
    private var _cachedYear: Int = 0

    private init() {
        loadCache()
    }

    // MARK: - 查询

    /// 返回该日是否为法定休息日；nil 表示无数据（调用方回退默认规则）
    func isOffDay(_ dateKey: String) -> Bool? {
        lock.lock(); defer { lock.unlock() }
        return _offDayMap[dateKey]
    }

    /// 该日期是否有 holiday-cn 数据（用于 UI 提示「已同步国家调休」）
    func hasData(for dateKey: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return _offDayMap[dateKey] != nil
    }

    /// 当前缓存的年份（0 = 无缓存）
    var cachedYear: Int {
        lock.lock(); defer { lock.unlock() }
        return _cachedYear
    }

    // MARK: - 缓存

    private func loadCache() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: cacheKey),
              let data = raw.data(using: .utf8),
              let parsed = Self.parse(data) else { return }
        lock.lock()
        _offDayMap = parsed.map
        _cachedYear = defaults.integer(forKey: yearKey)
        lock.unlock()
    }

    private func saveCache(_ map: [String: Bool], year: Int) {
        let json = Self.encode(map)
        UserDefaults.standard.set(json, forKey: cacheKey)
        UserDefaults.standard.set(year, forKey: yearKey)
        lock.lock()
        _offDayMap = map
        _cachedYear = year
        lock.unlock()
    }

    // MARK: - 拉取（启动静默调用）

    /// 静默同步：若本地已缓存目标年份则跳过；否则从 holiday-cn 拉取并缓存。
    /// 失败静默（不弹任何 UI，不影响主流程）。
    func syncIfNeeded(year: Int = Calendar.current.component(.year, from: .now)) async {
        guard cachedYear != year else { return }
        let ok = await fetch(year: year)
        // 诊断：记录最近一次同步结果（CI 可从 UserDefaults 读出核对）
        UserDefaults.standard.set(ok ? "ok" : "fail", forKey: "holiday.cn.lastSync")
    }

    /// 强制重新拉取（设置页「同步节假日」按钮用）
    ///
    /// ⚠️ 数据源可用性：`raw.githubusercontent.com` 在中国大陆网络常被拦截（实测 502），
    /// 故按顺序尝试多个镜像，任一成功即缓存；全部失败静默回退默认规则。
    @discardableResult
    func fetch(year: Int) async -> Bool {
        for url in Self.sourceURLs(year: year) {
            if let parsed = await fetchJSON(url) {
                saveCache(parsed.map, year: year)
                return true
            }
        }
        return false   // 静默失败：保留旧缓存 / 回退默认规则
    }

    /// 单个 URL 拉取 + 解析（失败返回 nil，不抛错）
    private func fetchJSON(_ url: URL) async -> Parsed? {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return Self.parse(data)
        } catch {
            return nil
        }
    }

    /// 多源候选（按可达性优先）：jsDelivr 国内可访问，raw 作为兜底
    static func sourceURLs(year: Int) -> [URL] {
        let raw = "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json"
        let candidates = [
            "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json",
            "https://fastly.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json",
            raw,
        ]
        return candidates.compactMap { URL(string: $0) }
    }

    // MARK: - 解析（纯函数，可测）

    struct Parsed {
        let map: [String: Bool]
    }

    /// 解析 holiday-cn JSON：`{ "days": [ { "date": "2026-01-01", "name": "元旦", "isOffDay": true } ] }`
    static func parse(_ data: Data) -> Parsed? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let days = obj["days"] as? [[String: Any]] else { return nil }
        var map: [String: Bool] = [:]
        for day in days {
            guard let date = day["date"] as? String,
                  let isOff = day["isOffDay"] as? Bool else { continue }
            map[date] = isOff
        }
        return Parsed(map: map)
    }

    static func encode(_ map: [String: Bool]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: map),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}
