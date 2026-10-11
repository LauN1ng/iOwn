import SwiftUI

// MARK: - E5 分类管理 / A5 自定义二级子类（名称+emoji）
// 预设子类只读；自定义子类可增删（M3 备忘 §4）

struct CategoryManagerView: View {
    @State private var version = 0          // CustomSubStore 非 Observable，手动翻版本驱动刷新
    @State private var addTarget: CategoryDef?
    @State private var pendingRemove: (CategoryDef, CategoryDef.SubDef)?

    var body: some View {
        List {
            ForEach(CategoryPresets.all) { cat in
                Section {
                    ForEach(cat.subs) { sub in
                        subRow(cat, sub)
                    }
                    Button {
                        Haptics.tap()
                        addTarget = cat
                    } label: {
                        Label("添加「\(cat.name)」子类", systemImage: "plus.circle.fill")
                            .scaledFont(15, weight: .semibold)
                            .foregroundStyle(Theme.greenText)
                    }
                } header: {
                    HStack(spacing: 6) {
                        CategoryIcon(cat, size: 20)
                        Text(cat.name)
                    }
                }
            }
            Section {
                Text("自定义子类保存在本机；删掉后已记账不受影响，只影响之后的分类选择。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(Theme.card)
        .listRowSeparatorTint(Theme.hairline)
        .background(Theme.bg)
        .navigationTitle("分类管理")
        .id(version)
        .sheet(item: $addTarget) { cat in
            AddCustomSubSheet(category: cat) {
                version += 1
            }
            .presentationDetents([.fraction(0.55)])
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
    }

    @ViewBuilder
    private func subRow(_ cat: CategoryDef, _ sub: CategoryDef.SubDef) -> some View {
        if CustomSubStore.isCustom(sub.id) {
            Button {
                Haptics.tap()
                pendingRemove = (cat, sub)
            } label: {
                HStack {
                    HStack(spacing: 8) {
                        CategoryIcon(sub, size: 22)
                        Text(sub.name).scaledFont(15)
                    }
                    .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Theme.redText)
                        .accessibilityLabel("删除 \(sub.name)")
                }
            }
        } else {
            HStack {
                HStack(spacing: 8) {
                    CategoryIcon(sub, size: 22)
                    Text(sub.name).scaledFont(15)
                }
                Spacer()
                Text("预设").scaledFont(11).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 新增自定义子类：emoji + 名称

struct AddCustomSubSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: CategoryDef
    var onAdded: () -> Void = {}

    @State private var emoji = "✨"
    @State private var name = ""

    private let emojiOptions = ["✨", "🍜", "☕️", "🧋", "🛒", "🚕", "🏠", "💡", "💊", "📚", "🎮", "🎬", "🎁", "🐶", "💇", "🧾"]

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    CategoryIcon(category, size: 24)
                    Text("\(category.name) · 新子类")
                        .scaledFont(17, weight: .bold)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("图标").scaledFont(12).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                        ForEach(emojiOptions, id: \.self) { e in
                            Button {
                                Haptics.tap()
                                emoji = e
                            } label: {
                                Text(e).scaledFont(20)
                                    .frame(width: 38, height: 38)
                                    .background(emoji == e ? Theme.green : Theme.iconBg,
                                                in: RoundedRectangle(cornerRadius: Radius.small))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("名称").scaledFont(12).foregroundStyle(.secondary)
                    TextField("如：咖啡续命", text: $name)
                        .scaledFont(16)
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Radius.small))
                        .overlay(RoundedRectangle(cornerRadius: Radius.small)
                            .stroke(Theme.hairline, lineWidth: 1))
                }

                Spacer()

                Button {
                    save()
                } label: {
                    Text("保存")
                        .scaledFont(16, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(name.isEmpty ? Theme.disabled : Theme.green,
                                    in: RoundedRectangle(cornerRadius: Radius.medium))
                }
                .foregroundStyle(name.isEmpty ? Theme.disabledText : .white)
                .disabled(name.isEmpty)
                .accessibilityLabel("保存自定义子类")
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    private func save() {
        Haptics.success()
        let id = "custom-\(UUID().uuidString.prefix(8))"
        CustomSubStore.add(.init(id: id, emoji: emoji, name: name), to: category.id)
        onAdded()
        dismiss()
    }
}
