//
//  Persistence.swift
//  beanmoney
//
//  Created by Claude Code
//

import Foundation
import SwiftData

/// 数据持久化管理器
/// 负责配置SwiftData容器，支持本地和iCloud存储
@MainActor
class Persistence {
    /// 共享的单例实例
    static let shared = Persistence()

    /// SwiftData ModelContainer
    let container: ModelContainer

    /// ModelContext
    var context: ModelContext {
        container.mainContext
    }

    /// iCloud是否启用
    private(set) var iCloudEnabled: Bool = false

    private init() {
        do {
            // 注册所有模型
            let schema = Schema([
                Transaction.self,
                Account.self
            ])

            // 尝试创建带iCloud的容器（如果用户启用了）
            // 默认使用本地存储
            let configuration = ModelConfiguration(isStoredInMemoryOnly: false)

            self.container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )

            // 初始化系统数据
            try? initializeSystemData()

        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    /// 切换到iCloud存储
    func enableCloudKit() throws {
        guard !iCloudEnabled else { return }

        // TODO: 实现从本地存储迁移到iCloud的逻辑
        // 需要创建新的ModelContainer并迁移数据

        iCloudEnabled = true
    }

    /// 切换到本地存储
    func disableCloudKit() {
        iCloudEnabled = false
    }

    /// 初始化系统预设数据
    private func initializeSystemData() throws {
        // 检查是否已初始化
        let accountsDescriptor = FetchDescriptor<Account>()
        let existingAccounts = try? context.fetch(accountsDescriptor)

        guard let existing = existingAccounts, existing.isEmpty else {
            return // 已有数据，不需要初始化
        }

        // 创建系统预设账户
        let systemAccounts = Account.createSystemAccounts()

        for account in systemAccounts {
            context.insert(account)
        }

        try context.save()
    }
}
