import SwiftUI

// MARK: - E5 分类管理 / A5 自定义二级子类（名称 + 图标）
// 预设子类只读；自定义子类可增删（M3 备忘 §4）
//
// 2026-10-15（D2 页面容器语言）：系统 `List` → **全自绘**（`ScrollView` + `VStack` + 白卡），
// 与其余业务页统一容器语言。已知取舍：失去系统 List 的分组吸顶 / 系统缩进，全部由 `CardSection` 承担。

struct CategoryManagerView: View {
    @State private var version = 0          // CustomSubStore 非 Observable，手动翻版本驱动刷新
    @State private var addTarget: CategoryDef?
    @State private var pendingRemove: (CategoryDef, CategoryDef.SubDef)?

    var body: some View {
        ScrollView {
            VStack(spacing: Radius.cardSpacing) {
                ForEach(CategoryPresets.all) { cat in
                    categorySection(cat)
                }
                CardFooterNote(text: "自定义子类保存在本机；删掉后已记账不受影响，只影响之后的分类选择。")
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
        .background(Theme.bg)
        .navigationTitle("分类管理")
        .id(version)
        .sheet(item: $addTarget) { cat in
            AddCustomSubSheet(category: cat) {
                version += 1
            }
            .presentationDetents([.fraction(0.68), .large])   // 2026-10-12：图标从 16 个扩到 135 个（9 组），半屏不够放
            .presentationDragIndicator(.hidden)
        }
        .alert("删除子类", isPresented: Binding(
            get: { pendingRemove != nil },
            set: { if !$0 { pendingRemove = nil } })) {
            Button("删除", role: .destructive) {
                if let (cat, sub) = pendingRemove {
                    CustomSubStore.remove(sub.id, from: cat.id)
                }
                pendingRemove = nil
                version += 1
            }
            Button("取消", role: .cancel) { pendingRemove = nil }
        } message: {
            if let (_, sub) = pendingRemove {
                Text("删除「\(sub.name)」？")
            }
        }
        .onAppear(perform: handleCIArg)
    }

    // MARK: 分组（一个大类 = 标题 + 白卡）

    private func categorySection(_ cat: CategoryDef) -> some View {
        let subs = cat.subs
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                CategoryIcon(cat, size: 20)
                Text(cat.name).scaledFont(.sm, weight: .semibold).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            CardSection {
                ForEach(subs.indices, id: \.self) { i in
                    subRow(cat, subs[i])
                    CardDivider()
                }
                addSubButton(cat)
            }
        }
    }

    // MARK: 行

    /// 子类行：自定义 → 可点删除；预设 → 只读「预设」标
    @ViewBuilder
    private func subRow(_ cat: CategoryDef, _ sub: CategoryDef.SubDef) -> some View {
        if CustomSubStore.isCustom(sub.id) {
            Button {
                Haptics.tap()
                pendingRemove = (cat, sub)
            } label: {
                rowContent(sub) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Theme.redText)
                        .accessibilityLabel("删除 \(sub.name)")
                }
            }
            .buttonStyle(.plain)
        } else {
            rowContent(sub) {
                Text("预设").scaledFont(.xs).foregroundStyle(.secondary)
            }
        }
    }

    private func rowContent<Trailing: View>(_ sub: CategoryDef.SubDef,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                CategoryIcon(sub, size: 22)
                Text(sub.name).scaledFont(.body)
            }
            .foregroundStyle(.primary)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func addSubButton(_ cat: CategoryDef) -> some View {
        Button {
            Haptics.tap()
            addTarget = cat
        } label: {
            HStack(spacing: 6) {
                // 加号是「控件符号」，按 D1 纪律保留 SF Symbol
                Image(systemName: "plus.circle.fill")
                Text("添加「\(cat.name)」子类").scaledFont(.body, weight: .semibold)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.greenText)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// CI 截图钩子：直接展开「添加子类」sheet 以拍新的图标选择器。
    /// ⚠️ 这是**嵌套 sheet**（本页本身也是 sheet），必须等外层先落位 → 延迟 0.7s。
    /// 按 `AGENTS.md` §4：钩子只读 `ProcessInfo.arguments`，不加存储属性。
    private func handleCIArg() {
        guard ProcessInfo.processInfo.arguments.contains("-ci-open-catman-add-sub"),
              let cat = CategoryPresets.all.first(where: { $0.id == "needs" }) else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            addTarget = cat
        }
    }
}

