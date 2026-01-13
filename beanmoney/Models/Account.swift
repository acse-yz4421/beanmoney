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
    @Relationship var category: AssetCategory?  // 关联分组
    var balance: Decimal            // 当前余额
    var initialBalance: Decimal     // 初始金额
    var currencyCode: String        // 关联Currency的code
    var icon: String
    var note: String
    var orderIndex: Int             // 排序索引

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
        self.category = category
        self.balance = balance
        self.initialBalance = initialBalance
        self.currencyCode = currencyCode
        self.icon = icon
        self.note = note
        self.orderIndex = orderIndex
    }

    /// 账户类型
    var type: AccountType {
        get { AccountType(rawValue: typeRawValue) ?? .asset }
        set { typeRawValue = newValue.rawValue }
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
    }

    /// 设置余额
    func setBalance(_ amount: Decimal) {
        balance = amount
    }
}

// MARK: - 系统预设账户工厂
extension Account {
    /// 创建系统预设账户（不关联category，初始化时再关联）
    static func createSystemAccounts() -> [Account] {
        var accounts: [Account] = []

        // 收入账户
        let incomeAccounts = [
            ("工资收入", "banknote", "收入"),
            ("投资收益", "chart.line.uptrend.xyaxis", "投资收益"),
        ]

        for (index, (name, icon, categoryName)) in incomeAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .income,
                category: nil,  // 初始化时不关联
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 支出账户 - 生活支出
        let livingExpenseAccounts = [
            ("餐饮", "fork.knife", "生活支出"),
            ("交通", "car.fill", "生活支出"),
            ("购物", "bag.fill", "生活支出"),
            ("娱乐", "gamecontroller.fill", "生活支出"),
        ]

        for (index, (name, icon, categoryName)) in livingExpenseAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .expense,
                category: nil,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 支出账户 - 财务支出
        let financeExpenseAccounts = [
            ("利息", "percent", "财务支出"),
            ("手续费", "banknote", "财务支出"),
        ]

        for (index, (name, icon, categoryName)) in financeExpenseAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .expense,
                category: nil,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 流动资产
        let currentAssets = [
            ("支付宝", "ant.fill", "流动资产"),
            ("微信", "message.fill", "流动资产"),
            ("现金", "banknote.fill", "流动资产"),
            ("招商银行", "building.columns.fill", "流动资产"),
            ("工商银行", "building.columns.fill", "流动资产"),
        ]

        for (index, (name, icon, categoryName)) in currentAssets.enumerated() {
            accounts.append(Account(
                name: name,
                type: .asset,
                category: nil,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 固定资产
        let fixedAssets = [
            ("房产", "house.fill", "固定资产"),
            ("车辆", "car.fill", "固定资产"),
            ("电子产品", "laptopcomputer", "固定资产"),
            ("家具家电", "sofa.fill", "固定资产"),
        ]

        for (index, (name, icon, categoryName)) in fixedAssets.enumerated() {
            accounts.append(Account(
                name: name,
                type: .asset,
                category: nil,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 外币账户
        let foreignAccounts = [
            ("美元账户", "dollarsign.circle", "外币账户", "USD"),
            ("欧元账户", "eurosign.circle", "外币账户", "EUR"),
            ("港币账户", "hkd.sign.circle", "外币账户", "HKD"),
            ("比特币", "bitcoinsign.circle", "外币账户", "BTC"),
            ("以太坊", "eth.circle", "外币账户", "ETH"),
        ]

        for (index, (name, icon, categoryName, currencyCode)) in foreignAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .asset,
                category: nil,
                balance: 0,
                initialBalance: 0,
                currencyCode: currencyCode,
                icon: icon,
                orderIndex: index
            ))
        }

        // 投资账户
        let investmentAccounts = [
            ("股票账户", "chart.line.uptrend.xyaxis.circle", "投资账户"),
            ("基金账户", "chart.bar.fill", "投资账户"),
            ("黄金账户", "circle.lefthalf.filled", "投资账户"),
            ("理财产品", "banknote", "投资账户"),
        ]

        for (index, (name, icon, categoryName)) in investmentAccounts.enumerated() {
            accounts.append(Account(
                name: name,
                type: .asset,
                category: nil,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        // 信用负债
        let creditLiabilities = [
            ("招商信用卡", "creditcard.fill", "信用负债"),
            ("花呗", "ant.fill", "信用负债"),
            ("借呗", "hand.draw.fill", "信用负债"),
            ("房贷", "house.fill", "信用负债"),
            ("车贷", "car.fill", "信用负债"),
        ]

        for (index, (name, icon, categoryName)) in creditLiabilities.enumerated() {
            accounts.append(Account(
                name: name,
                type: .liability,
                category: nil,
                balance: 0,
                initialBalance: 0,
                icon: icon,
                orderIndex: index
            ))
        }

        return accounts
    }
}
