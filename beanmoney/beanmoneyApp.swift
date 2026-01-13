//
//  beanmoneyApp.swift
//  beanmoney
//
//  Created by zhou yuqi on 4/1/2026.
//

import SwiftUI
import SwiftData

@main
struct beanmoneyApp: App {
    // 共享的ModelContainer
    let modelContainer: ModelContainer

    init() {
        do {
            // 配置SwiftData
            let schema = Schema([
                Transaction.self,
                Account.self,
                AssetCategory.self
            ])

            // 检测是否需要重置数据库（用于开发调试）
            // ⚠️ 生产环境应该移除这段代码，改为正确的迁移策略
            #if DEBUG
            let fileManager = FileManager.default
            if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                let storeURL = documentsURL.appendingPathComponent("default.store")
                // 删除旧数据库以重置数据
                try? fileManager.removeItem(at: storeURL)
                print("🗑️ 数据库已重置")
            }
            #endif

            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )

            // 初始化系统数据
            initializeSystemData()

        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }

    /// 初始化系统预设数据
    private func initializeSystemData() {
        let context = modelContainer.mainContext

        do {
            // 初始化默认分组
            initializeDefaultCategories(context: context)

            // 获取所有分组
            let categoriesDescriptor = FetchDescriptor<AssetCategory>()
            let allCategories = try context.fetch(categoriesDescriptor)

            // 创建分组名称到分组的映射
            let categoryMap = Dictionary(uniqueKeysWithValues: allCategories.map { ($0.name, $0) })

            // 创建系统预设账户
            let systemAccounts = Account.createSystemAccounts()
            print("=== 系统预设账户数量: \(systemAccounts.count) ===")

            // 检查现有账户
            let accountsDescriptor = FetchDescriptor<Account>()
            let existingAccounts = try context.fetch(accountsDescriptor)

            print("=== 数据库中现有账户数量: \(existingAccounts.count) ===")
            for account in existingAccounts {
                print("  - \(account.name) | 类型: \(account.type.rawValue) | 分组: \(account.category?.name ?? "无") | 余额: \(account.balance)")
            }

            let existingAccountNames = Set(existingAccounts.map { $0.name })

            // 账户名称到分组名称的映射
            let accountToCategoryMap: [String: String] = [
                // 收入
                "工资收入": "收入",
                "投资收益": "投资收益",
                // 支出 - 生活
                "餐饮": "生活支出",
                "交通": "生活支出",
                "购物": "生活支出",
                "娱乐": "生活支出",
                // 支出 - 财务
                "利息": "财务支出",
                "手续费": "财务支出",
                // 资产 - 流动
                "支付宝": "流动资产",
                "微信": "流动资产",
                "现金": "流动资产",
                "招商银行": "流动资产",
                "工商银行": "流动资产",
                // 资产 - 固定
                "房产": "固定资产",
                "车辆": "固定资产",
                "电子产品": "固定资产",
                "家具家电": "固定资产",
                // 资产 - 外币
                "美元账户": "外币账户",
                "欧元账户": "外币账户",
                "港币账户": "外币账户",
                "比特币": "外币账户",
                "以太坊": "外币账户",
                // 资产 - 投资
                "股票账户": "投资账户",
                "基金账户": "投资账户",
                "黄金账户": "投资账户",
                "理财产品": "投资账户",
                // 负债
                "招商信用卡": "信用负债",
                "花呗": "信用负债",
                "借呗": "信用负债",
                "房贷": "信用负债",
                "车贷": "信用负债",
            ]

            // 添加缺失的系统预设账户
            var addedCount = 0
            for account in systemAccounts {
                if !existingAccountNames.contains(account.name) {
                    // 根据账户名称查找对应的分组
                    if let categoryName = accountToCategoryMap[account.name],
                       let category = categoryMap[categoryName] {
                        account.category = category
                    }

                    context.insert(account)
                    print("✅ 添加系统预设账户: \(account.name)")
                    addedCount += 1
                }
            }

            if addedCount == 0 {
                print("ℹ️ 所有系统预设账户已存在，无需添加")
            }

            try context.save()
            print("=== 初始化完成 ===")
        } catch {
            print("❌ 初始化系统数据失败: \(error)")
        }
    }
}
