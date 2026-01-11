//
//  AppSettings.swift
//  beanmoney
//
//  Created by Claude Code
//

import Foundation
import SwiftUI

/// 应用设置
@Observable
class AppSettings {
    static let shared = AppSettings()

    /// 默认币种代码
    var defaultCurrencyCode: String {
        get {
            UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "CNY"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "defaultCurrencyCode")
        }
    }

    /// 汇率表（相对于默认币种）
    var exchangeRates: [String: Double] {
        get {
            UserDefaults.standard.dictionary(forKey: "exchangeRates") as? [String: Double] ?? ["CNY": 1.0]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "exchangeRates")
        }
    }

    /// 标题背景颜色（hex值）
    var titleColorHex: String {
        get {
            UserDefaults.standard.string(forKey: "titleColorHex") ?? "#E67E22"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "titleColorHex")
            NotificationCenter.default.post(name: NSNotification.Name("TitleColorDidChange"), object: nil)
        }
    }

    /// 标题背景颜色（SwiftUI Color）
    var titleColor: Color {
        Color(hex: titleColorHex)
    }

    /// 获取默认币种对象
    var defaultCurrency: Currency {
        Currency.defaultCurrencies.first { $0.code == defaultCurrencyCode }
            ?? Currency(code: defaultCurrencyCode, symbol: defaultCurrencyCode, name: defaultCurrencyCode)
    }

    /// 获取汇率
    func getExchangeRate(for currencyCode: String) -> Double {
        if currencyCode == defaultCurrencyCode {
            return 1.0
        }
        return exchangeRates[currencyCode] ?? 1.0
    }

    /// 设置汇率
    func setExchangeRate(_ rate: Double, for currencyCode: String) {
        var rates = exchangeRates
        rates[currencyCode] = rate
        exchangeRates = rates
    }

    /// 将金额从一种币种换算到默认币种
    func convertToDefault(amount: Decimal, from currencyCode: String) -> Decimal {
        let rate = getExchangeRate(for: currencyCode)
        return amount * Decimal(rate)
    }

    /// 格式化显示（包含原币种和默认币种）
    func formatAmountWithConversion(amount: Decimal, currencyCode: String) -> String {
        if currencyCode == defaultCurrencyCode {
            // 如果就是默认币种，只显示一个
            let currency = Currency.defaultCurrencies.first { $0.code == currencyCode }
                ?? Currency(code: currencyCode, symbol: "?", name: currencyCode)
            return currency.format(amount)
        } else {
            // 如果不是默认币种，显示两个
            let originalCurrency = Currency.defaultCurrencies.first { $0.code == currencyCode }
                ?? Currency(code: currencyCode, symbol: "?", name: currencyCode)

            let convertedAmount = convertToDefault(amount: amount, from: currencyCode)
            let originalText = originalCurrency.format(amount)
            let convertedText = defaultCurrency.format(convertedAmount)

            return "\(originalText) ≈ \(convertedText)"
        }
    }

    private init() {}
}

/// Color扩展：支持从hex字符串创建颜色
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// 预设的标题颜色选项
struct TitleColorOption: Identifiable {
    let id = UUID()
    let hex: String
    let name: String
    let color: Color

    init(hex: String, name: String) {
        self.hex = hex
        self.name = name
        self.color = Color(hex: hex)
    }

    static let allOptions: [TitleColorOption] = [
        // 红色系 (2个)
        TitleColorOption(hex: "#E74C3C", name: "朱红"),
        TitleColorOption(hex: "#C62828", name: "绯红"),

        // 橙色系 (2个)
        TitleColorOption(hex: "#F57C00", name: "橙色"),
        TitleColorOption(hex: "#EF6C00", name: "琥珀"),

        // 黄色系 (2个)
        TitleColorOption(hex: "#F9A825", name: "金黄"),
        TitleColorOption(hex: "#FBC02D", name: "柠檬"),

        // 绿色系 (3个)
        TitleColorOption(hex: "#43A047", name: "草绿"),
        TitleColorOption(hex: "#00897B", name: "青绿"),
        TitleColorOption(hex: "#2E7D32", name: "森林绿"),

        // 青色系 (2个)
        TitleColorOption(hex: "#00ACC1", name: "青色"),
        TitleColorOption(hex: "#00838F", name: "海蓝"),

        // 蓝色系 (2个)
        TitleColorOption(hex: "#1E88E5", name: "天蓝"),
        TitleColorOption(hex: "#3949AB", name: "靛蓝"),

        // 紫色系 (2个)
        TitleColorOption(hex: "#8E24AA", name: "紫色"),
        TitleColorOption(hex: "#5E35B1", name: "深紫"),
    ]
}
