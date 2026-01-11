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
                Account.self
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
            // 创建系统预设账户
            let systemAccounts = Account.createSystemAccounts()
            print("=== 系统预设账户数量: \(systemAccounts.count) ===")

            // 检查现有账户
            let accountsDescriptor = FetchDescriptor<Account>()
            let existingAccounts = try context.fetch(accountsDescriptor)

            print("=== 数据库中现有账户数量: \(existingAccounts.count) ===")
            for account in existingAccounts {
                print("  - \(account.name) | 类型: \(account.type.rawValue) | 分类: \(account.categoryRawValue ?? "无") | 余额: \(account.balance)")
            }

            let existingAccountNames = Set(existingAccounts.map { $0.name })

            // 添加缺失的系统预设账户
            var addedCount = 0
            for account in systemAccounts {
                if !existingAccountNames.contains(account.name) {
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
