//
//  TransactionDetailView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var accounts: [Account] = []

    var body: some View {
        NavigationStack {
            Form {
                // 金额和币种
                Section("金额") {
                    HStack {
                        Text("金额")
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text(transaction.formattedAmount)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(transactionTypeColor)
                    }

                    HStack {
                        Text("币种")
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text(transaction.currencyCode)
                            .foregroundColor(.secondary)
                    }
                }

                // 账户信息
                Section("交易流向") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 来源
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("来源")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let fromAccount = transaction.getFromAccount(context: modelContext) {
                                    HStack {
                                        Image(systemName: fromAccount.icon)
                                            .foregroundColor(.blue)
                                        Text(fromAccount.name)
                                            .foregroundColor(.primary)
                                    }
                                    .font(.subheadline)
                                }
                            }
                            Spacer()
                            Text(getAccountType(fromAccount))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }

                        Divider()

                        // 去向
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("去向")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let toAccount = transaction.getToAccount(context: modelContext) {
                                    HStack {
                                        Image(systemName: toAccount.icon)
                                            .foregroundColor(.green)
                                        Text(toAccount.name)
                                            .foregroundColor(.primary)
                                    }
                                    .font(.subheadline)
                                }
                            }
                            Spacer()
                            Text(getAccountType(toAccount))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 时间信息
                Section("时间") {
                    HStack {
                        Text("创建时间")
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        Text(formatDateTime(transaction.createdAt))
                            .foregroundColor(.secondary)
                    }
                }

                // 备注
                Section("备注") {
                    if transaction.note.isEmpty {
                        Text("无备注")
                            .foregroundColor(.secondary)
                    } else {
                        Text(transaction.note)
                            .foregroundColor(.primary)
                    }
                }

                // 操作按钮
                Section {
                    Button(action: {
                        showingEdit = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("编辑交易")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.blue)
                    }
                }

                Section {
                    Button(role: .destructive, action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除交易")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("交易详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                EditTransactionView(transaction: transaction)
            }
            .alert("删除交易", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteTransaction()
                }
            } message: {
                Text("删除此交易记录将回滚相关账户的余额，确定要删除吗？")
            }
            .onAppear {
                loadAccounts()
            }
        }
    }

    private func loadAccounts() {
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.orderIndex)])
        accounts = (try? modelContext.fetch(descriptor)) ?? []
    }

    private var fromAccount: Account? {
        transaction.getFromAccount(context: modelContext)
    }

    private var toAccount: Account? {
        transaction.getToAccount(context: modelContext)
    }

    private var transactionTypeColor: Color {
        if let fromType = fromAccount?.type {
            switch fromType {
            case .income:
                return .green
            case .expense:
                return .red
            default:
                return .primary
            }
        }
        return .primary
    }

    private func getAccountType(_ account: Account?) -> String {
        guard let account else { return "" }
        return account.type.description
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func deleteTransaction() {
        do {
            // 回滚账户余额（与添加交易时相反）
            if let fromAcc = accounts.first(where: { $0.id == transaction.fromAccountId }),
               let toAcc = accounts.first(where: { $0.id == transaction.toAccountId }) {

                // 回滚来源账户（与添加时的逻辑相反）
                switch fromAcc.type {
                case .asset:
                    // 资产账户：添加时减少，回滚时增加
                    fromAcc.updateBalance(transaction.amount)
                case .liability:
                    // 负债账户：添加时增加（向负变少），回滚时减少（向负变大）
                    fromAcc.updateBalance(-transaction.amount)
                case .income:
                    // 收入账户：添加时减少，回滚时增加
                    fromAcc.updateBalance(transaction.amount)
                case .expense:
                    // 支出账户：添加时增加，回滚时减少
                    fromAcc.updateBalance(-transaction.amount)
                }

                // 回滚去向账户（与添加时的逻辑相反）
                switch toAcc.type {
                case .asset:
                    // 资产账户：添加时增加，回滚时减少
                    toAcc.updateBalance(-transaction.amount)
                case .liability:
                    // 负债账户：添加时减少（向负变大），回滚时增加（向负变少）
                    toAcc.updateBalance(transaction.amount)
                case .income:
                    // 收入账户：添加时增加，回滚时减少
                    toAcc.updateBalance(-transaction.amount)
                case .expense:
                    // 支出账户：添加时增加，回滚时减少
                    toAcc.updateBalance(-transaction.amount)
                }
            }

            // 删除交易（即使账户余额回滚失败，也要删除交易记录）
            modelContext.delete(transaction)

            // 保存所有更改
            try modelContext.save()

            // 删除成功后才关闭视图
            dismiss()
        } catch {
            // 删除失败，打印错误但不关闭视图
            print("删除交易失败: \(error.localizedDescription)")
        }
    }
}

