//
//  NewAccountManagementView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct NewAccountManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]

    @State private var selectedType: AccountTypeFilter = .asset
    @State private var showingAddAccount = false
    @State private var editingAccount: Account?
    @State private var accountToDelete: Account?
    @State private var showingDeleteAlert = false

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
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var groupedAccounts: [(AssetCategory?, [Account])] {
        // 对于收入和支出，不分组
        if selectedType == .income || selectedType == .expense {
            return [(nil, filteredAccounts)]
        }

        // 对于资产和负债，按分类分组并排序
        let grouped = Dictionary(grouping: filteredAccounts) { account -> AssetCategory? in
            return account.category
        }

        var result: [(AssetCategory?, [Account])] = []
        for (category, accounts) in grouped {
            let sortedAccounts = accounts.sorted { $0.orderIndex < $1.orderIndex }
            result.append((category, sortedAccounts))
        }

        // 简化排序逻辑
        return result.sorted { first, second in
            let firstValue = first.0?.rawValue ?? ""
            let secondValue = second.0?.rawValue ?? ""
            return firstValue < secondValue
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
                    ForEach(groupedAccounts, id: \.0?.rawValue) { (category, accounts) in
                        Section {
                            ForEach(accounts) { account in
                                NewAccountManagementRow(
                                    account: account,
                                    showIndent: category != nil,
                                    onEdit: {
                                        editingAccount = account
                                    },
                                    onDelete: {
                                        accountToDelete = account
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                                .onMove { source, destination in
                                    moveAccount(accounts: accounts, from: source, to: destination)
                                }
                                .deleteDisabled(false)
                        } header: {
                            if let category = category {
                                Text(category.description)
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
                NewAddAccountForm(selectedType: selectedType)
            }
            .sheet(item: $editingAccount) { account in
                EditAccountForm(account: account)
            }
            .alert("删除账户", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {
                    accountToDelete = nil
                }
                Button("删除", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                if let account = accountToDelete {
                    Text("确定要删除账户\"\(account.name)\"吗？删除后无法恢复。")
                }
            }
        }
    }

    private func moveAccount(accounts: [Account], from source: IndexSet, to destination: Int) {
        var sortedAccounts = accounts
        sortedAccounts.move(fromOffsets: source, toOffset: destination)

        // 更新orderIndex
        for (index, account) in sortedAccounts.enumerated() {
            account.orderIndex = index
        }

        try? modelContext.save()
    }

    private func deleteAccount() {
        guard let account = accountToDelete else { return }

        // 删除账户（包括系统账户）
        modelContext.delete(account)
        try? modelContext.save()

        accountToDelete = nil
    }
}

/// 新账户管理行
struct NewAccountManagementRow: View {
    let account: Account
    let showIndent: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

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

            // 信息（带缩进）
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
            .if(showIndent) { view in
                view.padding(.leading, 16)
            }

            Spacer()

            // 余额
            Text(account.formattedBalance)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)

            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}

/// 修改后的添加账户表单
struct NewAddAccountForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let selectedType: NewAccountManagementView.AccountTypeFilter

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
        switch selectedType {
        case .asset, .liability:
            return AssetCategory.allCases
        case .income, .expense:
            return []
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 分类选择（仅资产/负债显示）
                if selectedType == .asset || selectedType == .liability {
                    Section("账户分类") {
                        Picker("分类", selection: $selectedCategory) {
                            ForEach(availableCategories, id: \.self) { category in
                                Text(category.description).tag(category as AssetCategory?)
                            }
                        }
                        .pickerStyle(.menu)
                        .onAppear {
                            if selectedCategory == nil && !availableCategories.isEmpty {
                                selectedCategory = availableCategories.first
                            }
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
                    .disabled(name.isEmpty || !isValidCategory)
                }
            }
        }
    }

    private var isValidCategory: Bool {
        // 资产和负债必须有分类
        if (selectedType == .asset || selectedType == .liability) && selectedCategory == nil {
            return false
        }
        return true
    }

    private func saveAccount() {
        // 获取当前分类下的最大orderIndex
        let descriptor = FetchDescriptor<Account>()
        let existingAccounts = (try? modelContext.fetch(descriptor)) ?? []

        let maxOrderIndex: Int
        if let category = selectedCategory {
            let categoryAccounts = existingAccounts.filter { $0.categoryRawValue == category.rawValue }
            maxOrderIndex = categoryAccounts.map { $0.orderIndex }.max() ?? -1
        } else {
            let typeAccounts = existingAccounts.filter { $0.typeRawValue == selectedType.accountType.rawValue }
            maxOrderIndex = typeAccounts.map { $0.orderIndex }.max() ?? -1
        }

        let initialBalanceValue = Decimal(string: initialBalance) ?? 0

        let account = Account(
            name: name,
            type: selectedType.accountType,
            category: selectedCategory,
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
    NewAccountManagementView()
}
