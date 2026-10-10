import Foundation

// MARK: - A5 自定义二级子类存储（E5 分类管理的持久层）
// 存 UserDefaults：[catID: [SubDef]] JSON；预设不可删，自定义可增删（M3 备忘 §4）

enum CustomSubStore {
    private static let key = "customSubs"

    static func all() -> [String: [CategoryDef.SubDef]] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: [CategoryDef.SubDef]].self, from: data)) ?? [:]
    }

    static func subs(in categoryID: String) -> [CategoryDef.SubDef] {
        all()[categoryID] ?? []
    }

    static func add(_ sub: CategoryDef.SubDef, to categoryID: String) {
        var dict = all()
        dict[categoryID, default: []].append(sub)
        save(dict)
    }

    static func remove(_ subID: String, from categoryID: String) {
        var dict = all()
        dict[categoryID]?.removeAll { $0.id == subID }
        save(dict)
    }

    /// 子类 id 是否自定义（分类管理页区分"可删/不可删"）
    static func isCustom(_ subID: String) -> Bool {
        all().values.contains { $0.contains { $0.id == subID } }
    }

    private static func save(_ dict: [String: [CategoryDef.SubDef]]) {
        let data = (try? JSONEncoder().encode(dict)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }
}
