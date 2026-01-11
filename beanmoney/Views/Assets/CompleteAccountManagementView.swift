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
    }

    var groupedAccounts: [(AssetCategory, [Account])] {
        let grouped = Dictionary(grouping: filteredAccounts) { account in
            account.category ?? AssetCategory.income
        }

        let mapped = grouped.map { (category, accounts) in
            (category, accounts.sorted { $0.orderIndex < $1.orderIndex })
        }

        return mapped.sorted { (first, second) in
            first.0.rawValue < second.0.rawValue
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
                                    },
                                    onDelete: {
                                        accountToDelete = account
                                        showingDeleteAlert = true
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

    private func categoryHeader(_ category: AssetCategory) -> some View {
        HStack {
            Text(category.description)
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

    private func deleteAccount() {
        guard let account = accountToDelete else { return }

        // 删除账户（包括系统账户）
        modelContext.delete(account)
        try? modelContext.save()

        accountToDelete = nil
    }
}

/// 完整的账户管理行
struct CompleteAccountRow: View {
    let account: Account
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

/// 完整的添加账户表单
struct CompleteAddAccountForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let selectedType: CompleteAccountManagementView.AccountTypeFilter

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
        AssetCategory.allCases
    }

    var body: some View {
        NavigationStack {
            Form {
                // 分类选择
                Section("账户分类") {
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category.description).tag(category as AssetCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        if selectedCategory == nil && !availableCategories.isEmpty {
                            // 根据类型选择默认分类
                            switch selectedType {
                            case .income:
                                selectedCategory = .income
                            case .expense:
                                selectedCategory = .expense
                            case .asset:
                                selectedCategory = .current
                            case .liability:
                                selectedCategory = .credit
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
            $0.categoryRawValue == category.rawValue
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
