//
//  AddTransactionView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]

    @State private var amount: String = ""
    @State private var selectedCurrency = "CNY"
    @State private var fromAccountId: UUID?
    @State private var toAccountId: UUID?
    @State private var note: String = ""
    @State private var transactionDate = Date()
    @State private var showingDatePicker = false
    @FocusState private var amountFieldFocused: Bool

    @State private var showingFromPicker = false
    @State private var showingToPicker = false

    private let currencies = Currency.defaultCurrencies

    // 优化：使用计算属性但通过懒加载避免重复计算
    private var fromAccounts: [Account] {
        accounts.filter { account in
            account.type == .income || account.type == .asset || account.type == .liability
        }
    }

    private var toAccounts: [Account] {
        accounts.filter { account in
            account.type == .expense || account.type == .asset || account.type == .liability
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // 日期
                Section {
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        HStack {
                            Text("日期")
                                .frame(width: 80, alignment: .leading)
                            Spacer()
                            Text(formatDate(transactionDate))
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }

                // 金额输入
                Section {
                    HStack {
                        Text("币种")
                            .frame(width: 80, alignment: .leading)

                        Picker("", selection: $selectedCurrency) {
                            ForEach(currencies) { currency in
                                Text("\(currency.symbol) \(currency.code)").tag(currency.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text("金额")
                            .frame(width: 80, alignment: .leading)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($amountFieldFocused)
                    }
                }

                // 来源
                Section("来源（钱从哪里来？）") {
                    Button(action: {
                        showingFromPicker = true
                    }) {
                        HStack {
                            Text(getAccountName(fromAccountId, from: fromAccounts))
                                .foregroundColor(fromAccountId == nil ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }

                // 去向
                Section("去向（钱到哪里去？）") {
                    Button(action: {
                        showingToPicker = true
                    }) {
                        HStack {
                            Text(getAccountName(toAccountId, from: toAccounts))
                                .foregroundColor(toAccountId == nil ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }

                // 备注
                Section("备注") {
                    TextField("选填", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingFromPicker) {
                AccountPickerView(
                    selectedAccountId: $fromAccountId,
                    accounts: fromAccounts,
                    title: "选择来源账户",
                    availableTypes: [.income, .asset, .liability]
                )
            }
            .sheet(isPresented: $showingToPicker) {
                AccountPickerView(
                    selectedAccountId: $toAccountId,
                    accounts: toAccounts,
                    title: "选择去向账户",
                    availableTypes: [.expense, .asset, .liability]
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(selectedDate: $transactionDate)
            }
            .onAppear {
                // 延迟一小段时间后自动聚焦到金额输入框
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    amountFieldFocused = true
                }
            }
        }
    }

    private var isValid: Bool {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
        guard fromAccountId != nil, toAccountId != nil else { return false }
        guard fromAccountId != toAccountId else { return false }
        return true
    }

    private func getAccountName(_ accountId: UUID?, from accounts: [Account]) -> String {
        guard let accountId else { return "请选择" }
        return accounts.first { $0.id == accountId }?.name ?? "未知账户"
    }

    private func saveTransaction() {
        guard let amountValue = Decimal(string: amount),
              let fromId = fromAccountId,
              let toId = toAccountId else {
            return
        }

        let transaction = Transaction(
            amount: amountValue,
            fromAccountId: fromId,
            toAccountId: toId,
            currencyCode: selectedCurrency,
            note: note
        )

        // 设置交易日期
        transaction.createdAt = transactionDate
        transaction.updatedAt = transactionDate

        // 直接使用modelContext保存
        modelContext.insert(transaction)
        try? modelContext.save()

        // 更新账户余额
        updateAccountBalances(transaction)

        dismiss()
    }

    private func updateAccountBalances(_ transaction: Transaction) {
        // 获取账户并更新余额
        let fromAccount = accounts.first { $0.id == transaction.fromAccountId }
        let toAccount = accounts.first { $0.id == transaction.toAccountId }

        if let from = fromAccount {
            switch from.type {
            case .asset:
                // 资产账户：来源减少，余额减少
                from.updateBalance(-transaction.amount)
            case .liability:
                // 负债账户：来源表示负债减少，余额增加（向负变少）
                from.updateBalance(transaction.amount)
            case .income:
                // 收入账户：来源表示转出，余额减少
                from.updateBalance(-transaction.amount)
            case .expense:
                // 支出账户：来源表示转入，余额增加
                from.updateBalance(transaction.amount)
            }
        }

        if let to = toAccount {
            switch to.type {
            case .asset:
                // 资产账户：去向增加，余额增加
                to.updateBalance(transaction.amount)
            case .liability:
                // 负债账户：去向表示负债增加，余额减少（向负变大）
                to.updateBalance(-transaction.amount)
            case .income:
                // 收入账户：去向表示收入，余额增加
                to.updateBalance(transaction.amount)
            case .expense:
                // 支出账户：去向表示支出，余额增加
                to.updateBalance(transaction.amount)
            }
        }

        try? modelContext.save()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// 账户选择器
struct AccountPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedAccountId: UUID?
    let accounts: [Account]
    var title: String = "选择账户"
    let availableTypes: [AccountType]  // 可用的账户类型

    @State private var selectedFilterType: AccountType

    init(selectedAccountId: Binding<UUID?>, accounts: [Account], title: String = "选择账户", availableTypes: [AccountType]) {
        self._selectedAccountId = selectedAccountId
        self.accounts = accounts
        self.title = title
        self.availableTypes = availableTypes
        // 默认选中第一个类型
        self._selectedFilterType = State(initialValue: availableTypes.first ?? .asset)
    }

    /// 按类型和分类分组
    private var accountGroups: [AccountGroup] {
        // 先根据选中的类型过滤账户
        let filteredAccounts = accounts.filter { availableTypes.contains($0.type) && $0.type == selectedFilterType }

        var groups: [AccountGroup] = []

        // 按分类分组（使用category关系）
        let grouped = Dictionary(grouping: filteredAccounts) { account -> String in
            account.category?.name ?? "未分类"
        }

        // 排序并创建分组
        for (categoryName, accountsInGroup) in grouped.sorted(by: { $0.key < $1.key }) {
            groups.append(AccountGroup(
                type: selectedFilterType,
                displayName: categoryName,
                accounts: accountsInGroup.sorted { $0.name < $1.name }
            ))
        }

        return groups
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部分段切换器
                Picker("类型", selection: $selectedFilterType) {
                    ForEach(availableTypes, id: \.self) { type in
                        Text(type.description).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(uiColor: .systemBackground))

                Divider()

                // 账户列表
                ScrollView {
                    VStack(spacing: 20) {
                        if accountGroups.isEmpty {
                            // 空状态
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("暂无\(selectedFilterType.description)账户")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(accountGroups) { group in
                                sectionForGroup(group)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sectionForGroup(_ group: AccountGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分类标题
            Text(group.displayName)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            // 标签网格（一行3个）
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(group.accounts) { account in
                    accountTag(account)
                }
            }
        }
    }

    private func accountTag(_ account: Account) -> some View {
        Button(action: {
            selectedAccountId = account.id
            dismiss()
        }) {
            HStack {
                Text(account.name)
                    .font(.system(size: 14))
                    .foregroundColor(selectedAccountId == account.id ? .white : .primary)
                    .lineLimit(1)

                if selectedAccountId == account.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(selectedAccountId == account.id ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedAccountId == account.id ? Color.clear : Color(uiColor: .separator), lineWidth: 0.5)
            )
        }
    }
}

/// 账户分组
struct AccountGroup: Identifiable {
    let id = UUID()
    let type: AccountType
    let displayName: String
    let accounts: [Account]
}

/// 日期选择器视图
struct DatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                Section {
                    Button("今天") {
                        selectedDate = Date()
                    }
                    Button("昨天") {
                        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                            selectedDate = yesterday
                        }
                    }
                    Button("本周一") {
                        if let monday = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) {
                            selectedDate = monday
                        }
                    }
                }
            }
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddTransactionView()
}
