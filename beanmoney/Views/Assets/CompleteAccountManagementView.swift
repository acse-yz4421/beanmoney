//
//  CompleteAccountManagementView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct CompleteAccountManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    @Query private var categories: [AssetCategory]

    @State private var selectedType: AccountTypeFilter = .asset
    @State private var showingAddAccount = false
    @State private var editingAccount: Account?

    enum AccountTypeFilter: String, CaseIterable {
        case income = "收入"
        case expense = "支出"
        case asset = "资产"
        case liability = "负债"

        var accountType: AccountType {
            switch self {
            case .income: return .income
            case .expense: return .expense
            case .asset: return .asset
            case .liability: return .liability
            }
        }
    }

    var filteredAccounts: [Account] {
        accounts.filter { $0.type == selectedType.accountType }
    }

    var groupedAccounts: [(AssetCategory, [Account])] {
        // 先过滤出有分类的账户
        let accountsWithCategories = filteredAccounts.filter { $0.category != nil }

        // 按分类分组
        let grouped = Dictionary(grouping: accountsWithCategories) { account -> AssetCategory in
            account.category!
        }

        // 转换为数组并排序
        let mapped = grouped.map { (category, accounts) in
            (category, accounts.sorted { $0.orderIndex < $1.orderIndex })
        }

        return mapped.sorted { (first, second) in
            first.0.name < second.0.name
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类切换器
                Picker("账户类型", selection: $selectedType) {
                    ForEach(AccountTypeFilter.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // 账户列表
                List {
                    ForEach(groupedAccounts, id: \.0) { (category, accounts) in
                        Section(header: categoryHeader(category)) {
                            ForEach(accounts) { account in
                                CompleteAccountRow(
                                    account: account,
                                    onEdit: {
                                        editingAccount = account
                                    }
                                )
                            }
                            .onMove { source, destination in
                                moveAccountsInSection(accounts, from: source, to: destination)
                            }
                        }
                    }
                }
            }
            .navigationTitle("账户管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        showingAddAccount = true
                    }) {
                        Text("添加")
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                CompleteAddAccountForm(selectedType: selectedType)
            }
            .sheet(item: $editingAccount) { account in
                EditAccountForm(account: account)
            }
        }
    }

    private func categoryHeader(_ category: AssetCategory) -> some View {
        HStack {
            Text(category.name)
                .font(.headline)
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }

    private func moveAccountsInSection(_ accounts: [Account], from source: IndexSet, to destination: Int) {
        var sortedAccounts = accounts
        sortedAccounts.move(fromOffsets: source, toOffset: destination)

        for (index, account) in sortedAccounts.enumerated() {
            account.orderIndex = index
        }

        try? modelContext.save()
    }
}

/// 完整的账户管理行
struct CompleteAccountRow: View {
    let account: Account
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 排序手柄
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .frame(width: 20)

            // 图标
            Image(systemName: account.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)

                if !account.note.isEmpty {
                    Text(account.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 余额
            Text(account.formattedBalance)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            // 箭头图标
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

/// 完整的添加账户表单
struct CompleteAddAccountForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let selectedType: CompleteAccountManagementView.AccountTypeFilter

    @Query private var categories: [AssetCategory]

    @State private var name = ""
    @State private var icon = "folder"
    @State private var note = ""
    @State private var currencyCode = "CNY"
    @State private var initialBalance: String = "0"
    @State private var selectedIconIndex = 0
    @State private var selectedCategory: AssetCategory?

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
        categories.filter { $0.accountType == selectedType.accountType }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 分类选择
                Section("账户分类") {
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(availableCategories) { category in
                            Text(category.name).tag(category as AssetCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        if selectedCategory == nil && !availableCategories.isEmpty {
                            selectedCategory = availableCategories.first
                        }
                    }
                }

                // 基本信息
                Section("账户信息") {
                    HStack {
                        Text("账户名称")
                            .frame(width: 80, alignment: .leading)
                        TextField("例如：招商银行", text: $name)
                    }

                    HStack {
                        Text("币种")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $currencyCode) {
                            ForEach(currencies) { currency in
                                Text("\(currency.symbol) \(currency.code)").tag(currency.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // 图标选择
                Section("图标") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(Array(icons.enumerated()), id: \.offset) { index, iconName in
                            Button(action: {
                                selectedIconIndex = index
                                icon = iconName
                            }) {
                                Image(systemName: iconName)
                                    .font(.title2)
                                    .foregroundColor(selectedIconIndex == index ? .white : .blue)
                                    .frame(width: 50, height: 50)
                                    .background(selectedIconIndex == index ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 初始余额
                Section("初始余额") {
                    HStack {
                        Text("金额")
                            .frame(width: 80, alignment: .leading)
                        TextField("0.00", text: $initialBalance)
                            .keyboardType(.decimalPad)
                    }
                }

                // 备注
                Section("备注") {
                    TextField("选填", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveAccount()
                    }
                    .disabled(name.isEmpty || selectedCategory == nil)
                }
            }
        }
    }

    private func saveAccount() {
        guard let category = selectedCategory else { return }

        // 获取当前分类下的最大orderIndex
        let descriptor = FetchDescriptor<Account>()
        let existingAccounts = (try? modelContext.fetch(descriptor)) ?? []
        let categoryAccounts = existingAccounts.filter {
            $0.category?.id == category.id
        }
        let maxOrderIndex = categoryAccounts.map { $0.orderIndex }.max() ?? -1

        let initialBalanceValue = Decimal(string: initialBalance) ?? 0

        let account = Account(
            name: name,
            type: selectedType.accountType,
            category: category,
            balance: initialBalanceValue,
            initialBalance: initialBalanceValue,
            currencyCode: currencyCode,
            icon: icon,
            note: note,
            orderIndex: maxOrderIndex + 1
        )

        modelContext.insert(account)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    CompleteAccountManagementView()
}