/// 编辑交易视图
struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var transaction: Transaction

    @State private var amount: String
    @State private var selectedCurrency: String
    @State private var fromAccountId: UUID
    @State private var toAccountId: UUID
    @State private var note: String
    @State private var transactionDate: Date
    @State private var showingDatePicker = false
    @State private var showingFromPicker = false
    @State private var showingToPicker = false

    @State private var accounts: [Account] = []
    @State private var selectedFromAccountId: UUID?
    @State private var selectedToAccountId: UUID?

    private let currencies = Currency.defaultCurrencies

    // 优化：使用计算属性过滤账户
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

    init(transaction: Transaction) {
        self.transaction = transaction
        _amount = State(initialValue: transaction.amount.description)
        _selectedCurrency = State(initialValue: transaction.currencyCode)
        _fromAccountId = State(initialValue: transaction.fromAccountId)
        _toAccountId = State(initialValue: transaction.toAccountId)
        _note = State(initialValue: transaction.note)
        _transactionDate = State(initialValue: transaction.createdAt)
        _selectedFromAccountId = State(initialValue: transaction.fromAccountId)
        _selectedToAccountId = State(initialValue: transaction.toAccountId)
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
                Section("金额") {
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
                    }
                }

                // 来源
                Section("来源（钱从哪里来？）") {
                    Button(action: {
                        selectedFromAccountId = fromAccountId
                        showingFromPicker = true
                    }) {
                        HStack {
                            Text(getAccountName(fromAccountId))
                                .foregroundColor(.primary)
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
                        selectedToAccountId = toAccountId
                        showingToPicker = true
                    }) {
                        HStack {
                            Text(getAccountName(toAccountId))
                                .foregroundColor(.primary)
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
            .navigationTitle("编辑交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
            .onChange(of: showingFromPicker) { _, newValue in
                if !newValue, let newFromId = selectedFromAccountId {
                    // Picker关闭时，同步选择的账户
                    fromAccountId = newFromId
                }
            }
            .onChange(of: showingToPicker) { _, newValue in
                if !newValue, let newToId = selectedToAccountId {
                    // Picker关闭时，同步选择的账户
                    toAccountId = newToId
                }
            }
            .sheet(isPresented: $showingFromPicker) {
                AccountPickerView(
                    selectedAccountId: $selectedFromAccountId,
                    accounts: fromAccounts,
                    title: "选择来源账户",
                    availableTypes: [.income, .asset, .liability]
                )
            }
            .sheet(isPresented: $showingToPicker) {
                AccountPickerView(
                    selectedAccountId: $selectedToAccountId,
                    accounts: toAccounts,
                    title: "选择去向账户",
                    availableTypes: [.expense, .asset, .liability]
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerView(selectedDate: $transactionDate)
            }
            .onAppear {
                loadAccounts()
            }
        }
    }

    private func loadAccounts() {
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.orderIndex)])
        accounts = (try? modelContext.fetch(descriptor)) ?? []
    }

    private var isValid: Bool {
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
        guard fromAccountId != toAccountId else { return false }
        return true
    }

    private func getAccountName(_ accountId: UUID) -> String {
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            return "请选择"
        }
        return account.name
    }

    private func saveChanges() {
        guard let amountValue = Decimal(string: amount) else { return }

        // 回滚旧的交易
        rollbackTransaction()

        // 更新交易信息
        transaction.amount = amountValue
        transaction.fromAccountId = fromAccountId
        transaction.toAccountId = toAccountId
        transaction.currencyCode = selectedCurrency
        transaction.note = note
        transaction.createdAt = transactionDate
        transaction.updatedAt = Date()

        // 应用新的交易
        applyTransaction()

        try? modelContext.save()
        dismiss()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func rollbackTransaction() {
        guard let oldFromAccount = accounts.first(where: { $0.id == transaction.fromAccountId }),
              let oldToAccount = accounts.first(where: { $0.id == transaction.toAccountId }) else {
            return
        }

        // 回滚来源账户
        updateAccountBalance(oldFromAccount, amount: transaction.amount, isFromAccount: true, rollback: true)

        // 回滚去向账户
        updateAccountBalance(oldToAccount, amount: transaction.amount, isFromAccount: false, rollback: true)
    }

    private func applyTransaction() {
        guard let newFromAccount = accounts.first(where: { $0.id == fromAccountId }),
              let newToAccount = accounts.first(where: { $0.id == toAccountId }) else {
            return
        }

        // 应用来源账户
        updateAccountBalance(newFromAccount, amount: Decimal(string: amount) ?? 0, isFromAccount: true, rollback: false)

        // 应用去向账户
        updateAccountBalance(newToAccount, amount: Decimal(string: amount) ?? 0, isFromAccount: false, rollback: false)
    }

    private func updateAccountBalance(_ account: Account, amount: Decimal, isFromAccount: Bool, rollback: Bool) {
        let multiplier: Decimal = rollback ? -1 : 1

        switch account.type {
        case .asset:
            // 资产账户：来源减少，去向增加
            if isFromAccount {
                account.updateBalance(-amount * multiplier)
            } else {
                account.updateBalance(amount * multiplier)
            }
        case .income:
            // 收入账户：来源减少，去向增加
            if isFromAccount {
                account.updateBalance(-amount * multiplier)
            } else {
                account.updateBalance(amount * multiplier)
            }
        case .expense:
            // 支出账户：来源增加，去向增加
            account.updateBalance(amount * multiplier)
        case .liability:
            // 负债账户：来源增加（向负变少），去向减少（向负变大）
            if isFromAccount {
                account.updateBalance(amount * multiplier)
            } else {
                account.updateBalance(-amount * multiplier)
            }
        }
    }
}

#Preview {
    TransactionDetailView(transaction: Transaction(
        amount: 100,
        fromAccountId: UUID(),
        toAccountId: UUID(),
        note: "测试交易"
    ))
}
