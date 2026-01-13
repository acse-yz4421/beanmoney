//
//  DataManager.swift
//  beanmoney
//
//  Created by Claude Code
//

import Foundation
import SwiftData

/// 数据管理服务
/// 提供统一的数据访问接口
@MainActor
class DataManager {
    static let shared = DataManager()

    private let persistence = Persistence.shared
    private var context: ModelContext {
        persistence.context
    }

    private init() {}

    // MARK: - 账户管理

    /// 获取所有账户
    func getAllAccounts() -> [Account] {
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.orderIndex)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 按类型获取账户
    func getAccounts(byType type: AccountType) -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.typeRawValue == type.rawValue },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 按分类获取账户（用于资产/负债）
    func getAccounts(byCategory category: AssetCategory) -> [Account] {
        let allAccounts = getAllAccounts()
        return allAccounts.filter { account in
            account.category?.id == category.id
        }
    }

    /// 获取账户ID
    func getAccount(byId id: UUID) -> Account? {
        let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    /// 添加账户
    func addAccount(_ account: Account) {
        context.insert(account)
        try? context.save()
    }

    /// 更新账户
    func updateAccount(_ account: Account) {
        try? context.save()
    }

    /// 删除账户
    func deleteAccount(_ account: Account) {
        context.delete(account)
        try? context.save()
    }

    /// 删除账户及其所有相关交易（级联删除）
    func deleteAccountWithTransactions(_ account: Account) {
        // 1. 查找所有涉及该账户的交易
        let transactions = getTransactions(for: account)

        // 2. 删除所有交易（会自动回滚账户余额）
        for transaction in transactions {
            deleteTransaction(transaction)
        }

        // 3. 删除账户
        deleteAccount(account)
    }

    // MARK: - 交易管理

    /// 获取所有交易
    func getAllTransactions() -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 按日期范围获取交易
    func getTransactions(from startDate: Date, to endDate: Date) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.createdAt >= startDate && $0.createdAt <= endDate },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 获取最近的交易
    func getRecentTransactions(limit: Int = 20) -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 添加交易
    func addTransaction(_ transaction: Transaction) {
        // 复式记账逻辑
        guard let fromAccount = getAccount(byId: transaction.fromAccountId),
              let toAccount = getAccount(byId: transaction.toAccountId) else {
            return
        }

        // 更新账户余额
        // 来源账户：如果类型是资产，则减少；如果是收入/负债，则增加
        // 去向账户：如果类型是资产，则增加；如果是支出/负债，则减少

        updateAccountBalance(fromAccount, amount: -transaction.amount, transaction: transaction)
        updateAccountBalance(toAccount, amount: transaction.amount, transaction: transaction)

        // 保存交易
        context.insert(transaction)
        try? context.save()
    }

    /// 更新账户余额（复式记账逻辑）
    private func updateAccountBalance(_ account: Account, amount: Decimal, transaction: Transaction) {
        switch account.type {
        case .asset:
            // 资产账户：正数增加，负数减少
            account.updateBalance(amount)
        case .income:
            // 收入账户：正数增加，负数减少
            account.updateBalance(amount)
        case .expense:
            // 支出账户：正数增加，负数减少
            account.updateBalance(amount)
        case .liability:
            // 负债账户：正数增加，负数减少
            account.updateBalance(amount)
        }
    }

    /// 获取账户涉及的所有交易
    func getTransactions(for account: Account) -> [Transaction] {
        let allTransactions = getAllTransactions()
        return allTransactions.filter { transaction in
            transaction.fromAccountId == account.id || transaction.toAccountId == account.id
        }
    }

    /// 删除交易（会回滚账户余额）
    func deleteTransaction(_ transaction: Transaction) {
        // 获取关联账户
        guard let fromAccount = getAccount(byId: transaction.fromAccountId),
              let toAccount = getAccount(byId: transaction.toAccountId) else {
            return
        }

        // 回滚来源账户余额
        rollbackAccountBalance(fromAccount, amount: transaction.amount, isFromAccount: true)

        // 回滚去向账户余额
        rollbackAccountBalance(toAccount, amount: transaction.amount, isFromAccount: false)

        // 删除交易记录
        context.delete(transaction)
        try? context.save()
    }

    /// 回滚账户余额
    private func rollbackAccountBalance(_ account: Account, amount: Decimal, isFromAccount: Bool) {
        switch account.type {
        case .asset:
            // 资产账户：来源时需要增加（回滚），去向时需要减少（回滚）
            if isFromAccount {
                account.updateBalance(amount)  // 来源账户回滚：增加
            } else {
                account.updateBalance(-amount) // 去向账户回滚：减少
            }
        case .income:
            // 收入账户：回滚时减少
            account.updateBalance(-amount)
        case .expense:
            // 支出账户：回滚时减少
            account.updateBalance(-amount)
        case .liability:
            // 负债账户：回滚时减少
            account.updateBalance(-amount)
        }
    }

    // MARK: - 统计计算

    /// 计算净资产
    func calculateNetWorth() -> Decimal {
        let accounts = getAllAccounts()
        var total: Decimal = 0

        for account in accounts {
            switch account.type {
            case .asset:
                total += account.balance
            case .liability:
                total -= account.balance
            case .income, .expense:
                break
            }
        }

        return total
    }

    /// 计算总资产
    func calculateTotalAssets() -> Decimal {
        let assetAccounts = getAccounts(byType: .asset)
        return assetAccounts.reduce(0) { $0 + $1.balance }
    }

    /// 计算总负债
    func calculateTotalLiabilities() -> Decimal {
        let liabilityAccounts = getAccounts(byType: .liability)
        return liabilityAccounts.reduce(0) { $0 + $1.balance }
    }

    /// 计算资产总增加（收入类账户余额总和）
    func calculateTotalIncome() -> Decimal {
        let incomeAccounts = getAccounts(byType: .income)
        return incomeAccounts.reduce(0) { $0 + abs($1.balance) }
    }

    /// 计算资产总减少（支出类账户余额总和）
    func calculateTotalExpense() -> Decimal {
        let expenseAccounts = getAccounts(byType: .expense)
        return expenseAccounts.reduce(0) { $0 + abs($1.balance) }
    }
}
