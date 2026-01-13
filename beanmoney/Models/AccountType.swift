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

    var icon: String {
        switch self {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .asset: return "banknote"
        case .liability: return "creditcard.fill"
        }
    }
}