// MARK: - 新增自定义子类：Fluent 3D 图标 + 名称（2026-10-12 重做）
//
// 变更前：图标是 **16 个 iOS 系统 emoji 字符**（✨🍜☕️…），渲染走系统字体 ——
//         与 App 内其余 Fluent 3D 贴图同屏最刺眼，是「第三套图标语言」的主要来源。
// 变更后：图标是 curated **135 个 Fluent 3D**，按 9 个大类分组切换（`CuratedIcons`）。
//         素材与分组由 `reports/_build_cur_icons.py` 生成，勿手改 `CuratedIcons.swift`。

struct AddCustomSubSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: CategoryDef
    var onAdded: () -> Void = {}

    @State private var name = ""
    @State private var iconAsset = CuratedIcons.preferred.asset
    @State private var groupIndex = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    /// 父大类 → 默认展开的图标组（用户可自行切到别的组）
    private static let defaultGroup: [String: String] = [
        "fixed":    "住 · 家居",
        "needs":    "吃 · 餐饮",
        "flexible": "娱乐 · 玩乐",
        "growth":   "学习 · 办公",
        "travel":   "行 · 交通",
        "bigitem":  "数码 · 电子",
    ]

    private var groups: [CuratedIcons.Group] { CuratedIcons.groups }
    private var items: [CuratedIcons.Item] {
        groups.indices.contains(groupIndex) ? groups[groupIndex].items : []
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    titleRow
                    iconSection
                    nameSection
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.bottom, 8)
            }
            saveButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .onAppear(perform: applyDefaultGroup)
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            CategoryIcon(category, size: 24)
            Text("\(category.name) · 新子类")
                .scaledFont(.title, weight: .bold)
        }
        .padding(.top, 4)
    }

    // MARK: 图标（9 组切换 + 6 列网格）

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("图标").scaledFont(.sm).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                // 让用户明确知道自己选的是哪个（图标本身没文字）
                if let item = CuratedIcons.item(iconAsset) {
                    Text(item.name).scaledFont(.xs).foregroundStyle(.tertiary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(groups.indices, id: \.self) { i in
                        groupChip(i)
                    }
                }
                .padding(.vertical, 1)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items) { item in
                    iconCell(item)
                }
            }
        }
    }

    private func groupChip(_ i: Int) -> some View {
        let on = i == groupIndex
        return Button {
            Haptics.tap()
            groupIndex = i
        } label: {
            Text(groups[i].title)
                .scaledFont(.sm, weight: .semibold)
                .foregroundStyle(on ? Color.white : Color.secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(on ? Theme.green : Theme.iconBg)
                .corner(Radius.capsule)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func iconCell(_ item: CuratedIcons.Item) -> some View {
        let on = iconAsset == item.asset
        return Button {
            Haptics.tap()
            iconAsset = item.asset
        } label: {
            CategoryIcon(asset: item.asset, size: 26)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(on ? Theme.greenSoft : Theme.card,
                            in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .stroke(on ? Theme.green : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: 名称

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名称").scaledFont(.sm).foregroundStyle(.secondary)
            TextField("如：咖啡续命", text: $name)
                .scaledFont(.title)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1))
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("保存")
                .scaledFont(.title, weight: .bold)
                .foregroundStyle(name.isEmpty ? Theme.disabledText : .white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .green3D(enabled: !name.isEmpty, radius: Radius.medium)
        }
        .disabled(name.isEmpty)
        .accessibilityLabel("保存自定义子类")
        .padding(.horizontal, Radius.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func applyDefaultGroup() {
        guard let title = Self.defaultGroup[category.id],
              let i = groups.firstIndex(where: { $0.title == title }) else { return }
        groupIndex = i
    }

    private func save() {
        Haptics.success()
        let id = "custom-\(UUID().uuidString.prefix(8))"
        let item = CuratedIcons.item(iconAsset) ?? CuratedIcons.preferred
        // emoji 一并存下：asset 万一缺失时的兜底，也让数据可读
        CustomSubStore.add(.init(id: id, emoji: item.emoji, name: name, asset: item.asset),
                           to: category.id)
        onAdded()
        dismiss()
    }
}
