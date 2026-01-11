//
//  Transaction.swift
//  beanmoney
//
//  Created by Claude Code
//

import Foundation
import SwiftData

/// 交易记录模型
@Model
final class Transaction {
    var id: UUID
    var amount: Decimal
    var fromAccountId: UUID      // 来源账户ID
    var toAccountId: UUID        // 去向账户ID
    var currencyCode: String      // 币种代码
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        fromAccountId: UUID,
        toAccountId: UUID,
        currencyCode: String = "CNY",
        note: String = ""
    ) {
        self.id = id
        self.amount = amount
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.currencyCode = currencyCode
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 获取关联的来源账户（需要通过ViewModel查询）
    func getFromAccount(context: ModelContext) -> Account? {
        let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == fromAccountId })
        return try? context.fetch(descriptor).first
    }

    /// 获取关联的去向账户
    func getToAccount(context: ModelContext) -> Account? {
        let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == toAccountId })
        return try? context.fetch(descriptor).first
    }

    /// 格式化金额
    var formattedAmount: String {
        let currency = Currency.defaultCurrencies.first { $0.code == currencyCode }
                ?? Currency(code: currencyCode, symbol: "?", name: currencyCode)
        return currency.format(amount)
    }

    /// 格式化金额（包含换算）
    var formattedAmountWithConversion: String {
        return AppSettings.shared.formatAmountWithConversion(amount: amount, currencyCode: currencyCode)
    }

    /// 获取交易描述（来源 → 去向）
    func getDescription(context: ModelContext) -> String {
        guard let fromAccount = getFromAccount(context: context),
              let toAccount = getToAccount(context: context) else {
            return "未知交易"
        }
        return "\(fromAccount.name) → \(toAccount.name)"
    }

    /// 交易类型描述
    func getTypeDescription(context: ModelContext) -> (fromType: AccountType, toType: AccountType)? {
        guard let fromAccount = getFromAccount(context: context),
              let toAccount = getToAccount(context: context) else {
            return nil
        }
        return (fromAccount.type, toAccount.type)
    }
}

// MARK: - 交易分类统计辅助
extension Transaction {
    /// 判断是否为资产增加（从收入账户或负债账户转入资产账户）
    func isAssetIncrease(context: ModelContext) -> Bool {
        guard let fromType = getFromAccount(context: context)?.type else { return false }
        return fromType == .income || fromType == .liability
    }

    /// 判断是否为资产减少（从资产账户转出到支出账户）
    func isAssetDecrease(context: ModelContext) -> Bool {
        guard let toType = getToAccount(context: context)?.type else { return false }
        return toType == .expense || toType == .liability
    }
}
