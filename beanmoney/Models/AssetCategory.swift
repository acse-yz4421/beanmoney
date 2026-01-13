//
//  AssetCategory.swift
//  beanmoney
//
//  Created by Claude Code
//

import Foundation
import SwiftData

/// 账户分组（数据库模型）
@Model
final class AssetCategory {
    var id: UUID
    var name: String
    var accountTypeRawValue: String
    var orderIndex: Int

    init(id: UUID = UUID(), name: String, accountType: AccountType, orderIndex: Int = 0) {
        self.id = id
        self.name = name
        self.accountTypeRawValue = accountType.rawValue
        self.orderIndex = orderIndex
    }

    /// 账户类型
    var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRawValue) ?? .asset }
        set { accountTypeRawValue = newValue.rawValue }
    }
}

/// 初始化默认分组
func initializeDefaultCategories(context: ModelContext) {
    // 检查是否已经初始化
    let descriptor = FetchDescriptor<AssetCategory>()
    let existingCount = (try? context.fetch(descriptor))?.count ?? 0
    if existingCount > 0 {
        return
    }

    // 收入分组
    let incomeCategories = [
        ("收入", AccountType.income),
        ("工资收入", AccountType.income),
        ("投资收益", AccountType.income),
        ("其他收入", AccountType.income),
    ]

    // 支出分组
    let expenseCategories = [
        ("支出", AccountType.expense),
        ("生活支出", AccountType.expense),
        ("财务支出", AccountType.expense),
    ]

    // 资产分组
    let assetCategories = [
        ("流动资产", AccountType.asset),
        ("固定资产", AccountType.asset),
        ("外币账户", AccountType.asset),
        ("投资账户", AccountType.asset),
    ]

    // 负债分组
    let liabilityCategories = [
        ("信用负债", AccountType.liability),
    ]

    var allCategories = incomeCategories + expenseCategories + assetCategories + liabilityCategories

    for (index, (name, type)) in allCategories.enumerated() {
        let category = AssetCategory(
            name: name,
            accountType: type,
            orderIndex: index
        )
        context.insert(category)
    }

    try? context.save()
}

/// 旧的枚举型 AssetCategory（用于数据迁移参考）
enum LegacyAssetCategory: String, CaseIterable, Codable {
    // 收入分类
    case income = "收入"
    case salary = "工资收入"
    case investmentIncome = "投资收益"
    case otherIncome = "其他收入"

    // 支出分类
    case expense = "支出"
    case living = "生活支出"
    case finance = "财务支出"

    // 资产分类
    case current = "流动资产"
    case fixed = "固定资产"
    case foreign = "外币账户"
    case investmentAccount = "投资账户"

    // 负债分类
    case credit = "信用负债"

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
}
