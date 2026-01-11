//
//  Currency.swift
//  beanmoney
//
//  Created by Claude Code
//

import Foundation

/// 币种模型
struct Currency: Identifiable, Codable, Hashable {
    let id: UUID
    var code: String              // 货币代码，如 CNY, USD, EUR
    var symbol: String            // 货币符号，如 ¥, $, €
    var name: String              // 货币名称，如 人民币, 美元
    var rate: Decimal?            // 相对于基准货币的汇率（可选，用于外币账户）
    var isDefault: Bool           // 是否为默认币种

    init(id: UUID = UUID(), code: String, symbol: String, name: String, rate: Decimal? = nil, isDefault: Bool = false) {
        self.id = id
        self.code = code
        self.symbol = symbol
        self.name = name
        self.rate = rate
        self.isDefault = isDefault
    }

    /// 格式化金额
    func format(_ amount: Decimal) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencySymbol = symbol
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2

        let nsAmount = NSDecimalNumber(decimal: amount)
        return numberFormatter.string(from: nsAmount) ?? "\(symbol)\(amount)"
    }

    /// 常用币种预设
    static let defaultCurrencies: [Currency] = [
        Currency(code: "CNY", symbol: "¥", name: "人民币", isDefault: true),
        Currency(code: "USD", symbol: "$", name: "美元"),
        Currency(code: "EUR", symbol: "€", name: "欧元"),
        Currency(code: "JPY", symbol: "¥", name: "日元"),
        Currency(code: "GBP", symbol: "£", name: "英镑"),
        Currency(code: "HKD", symbol: "HK$", name: "港币"),
        Currency(code: "BTC", symbol: "₿", name: "比特币"),
        Currency(code: "ETH", symbol: "Ξ", name: "以太坊"),
    ]
}
