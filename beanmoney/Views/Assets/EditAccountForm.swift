//
//  EditAccountForm.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct EditAccountForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var account: Account

    @State private var selectedIconIndex = 0
    @State private var selectedCategory: AssetCategory?
    @State private var isSaving = false

    @Query private var categories: [AssetCategory]

    private let currencies = Currency.defaultCurrencies
    private let icons = [
        "folder", "banknote", "creditcard", "house", "car",
        "laptopcomputer", "gamecontroller", "airplane", "gift.fill",
        "heart.fill", "star.fill", "book.fill", "bag.fill",
        "cart.fill", "phone.fill", "tv.fill", "desktopcomputer",
        "bicycle", "tram.fill", "car.fill", "airplane",
        "chart.bar.fill", "chart.line.uptrend.xyaxis", "chart.pie.fill"
    ]

    var availableCategories: [AssetCategory] {
        categories.filter { $0.accountType == account.type }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 账户类型（不可修改）
                Section("账户类型") {
                    HStack {
                        Text("类型")
                            .frame(width: 80, alignment: .leading)
                        Text(account.type.description)
                            .foregroundColor(.secondary)
                    }
                }

                // 分组类型
                Section("分组类型") {
                    Picker("分组", selection: $selectedCategory) {
                        Text("未分类").tag(nil as AssetCategory?)
                        ForEach(availableCategories) { category in
                            Text(category.name).tag(category as AssetCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("账户信息") {
                    HStack {
                        Text("账户名称")
                            .frame(width: 80, alignment: .leading)
                        TextField("账户名称", text: $account.name)
                    }

                    HStack {
                        Text("币种")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $account.currencyCode) {
                            ForEach(currencies) { currency in
                                Text("\(currency.symbol) \(currency.code)").tag(currency.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("图标") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(Array(icons.enumerated()), id: \.offset) { index, iconName in
                            Button(action: {
                                selectedIconIndex = index
                                account.icon = iconName
                            }) {
                                Image(systemName: iconName)
                                    .font(.title2)
                                    .foregroundColor(account.icon == iconName && selectedIconIndex == index ? .white : .blue)
                                    .frame(width: 50, height: 50)
                                    .background(account.icon == iconName && selectedIconIndex == index ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("备注") {
                    TextField("选填", text: $account.note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中..." : "保存") {
                        saveAccount()
                    }
                    .disabled(isSaving)
                }
            }
            .disabled(isSaving)
            .onAppear {
                selectedCategory = account.category
                if let index = icons.firstIndex(of: account.icon) {
                    selectedIconIndex = index
                }
            }
        }
    }

    private func saveAccount() {
        isSaving = true

        // 更新账户分类
        account.category = selectedCategory

        do {
            try modelContext.save()
            dismiss()
        } catch {
            isSaving = false
            print("Error saving account: \(error.localizedDescription)")
        }
    }
}
