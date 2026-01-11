//
//  Account.swift
//  beanmoney
//
//  Created by Claude Code
//

import Foundation
import SwiftData

/// 账户模型
@Model
final class Account {
    var id: UUID
    var name: String
    var typeRawValue: String        // AccountType的rawValue
    var categoryRawValue: String?   // AssetCategory的rawValue（可选）
    var balance: Decimal            // 当前余额
    var initialBalance: Decimal     // 初始金额
    var currencyCode: String        // 关联Currency的code
    var icon: String
    var note: String
    var orderIndex: Int             // 排序索引
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        category: AssetCategory? = nil,
        balance: Decimal = 0,
        initialBalance: Decimal = 0,
        currencyCode: String = "CNY",
        icon: String = "folder",
        note: String = "",
        orderIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.typeRawValue = type.rawValue
        self.categoryRawValue = category?.rawValue
        self.balance = balance
        self.initialBalance = initialBalance
        self.currencyCode = currencyCode
        self.icon = icon
        self.note = note
        self.orderIndex = orderIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 账户类型
    var type: AccountType {
        get { AccountType(rawValue: typeRawValue) ?? .asset }
        set { typeRawValue = newValue.rawValue }
    }

    /// 账户分类（仅用于资产/负债类型）
    var category: AssetCategory? {
        get {
            guard let categoryRawValue else { return nil }
            return AssetCategory(rawValue: categoryRawValue)
        }
        set { categoryRawValue = newValue?.rawValue }
    }

    /// 格式化后的余额
    var formattedBalance: String {
        let currency = Currency.defaultCurrencies.first { $0.code == currencyCode }
                ?? Currency(code: currencyCode, symbol: "?", name: currencyCode)
        // 负债账户的余额是负数，但显示时不显示负号
        let displayBalance = type == .liability ? -balance : balance
        return currency.format(displayBalance)
    }

    /// 格式化后的初始余额
    var formattedInitialBalance: String {
        let currency = Currency.defaultCurrencies.first { $0.code == currencyCode }
                ?? Currency(code: currencyCode, symbol: "?", name: currencyCode)
        // 负债账户的余额是负数，但显示时不显示负号
        let displayBalance = type == .liability ? -initialBalance : initialBalance
        return currency.format(displayBalance)
    }

    /// 格式化后的余额（包含换算）
    var formattedBalanceWithConversion: String {
        // 负债账户的余额是负数，但显示时不显示负号
        let displayBalance = type == .liability ? -balance : balance
        return AppSettings.shared.formatAmountWithConversion(amount: displayBalance, currencyCode: currencyCode)
    }

    /// 换算后的余额（默认币种）
    var convertedBalance: Decimal {
        // 负债账户的余额是负数，但换算后也保持负数用于计算
        return AppSettings.shared.convertToDefault(amount: balance, from: currencyCode)
    }

    /// 更新余额
    func updateBalance(_ amount: Decimal) {
        balance += amount
        updatedAt = Date()
    }

    /// 设置余额
    func setBalance(_ amount: Decimal) {
        balance = amount
        updatedAt = Date()
    }
}

// MARK: - 系统预设账户工厂
extension Account {
    /// 创建系统预设账户
    static func createSystemAccounts() -> [Account] {
        var accounts: [Account] = []

        // 收入账户
        let incomeAccounts = [
            ("工资收入", "banknote", AssetCategory.income),
            ("投资收益", "chart.line.uptrend.xyaxis", AssetCategory.investmentIncome),
        ]

        for (index, (name, icon, category)) in incomeAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .income,
                category: category,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 支出账户 - 生活支出
        let livingExpenseAccounts = [
            ("餐饮", "fork.knife", AssetCategory.living),
            ("交通", "car.fill", AssetCategory.living),
            ("购物", "bag.fill", AssetCategory.living),
            ("娱乐", "gamecontroller.fill", AssetCategory.living),
        ]

        for (index, (name, icon, category)) in livingExpenseAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .expense,
                category: category,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 支出账户 - 财务支出
        let financeExpenseAccounts = [
            ("利息", "percent", AssetCategory.finance),
            ("手续费", "banknote", AssetCategory.finance),
        ]

        for (index, (name, icon, category)) in financeExpenseAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .expense,
                category: category,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 流动资产
        let currentAssets = [
            ("支付宝", "ant.fill", AssetCategory.current),
            ("微信", "message.fill", AssetCategory.current),
            ("现金", "banknote.fill", AssetCategory.current),
            ("招商银行", "building.columns.fill", AssetCategory.current),
            ("工商银行", "building.columns.fill", AssetCategory.current),
        ]

        for (index, (name, icon, category)) in currentAssets.enumerated() {
            accounts.append(Account(
                name: name,
                type: .asset,
                category: category,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 固定资产
        let fixedAssets = [
            ("房产", "house.fill", AssetCategory.fixed),
            ("车辆", "car.fill", AssetCategory.fixed),
            ("电子产品", "laptopcomputer", AssetCategory.fixed),
            ("家具家电", "sofa.fill", AssetCategory.fixed),
        ]

        for (index, (name, icon, category)) in fixedAssets.enumerated() {
            accounts.append(Account(
                name: name,
                type: .asset,
                category: category,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 外币账户
        let foreignAccounts = [
            ("美元账户", "dollarsign.circle", AssetCategory.foreign, "USD"),
            ("欧元账户", "eurosign.circle", AssetCategory.foreign, "EUR"),
            ("港币账户", "hkd.sign.circle", AssetCategory.foreign, "HKD"),
            ("比特币", "bitcoinsign.circle", AssetCategory.foreign, "BTC"),
            ("以太坊", "eth.circle", AssetCategory.foreign, "ETH"),
        ]

        for (index, (name, icon, category, currencyCode)) in foreignAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .asset,
                category: category,
                balance: 0,
                initialBalance: 0,
                currencyCode: currencyCode,
                icon: icon,
                orderIndex: index
            ))
        }

        // 投资账户
        let investmentAccounts = [
            ("股票账户", "chart.line.uptrend.xyaxis.circle", AssetCategory.investmentAccount),
            ("基金账户", "chart.bar.fill", AssetCategory.investmentAccount),
            ("黄金账户", "circle.lefthalf.filled", AssetCategory.investmentAccount),
            ("理财产品", "banknote", AssetCategory.investmentAccount),
        ]

        for (index, (name, icon, category)) in investmentAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .asset,
                category: category,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 信用负债
        let creditLiabilities = [
            ("招商信用卡", "creditcard.fill", AssetCategory.credit),
            ("花呗", "ant.fill", AssetCategory.credit),
            ("借呗", "hand.draw.fill", AssetCategory.credit),
            ("房贷", "house.fill", AssetCategory.credit),
            ("车贷", "car.fill", AssetCategory.credit),
        ]

        for (index, (name, icon, category)) in creditLiabilities.enumerated() {
            accounts.append(Account(
                name: name,
                type: .liability,
                category: category,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        return accounts
    }
}
