//
//  AccountType.swift
//  beanmoney
//
//  Created by Claude Code
//

import Foundation

/// 账户类型枚举
enum AccountType: String, CaseIterable, Codable {
    case income = "收入"          // 工资、投资收益等（使资产增加）
    case expense = "支出"         // 日常消费等（使资产减少）
    case asset = "资产"           // 资产账户（银行、现金等）
    case liability = "负债"       // 负债账户（信用卡、贷款等）

    var description: String {
        return self.rawValue
    }
}

/// 账户分类（用于所有类型账户的细分）
enum AssetCategory: String, CaseIterable, Codable {
    // 收入分类
    case income = "收入"           // 默认收入分类
    case salary = "工资收入"        // 工资、奖金
    case investmentIncome = "投资收益"    // 股票、基金收益
    case otherIncome = "其他收入"   // 其他收入来源

    // 支出分类
    case expense = "支出"          // 默认支出分类
    case living = "生活支出"        // 日常消费
    case finance = "财务支出"       // 理财、保险等

    // 资产分类
    case current = "流动资产"      // 支付宝、微信、现金、银行卡
    case fixed = "固定资产"       // 房产、车辆、电子产品
    case foreign = "外币账户"     // 外汇、加密货币
    case investmentAccount = "投资账户"  // 股票、基金账户

    // 负债分类
    case credit = "信用负债"      // 信用卡、花呗、贷款

    var description: String {
        return self.rawValue
    }

    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .salary: return "banknote"
        case .investmentIncome: return "chart.line.uptrend.xyaxis"
        case .otherIncome: return "gift.fill"

        case .expense: return "arrow.up.circle.fill"
        case .living: return "cart.fill"
        case .finance: return "chart.bar.fill"

        case .current: return "banknote"
        case .fixed: return "house"
        case .foreign: return "globe"
        case .investmentAccount: return "chart.line.uptrend.xyaxis"

        case .credit: return "creditcard"
        }
    }

    /// 获取默认分类（根据账户类型）
    static func `default`(for type: AccountType) -> AssetCategory {
        switch type {
        case .income: return .income
        case .expense: return .expense
        case .asset: return .current
        case .liability: return .credit
        }
    }
}
