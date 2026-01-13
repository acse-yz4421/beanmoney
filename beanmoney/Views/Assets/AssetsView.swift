//
//  AssetsView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @State private var selectedTab: AssetTab = .asset
    @State private var selectedTimeRange: TimeRange = .month
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex
    @State private var showingAddAccount = false

    enum AssetTab: String, CaseIterable {
        case asset = "总资产"
        case liability = "总负债"
    }

    enum TimeRange: String, CaseIterable {
        case week = "周"
        case month = "月"
        case year = "年"
    }

    /// 获取今日之前的交易
    private var pastTransactions: [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return DataManager.shared.getAllTransactions().filter { transaction in
            let transactionDay = calendar.startOfDay(for: transaction.createdAt)
            return transactionDay <= today
        }
    }

    /// 计算账户在今日之前的余额
    private func getAccountBalanceBeforeToday(_ account: Account) -> Decimal {
        // 从初始余额开始
        var balance = account.initialBalance

        // 应用今日之前的交易
        let accountTransactions = pastTransactions.filter { transaction in
            transaction.fromAccountId == account.id || transaction.toAccountId == account.id
        }

        for transaction in accountTransactions {
            if transaction.fromAccountId == account.id {
                // 账户是来源
                switch account.type {
                case .asset:
                    balance -= transaction.amount
                case .liability:
                    balance -= transaction.amount
                case .income, .expense:
                    balance += transaction.amount
                }
            }

            if transaction.toAccountId == account.id {
                // 账户是去向
                switch account.type {
                case .asset:
                    balance += transaction.amount
                case .liability:
                    balance += transaction.amount
                case .income, .expense:
                    balance -= transaction.amount
                }
            }
        }

        return balance
    }

    var netWorth: Decimal {
        accounts.reduce(0) { total, account in
            let balance = getAccountBalanceBeforeToday(account)
            switch account.type {
            case .asset:
                return total + balance
            case .liability:
                return total - balance
            case .income, .expense:
                return total
            }
        }
    }

    var totalAssets: Decimal {
        accounts.filter { $0.type == .asset }
            .reduce(0) { $0 + getAccountBalanceBeforeToday($1) }
    }

    var totalLiabilities: Decimal {
        accounts.filter { $0.type == .liability }
            .reduce(0) { $0 + getAccountBalanceBeforeToday($1) }
    }

    var filteredAccounts: [Account] {
        switch selectedTab {
        case .asset:
            return accounts.filter { $0.type == .asset }
                .sorted { $0.orderIndex < $1.orderIndex }
        case .liability:
            return accounts.filter { $0.type == .liability }
                .sorted { $0.orderIndex < $1.orderIndex }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 金额概览卡片
                    AssetOverviewCard(
                        netWorth: netWorth,
                        totalAssets: totalAssets,
                        totalLiabilities: totalLiabilities
                    )

                    // 趋势图卡片
                    AssetTrendChart(
                        selectedTimeRange: $selectedTimeRange
                    )

                    // 账户列表切换器
                    AssetAccountSwitcher(
                        selectedTab: $selectedTab,
                        totalAssets: totalAssets,
                        totalLiabilities: totalLiabilities
                    )

                    // 账户分布环形图
                    AssetDistributionChart(
                        accounts: filteredAccounts,
                        selectedTab: selectedTab
                    )

                    // 账户列表
                    AccountListView(
                        accounts: filteredAccounts,
                        selectedTab: selectedTab
                    )
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("资产")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        showingAddAccount = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showingAddAccount) {
                UnifiedAddAccountView()
            }
            .onAppear {
                titleColorHex = AppSettings.shared.titleColorHex
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
                titleColorHex = AppSettings.shared.titleColorHex
            }
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
}

/// 金额概览卡片
struct AssetOverviewCard: View {
    let netWorth: Decimal
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex

    /// 未来交易（今天之后的交易）
    private var futureTransactions: [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return DataManager.shared.getAllTransactions().filter { transaction in
            let transactionDay = calendar.startOfDay(for: transaction.createdAt)
            return transactionDay > today
        }
    }

    /// 预估的净资产变化
    private var estimatedNetWorthChange: Decimal {
        futureTransactions.reduce(0) { total, transaction in
            // 简化计算：假设未来交易都会影响净资产
            // 实际需要根据交易类型详细计算
            return total
        }
    }

    /// 预估的总资产变化
    private var estimatedAssetsChange: Decimal {
        futureTransactions.reduce(0) { total, transaction in
            var change = total

            // 检查来源账户
            if let fromAccount = DataManager.shared.getAccount(byId: transaction.fromAccountId) {
                if fromAccount.type == .asset {
                    change -= transaction.amount
                }
            }

            // 检查去向账户
            if let toAccount = DataManager.shared.getAccount(byId: transaction.toAccountId) {
                if toAccount.type == .asset {
                    change += transaction.amount
                }
            }

            return change
        }
    }

    /// 预估的总负债变化
    private var estimatedLiabilitiesChange: Decimal {
        futureTransactions.reduce(0) { total, transaction in
            var change = total

            // 检查来源账户
            if let fromAccount = DataManager.shared.getAccount(byId: transaction.fromAccountId) {
                if fromAccount.type == .liability {
                    // 负债作为来源：负债减少，余额增加（向正变化）
                    change += transaction.amount
                }
            }

            // 检查去向账户
            if let toAccount = DataManager.shared.getAccount(byId: transaction.toAccountId) {
                if toAccount.type == .liability {
                    // 负债作为去向：负债增加，余额减少（向负变化）
                    change -= transaction.amount
                }
            }

            return change
        }
    }

    /// 预估净资产
    private var estimatedNetWorth: Decimal {
        // 因为estimatedLiabilitiesChange是负数（负债增加），所以用加法
        netWorth + estimatedAssetsChange + estimatedLiabilitiesChange
    }

    /// 预估总资产
    private var estimatedTotalAssets: Decimal {
        totalAssets + estimatedAssetsChange
    }

    /// 预估总负债
    private var estimatedTotalLiabilities: Decimal {
        totalLiabilities + estimatedLiabilitiesChange
    }

    var body: some View {
        VStack(spacing: 16) {
            // 净资产（左对齐，卡片背景色）
            VStack(alignment: .leading, spacing: 8) {
                Text("净资产")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(formatAmount(netWorth))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)

                if !futureTransactions.isEmpty {
                    // 净资产变化 = 资产变化 + 负债变化（因为负债变化是负数）
                    let netWorthChange = estimatedAssetsChange + estimatedLiabilitiesChange
                    HStack(spacing: 4) {
                        Text("不包含未来 \(futureTransactions.count) 笔交易")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if netWorthChange != 0 {
                            Text(", 未来预估净资产\(netWorthChange > 0 ? "增加" : "减少")\(formatChangeAmount(netWorthChange))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 4)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(10)

            // 总资产和总负债
            HStack(spacing: 20) {
                // 总资产
                VStack(alignment: .leading, spacing: 4) {
                    Text("总资产")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(totalAssets))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if !futureTransactions.isEmpty && estimatedAssetsChange != 0 {
                        Text("不包含未来预估\(estimatedAssetsChange > 0 ? "增加" : "减少")\(formatChangeAmount(estimatedAssetsChange))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 总负债
                VStack(alignment: .leading, spacing: 4) {
                    Text("总负债")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatAmount(totalLiabilities))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if !futureTransactions.isEmpty && estimatedLiabilitiesChange != 0 {
                        Text("不包含未来预估\(estimatedLiabilitiesChange > 0 ? "增加" : "减少")\(formatChangeAmount(estimatedLiabilitiesChange))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(uiColor: .white))
        .cornerRadius(12)
        .shadow(color: Color(uiColor: .black).opacity(0.05), radius: 3, x: 0, y: 1)
        .onAppear {
            titleColorHex = AppSettings.shared.titleColorHex
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
            titleColorHex = AppSettings.shared.titleColorHex
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }

    private func formatChangeAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        let absAmount = abs(amount)
        let prefix = amount >= 0 ? "+" : ""
        return prefix + (formatter.string(from: NSDecimalNumber(decimal: absAmount)) ?? "¥0")
    }

    private func formatEstimatedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 资产趋势图卡片
struct AssetTrendChart: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedTimeRange: AssetsView.TimeRange

    /// 获取趋势数据
    private var trendData: [AssetDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        // 确定时间范围
        let (startDate, numberOfPoints, grouping): (Date, Int, Calendar.Component) = switch selectedTimeRange {
        case .week:
            (calendar.date(byAdding: .day, value: -7, to: now) ?? now, 7, .day)
        case .month:
            (calendar.date(byAdding: .month, value: -1, to: now) ?? now, 4, .weekOfMonth)
        case .year:
            (calendar.date(byAdding: .year, value: -1, to: now) ?? now, 12, .month)
        }

        var dataPoints: [AssetDataPoint] = []

        // 获取所有交易记录
        let allTransactions = DataManager.shared.getAllTransactions()

        for i in 0..<numberOfPoints {
            // 计算当前时间点的结束日期
            let endDate: Date = switch selectedTimeRange {
            case .week:
                calendar.date(byAdding: .day, value: -i, to: now) ?? now
            case .month:
                calendar.date(byAdding: .weekOfYear, value: -i, to: now) ?? now
            case .year:
                calendar.date(byAdding: .month, value: -i, to: now) ?? now
            }

            // 计算当前时间点的开始日期
            let startPointDate: Date = switch selectedTimeRange {
            case .week:
                calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
            case .month:
                calendar.date(byAdding: .weekOfYear, value: -1, to: endDate) ?? endDate
            case .year:
                calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
            }

            // 计算该时间点的资产
            let accounts = DataManager.shared.getAllAccounts()
            var netWorth: Decimal = 0
            var totalAssets: Decimal = 0
            var totalLiabilities: Decimal = 0

            for account in accounts {
                switch account.type {
                case .asset:
                    totalAssets += account.balance
                case .liability:
                    totalLiabilities += account.balance  // 负债余额现在是负数
                case .income, .expense:
                    break
                }
            }

            // 净资产 = 总资产 + 总负债（因为负债余额已经是负数了）
            // 例如：资产10000 + 负债(-2000) = 净资产8000
            netWorth = totalAssets + totalLiabilities

            // 应用该时间点之前的交易影响
            let periodTransactions = allTransactions.filter { transaction in
                transaction.createdAt < endDate && transaction.createdAt >= startPointDate
            }

            for transaction in periodTransactions {
                // 这里简化处理，实际应该根据历史状态计算
                // 由于没有历史快照，我们暂时只显示当前状态
            }

            let label = formatLabel(endDate)
            let dataPoint = AssetDataPoint(
                date: endDate,
                label: label,
                netWorth: netWorth,
                totalAssets: totalAssets,
                totalLiabilities: totalLiabilities
            )

            dataPoints.append(dataPoint)
        }

        return dataPoints.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 时间范围选择器
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(AssetsView.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            // 趋势图
            if trendData.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("暂无数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // 图例
                    HStack(spacing: 16) {
                        LegendItem(color: .blue, label: "净资产")
                        LegendItem(color: .green, label: "总资产")
                        LegendItem(color: .red, label: "总负债")
                        Spacer()
                    }
                    .font(.caption)
                    .padding(.horizontal, 4)

                    // 图表
                    Chart {
                        ForEach(trendData, id: \.date) { point in
                            // 净资产线
                            LineMark(
                                x: .value("时间", point.label),
                                y: .value("净资产", point.netWorth)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                            // 总资产线
                            LineMark(
                                x: .value("时间", point.label),
                                y: .value("总资产", point.totalAssets)
                            )
                            .foregroundStyle(.green)
                            .interpolationMethod(.catmullRom)

                            // 总负债线
                            LineMark(
                                x: .value("时间", point.label),
                                y: .value("总负债", point.totalLiabilities)
                            )
                            .foregroundStyle(.red)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(formatAmount(Decimal(doubleValue)))
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom) { _ in
                            AxisValueLabel()
                                .font(.caption2)
                            AxisGridLine()
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding()
        .background(Color(uiColor: .white))
        .cornerRadius(12)
        .shadow(color: Color(uiColor: .black).opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func formatLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedTimeRange {
        case .week:
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        case .month:
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        case .year:
            formatter.dateFormat = "M月"
            return formatter.string(from: date)
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 资产数据点
struct AssetDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let netWorth: Decimal
    let totalAssets: Decimal
    let totalLiabilities: Decimal
}

/// 图例项
struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

/// 账户列表切换器
struct AssetAccountSwitcher: View {
    @Binding var selectedTab: AssetsView.AssetTab
    let totalAssets: Decimal
    let totalLiabilities: Decimal

    var body: some View {
        VStack(spacing: 16) {
            // 切换器
            HStack(spacing: 8) {
                SwitcherButton(
                    title: "总资产",
                    amount: totalAssets,
                    isSelected: selectedTab == .asset
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .asset
                    }
                }

                SwitcherButton(
                    title: "总负债",
                    amount: totalLiabilities,
                    isSelected: selectedTab == .liability
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .liability
                    }
                }
            }

            // 选中项的详细金额（大字显示）
            VStack(spacing: 4) {
                Text(selectedTab == .asset ? "总资产" : "总负债")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(selectedTab == .asset ? formatAmount(totalAssets) : formatAmount(totalLiabilities))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(selectedTab == .asset ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
        .padding()
        .background(Color(uiColor: .white))
        .cornerRadius(12)
        .shadow(color: Color(uiColor: .black).opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 切换器按钮
struct SwitcherButton: View {
    let title: String
    let amount: Decimal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(hex: AppSettings.shared.titleColorHex))

                Text(formatAmount(amount))
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : Color(hex: AppSettings.shared.titleColorHex).opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: AppSettings.shared.titleColorHex) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 资产/负债切换卡片（已废弃）
struct AssetLiabilityCard: View {
    @Binding var selectedTab: AssetsView.AssetTab
    let netWorth: Decimal
    let totalAssets: Decimal
    let totalLiabilities: Decimal

    var body: some View {
        VStack(spacing: 12) {
            // 第一行：净资产标签
            Text("净资产")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 第二行：净资产金额
            Text(formatAmount(netWorth))
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 第三行：总资产/总负债切换器
            HStack(spacing: 0) {
                ForEach(AssetsView.AssetTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? Color(hex: AppSettings.shared.titleColorHex) : .secondary)

                            // 指示器
                            Rectangle()
                                .fill(Color(hex: AppSettings.shared.titleColorHex))
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                                .opacity(selectedTab == tab ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 第四行：随切换变化的金额
            Text(selectedTab == .asset ? formatAmount(totalAssets) : formatAmount(totalLiabilities))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(selectedTab == .asset ? .green : .red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(uiColor: .white))
        .cornerRadius(12)
        .shadow(color: Color(uiColor: .black).opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
}

/// 净资产卡片
struct NetWorthCard: View {
    let netWorth: Decimal
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex

    var body: some View {
        VStack(spacing: 12) {
            Text("总资产")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))

            Text(formatAmount(netWorth))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(hex: titleColorHex))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            titleColorHex = AppSettings.shared.titleColorHex
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
            titleColorHex = AppSettings.shared.titleColorHex
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
}

/// 账户列表
struct AccountListView: View {
    let accounts: [Account]
    let selectedTab: AssetsView.AssetTab
    @State private var showingCategorySort = false
    @Query private var categories: [AssetCategory]

    /// 按分类分组
    var groupedAccounts: [AccountGroupItem] {
        // 按分类分组
        let grouped = Dictionary(grouping: accounts) { account -> AssetCategory? in
            return account.category
        }

        // 获取当前账户类型对应的所有分组
        let accountType = selectedTab == .asset ? AccountType.asset : AccountType.liability
        let typeCategories = categories.filter { $0.accountType == accountType }

        // 使用排序顺序
        let savedOrder = AppSettings.shared.categoryOrder
        let sortedCategories = typeCategories.sorted { cat1, cat2 in
            let index1 = savedOrder.firstIndex(of: cat1.name) ?? Int.max
            let index2 = savedOrder.firstIndex(of: cat2.name) ?? Int.max
            return index1 < index2
        }

        // 按排序顺序返回已分组的账户
        var result: [AccountGroupItem] = sortedCategories.compactMap { category in
            grouped[category].map { accounts in
                AccountGroupItem(id: category.id, category: category, accounts: accounts)
            }
        }

        // 添加未分类账户(如果有)
        if let uncategorizedAccounts = grouped[nil], !uncategorizedAccounts.isEmpty {
            result.append(AccountGroupItem(id: UUID(), category: nil, accounts: uncategorizedAccounts))
        }

        return result
    }

/// 账户分组项
struct AccountGroupItem: Identifiable {
    let id: UUID
    let category: AssetCategory?
    let accounts: [Account]
}

    var body: some View {
        VStack(spacing: 16) {
            if accounts.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("暂无账户")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("点击左上角 + 添加账户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // 账户卡片（包含标题和分组）
                VStack(spacing: 0) {
                    // 卡片标题
                    HStack {
                        Text(selectedTab == .asset ? "资产账户" : "负债账户")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        // 分组排序按钮
                        Button(action: {
                            showingCategorySort = true
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(width: 36, height: 36)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // 分组分隔线
                    Divider()
                        .padding(.leading, 16)

                    // 账户列表（所有分组在一个卡片中）
                    VStack(spacing: 0) {
                        ForEach(groupedAccounts, id: \.id) { groupItem in
                            AccountCategorySection(
                                category: groupItem.category,
                                accounts: groupItem.accounts,
                                selectedTab: selectedTab
                            )

                            // 分组分隔线（最后一个分组不显示）
                            if groupItem.id != groupedAccounts.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .background(Color(uiColor: .white))
                .cornerRadius(12)
                .shadow(color: Color(uiColor: .black).opacity(0.05), radius: 3, x: 0, y: 1)
            }
        }
        .sheet(isPresented: $showingCategorySort) {
            CategorySortView(
                accountType: selectedTab == .asset ? .asset : .liability
            )
        }
    }
}

/// 统一添加账户视图
struct UnifiedAddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: AccountType = .asset
    @State private var selectedCategory: AssetCategory?
    @State private var accountName = ""
    @State private var currencyCode = "CNY"
    @State private var icon = "folder"
    @State private var initialBalance = ""
    @State private var note = ""
    @State private var showingIconPicker = false
    @State private var isSaving = false

    @Query private var categories: [AssetCategory]
    private let currencies = Currency.defaultCurrencies

    var availableCategories: [AssetCategory] {
        categories.filter { $0.accountType == selectedType }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var isValid: Bool {
        !accountName.isEmpty && selectedCategory != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // 账户类型
                Section("账户类型") {
                    Picker("类型", selection: $selectedType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Text(type.description).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedType) { _, _ in
                        // 切换账户类型时，重置分组为该类型的第一个分组
                        selectedCategory = availableCategories.first
                    }
                }

                // 分组类型
                Section("分组类型") {
                    Picker("分组", selection: $selectedCategory) {
                        ForEach(availableCategories) { category in
                            Text(category.name).tag(category as AssetCategory?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        if selectedCategory == nil {
                            selectedCategory = availableCategories.first
                        }
                    }
                }

                // 账户信息
                Section("账户信息") {
                    TextField("账户名称", text: $accountName)

                    HStack {
                        Text("币种")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $currencyCode) {
                            ForEach(currencies) { currency in
                                Text("\(currency.symbol) \(currency.code)").tag(currency.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    TextField("初始余额", text: $initialBalance)
                        .keyboardType(.decimalPad)
                }

                // 图标
                Section("图标") {
                    Button(action: {
                        showingIconPicker = true
                    }) {
                        HStack {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            Text("选择图标")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }

                // 备注
                Section("备注") {
                    TextField("选填", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中..." : "保存") {
                        saveAccount()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .disabled(isSaving)
            .sheet(isPresented: $showingIconPicker) {
                IconPicker(selectedIcon: $icon)
            }
        }
    }

    private func saveAccount() {
        guard let category = selectedCategory else { return }

        isSaving = true

        do {
            // 获取当前分类下的最大orderIndex
            let descriptor = FetchDescriptor<Account>()
            let existingAccounts = (try? modelContext.fetch(descriptor)) ?? []
            let categoryAccounts = existingAccounts.filter {
                $0.category?.id == category.id
            }
            let maxOrderIndex = categoryAccounts.map { $0.orderIndex }.max() ?? -1

            let initialBalanceValue = Decimal(string: initialBalance) ?? 0

            let account = Account(
                name: accountName,
                type: selectedType,
                category: category,
                balance: initialBalanceValue,
                initialBalance: initialBalanceValue,
                currencyCode: currencyCode,
                icon: icon,
                note: note,
                orderIndex: maxOrderIndex + 1
            )

            modelContext.insert(account)
            try modelContext.save()

            // 保存成功，关闭视图
            dismiss()
        } catch {
            isSaving = false
            print("Error: \(error.localizedDescription)")
        }
    }
}

/// 快速添加账户视图
struct QuickAddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let accountType: AccountType

    @State private var name = ""
    @State private var initialBalance = ""
    @State private var currencyCode = "CNY"
    @State private var icon = "folder"
    @State private var note = ""
    @State private var selectedCategory: AssetCategory?
    @State private var showingIconPicker = false
    @State private var isSaving = false

    @Query private var categories: [AssetCategory]
    private let currencies = Currency.defaultCurrencies

    var availableCategories: [AssetCategory] {
        categories.filter { $0.accountType == accountType }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账户信息") {
                    TextField("账户名称", text: $name)

                    Picker("分类", selection: $selectedCategory) {
                        Text("请选择").tag(nil as AssetCategory?)
                        ForEach(availableCategories) { category in
                            Text(category.name).tag(category as AssetCategory?)
                        }
                    }

                    Picker("币种", selection: $currencyCode) {
                        ForEach(currencies, id: \.code) { currency in
                            Text("\(currency.symbol) \(currency.code)").tag(currency.code)
                        }
                    }

                    TextField("初始余额", text: $initialBalance)
                        .keyboardType(.decimalPad)
                }

                Section("图标") {
                    Button(action: {
                        showingIconPicker = true
                    }) {
                        HStack {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 40)
                            Text("选择图标")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }

                Section("备注") {
                    TextField("选填", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("添加账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中..." : "保存") {
                        saveAccount()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .disabled(isSaving)
            .sheet(isPresented: $showingIconPicker) {
                IconPicker(selectedIcon: $icon)
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && selectedCategory != nil
    }

    private func saveAccount() {
        guard let category = selectedCategory,
              let initialBalanceValue = Decimal(string: initialBalance) else {
            return
        }

        isSaving = true

        // 获取同类账户的最大 orderIndex
        do {
            let typeRawValue = accountType.rawValue
            let descriptor = FetchDescriptor<Account>(
                predicate: #Predicate<Account> { account in
                    account.typeRawValue == typeRawValue
                }
            )
            let sameTypeAccounts = try modelContext.fetch(descriptor)
            let maxOrderIndex = sameTypeAccounts.map { $0.orderIndex }.max() ?? -1

            let account = Account(
                name: name,
                type: accountType,
                category: category,
                balance: initialBalanceValue,
                initialBalance: initialBalanceValue,
                currencyCode: currencyCode,
                icon: icon,
                note: note,
                orderIndex: maxOrderIndex + 1
            )

            modelContext.insert(account)
            try modelContext.save()

            // 保存成功，关闭视图
            dismiss()
        } catch {
            isSaving = false
            print("Error: \(error.localizedDescription)")
        }
    }
}

/// 图标选择器
struct IconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    private let icons = [
        "folder", "banknote", "creditcard", "house", "car",
        "laptopcomputer", "gamecontroller", "airplane", "gift.fill",
        "heart.fill", "star.fill", "book.fill", "bag.fill",
        "cart.fill", "phone.fill", "tv.fill", "desktopcomputer",
        "bicycle", "tram.fill", "chart.bar.fill",
        "chart.line.uptrend.xyaxis", "chart.pie.fill"
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 120), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(icons, id: \.self) { iconName in
                        IconPickerButton(
                            iconName: iconName,
                            isSelected: selectedIcon == iconName,
                            action: {
                                selectedIcon = iconName
                                dismiss()
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 图标按钮组件
struct IconPickerButton: View {
    let iconName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 60, height: 60)
                .background(isSelected ? Color.blue : Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

/// 账户分类区块
struct AccountCategorySection: View {
    let category: AssetCategory?
    let accounts: [Account]
    let selectedTab: AssetsView.AssetTab
    @State private var isExpanded = true
    @State private var accountsList: [Account]

    init(category: AssetCategory?, accounts: [Account], selectedTab: AssetsView.AssetTab) {
        self.category = category
        self.accounts = accounts
        self.selectedTab = selectedTab
        self._accountsList = State(initialValue: accounts.sorted { $0.orderIndex < $1.orderIndex })
    }

    /// 分类名称
    private var categoryName: String {
        category?.name ?? "未分类"
    }

    private var categoryBalance: Decimal {
        accounts.reduce(0) { total, account in
            if account.type == .liability {
                // 负债：余额已经是负数
                return total + account.balance
            } else {
                // 资产：直接相加
                return total + account.balance
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 账户分类标题（可点击折叠/展开）
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    // 折叠图标
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16)

                    // 分类名称
                    Text("\(categoryName)(\(accounts.count))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    // 余额统计
                    if selectedTab == .asset {
                        Text("余额：\(formatAmount(categoryBalance))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("负债：\(formatAmount(categoryBalance))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .buttonStyle(PlainButtonStyle())

            // 账户列表（根据展开状态显示）
            if isExpanded {
                List {
                    ForEach(accountsList) { account in
                        AccountCard(account: account)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(uiColor: .white))
                    }
                    .onMove { source, destination in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            accountsList.move(fromOffsets: source, toOffset: destination)
                            updateOrderIndices()
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(accountsList.count) * 72) // 固定高度防止滚动冲突
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4) // 给顶部和底部留一点空间
    }

    private func updateOrderIndices() {
        for (index, account) in accountsList.enumerated() {
            account.orderIndex = index
        }
        try? accounts.first?.modelContext?.save()
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 单个账户卡片
struct AccountCard: View {
    let account: Account
    @State private var showingDetail = false

    init(account: Account) {
        self.account = account
    }

    var body: some View {
        HStack(spacing: 14) {
            // 图标（圆角方形）
            Image(systemName: account.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue)
                )

            // 信息
            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if !account.note.isEmpty {
                    Text(account.note)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 余额
            VStack(alignment: .trailing, spacing: 3) {
                Text(account.formattedBalance)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(balanceColor)

                // 如果是非默认币种，显示换算
                if account.currencyCode != AppSettings.shared.defaultCurrencyCode {
                    Text("≈ \(AppSettings.shared.defaultCurrency.symbol)\(AppSettings.shared.convertToDefault(amount: account.balance, from: account.currencyCode))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .frame(minHeight: 68)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            AccountDetailView(account: account)
        }
    }

    private var balanceColor: Color {
        if account.balance < 0 {
            return .red
        }
        return .primary
    }
}

/// 账户详情视图
struct AccountDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: Account
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex
    @State private var showingDeleteAlert = false
    @State private var showingEditAccount = false

    @Query private var transactions: [Transaction]

    private let dataManager = DataManager.shared

    enum TimeFilter: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case week = "本周"
        case month = "本月"
        case custom = "自定义"
    }

    var filteredTransactions: [Transaction] {
        let now = Date()
        let calendar = Calendar.current

        return transactions.filter { transaction in
            // 筛选与该账户相关的交易
            transaction.fromAccountId == account.id || transaction.toAccountId == account.id
        }.filter { transaction in
            // 筛选时间
            switch selectedTimeFilter {
            case .all:
                return true
            case .today:
                return calendar.isDateInToday(transaction.createdAt)
            case .week:
                return transaction.createdAt >= calendar.date(byAdding: .day, value: -7, to: now)!
            case .month:
                return calendar.isDate(transaction.createdAt, equalTo: now, toGranularity: .month)
            case .custom:
                return true // 自定义时间筛选逻辑可以在这里扩展
            }
        }.sorted { $0.createdAt > $1.createdAt }
    }

    var statistics: AccountStatistics {
        var inflow: Decimal = 0
        var outflow: Decimal = 0

        for transaction in filteredTransactions {
            if transaction.toAccountId == account.id {
                // 流入
                inflow += transaction.amount
            }
            if transaction.fromAccountId == account.id {
                // 流出
                outflow += transaction.amount
            }
        }

        return AccountStatistics(inflow: inflow, outflow: outflow)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 交易列表
                    transactionList
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Text("删除账户")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("删除账户", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteAccount()
                    dismiss()
                }
            } message: {
                let transactionCount = dataManager.getTransactions(for: account).count
                if transactionCount > 0 {
                    Text("该账户有 \(transactionCount) 笔交易，删除账户将同时删除这些交易，此操作不可恢复。\n\n确定要删除账户「\(account.name)」吗？")
                } else {
                    Text("确定要删除账户「\(account.name)」吗？删除后无法恢复。")
                }
            }
            .onAppear {
                titleColorHex = AppSettings.shared.titleColorHex
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
                titleColorHex = AppSettings.shared.titleColorHex
            }
        }
        .sheet(isPresented: $showingEditAccount) {
            EditAccountForm(account: account)
        }
        .overlay(alignment: .top) {
            headerCard
                .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    var headerCard: some View {
        VStack(spacing: 0) {
            // 账户名称和余额
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("余额: \(account.formattedBalance)")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                // 操作按钮组
                HStack(spacing: 8) {
                    // 编辑按钮
                    Button(action: {
                        showingEditAccount = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    // 删除按钮
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.3))
                            .clipShape(Circle())
                    }
                }

                if !account.note.isEmpty {
                    Text(account.note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // 资金流入流出
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("流入")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(formatAmount(statistics.inflow))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("流出")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(formatAmount(statistics.outflow))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // 时间筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TimeFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTimeFilter = filter
                            }
                        }) {
                            Text(filter.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedTimeFilter == filter ? Color(uiColor: .white).opacity(0.2) : Color.clear)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .background(Color(hex: titleColorHex))
    }

    var transactionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if filteredTransactions.isEmpty {
                Text("暂无交易记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredTransactions) { transaction in
                        AccountTransactionRow(transaction: transaction, account: account)
                        if transaction.id != filteredTransactions.last?.id {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(Color(uiColor: .white))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                )
            }
        }
        .padding(.top, 180) // 为固定头部留出空间
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let currency = Currency.defaultCurrencies.first { $0.code == account.currencyCode }
            ?? Currency(code: account.currencyCode, symbol: "?", name: account.currencyCode)
        return currency.format(amount)
    }

    private func deleteAccount() {
        dataManager.deleteAccountWithTransactions(account)
    }
}

/// 账户统计数据
struct AccountStatistics {
    let inflow: Decimal
    let outflow: Decimal
}

/// 账户交易行
struct AccountTransactionRow: View {
    @Environment(\.modelContext) private var modelContext

    let transaction: Transaction
    let account: Account

    var isInflow: Bool {
        transaction.toAccountId == account.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // 图标（不区分颜色）
            Image(systemName: isInflow ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(getTransactionDescription())
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(formatDate(transaction.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 金额（不区分颜色）
            Text("\(isInflow ? "+" : "-")\(transaction.formattedAmount)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func getTransactionDescription() -> String {
        guard let fromAccount = transaction.getFromAccount(context: modelContext),
              let toAccount = transaction.getToAccount(context: modelContext) else {
            return "交易"
        }

        if isInflow {
            return "从 \(fromAccount.name) 收入"
        } else {
            return "支出到 \(toAccount.name)"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

/// 账户分布环形图
struct AssetDistributionChart: View {
    let accounts: [Account]
    let selectedTab: AssetsView.AssetTab

    /// 分类数据（包含该分类下的所有账户）
    private var categoryData: [CategoryDistribution] {
        // 只处理有分类的账户
        let accountsWithCategories = accounts.filter { $0.category != nil }

        // 按分类分组
        let grouped = Dictionary(grouping: accountsWithCategories) { account -> AssetCategory in
            account.category!
        }

        return grouped.map { (category, accountsInCategory) in
            let categoryTotal = accountsInCategory.reduce(0) { $0 + $1.balance }
            return CategoryDistribution(
                category: category,
                totalAmount: categoryTotal,
                accounts: accountsInCategory.sorted { $0.balance > $1.balance }
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
    }

    /// 总金额
    private var totalAmount: Decimal {
        accounts.reduce(0) { $0 + $1.balance }
    }

    /// 彩虹颜色
    private var rainbowColors: [Color] {
        [
            Color(red: 1.0, green: 0.2, blue: 0.2),    // 红
            Color(red: 1.0, green: 0.6, blue: 0.0),    // 橙
            Color(red: 1.0, green: 1.0, blue: 0.0),    // 黄
            Color(red: 0.2, green: 1.0, blue: 0.2),    // 绿
            Color(red: 0.0, green: 0.6, blue: 1.0),    // 蓝
            Color(red: 0.4, green: 0.2, blue: 1.0),    // 靛
            Color(red: 0.7, green: 0.0, blue: 0.7),    // 紫
            Color(red: 1.0, green: 0.0, blue: 1.0),    // 品红
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text("\(selectedTab == .asset ? "资产" : "负债")分布")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            if categoryData.isEmpty {
                // 空状态
                VStack(spacing: 16) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: selectedTab == .asset ? "folder.badge.questionmark" : "creditcard.trianglebadge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }

                    // 文字说明
                    VStack(spacing: 8) {
                        Text("暂无\(selectedTab == .asset ? "资产" : "负债")分布")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text(selectedTab == .asset ? "添加资产账户并设置分组后，这里将显示您的资产分布情况" : "添加负债账户并设置分组后，这里将显示您的负债分布情况")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
            } else {
                // 环形图和图例（左右排列）
                HStack(spacing: 20) {
                    // 左侧：环形图
                    ZStack {
                        // 背景圆环
                        Circle()
                            .stroke(Color(uiColor: .systemGray6), lineWidth: 20)
                            .frame(width: 140, height: 140)

                        // 数据圆环（按分类）
                        ForEach(Array(categoryData.enumerated()), id: \.element.id) { index, item in
                            let startAngle = startAngle(for: index)
                            let endAngle = endAngle(for: index)
                            let color = rainbowColors[index % rainbowColors.count]

                            Circle()
                                .trim(from: startAngle, to: endAngle)
                                .stroke(
                                    LinearGradient(
                                        colors: [color, color.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 20, lineCap: .butt)
                                )
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))
                        }

                        // 中心文字
                        VStack(spacing: 2) {
                            Text("总计")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatAmount(totalAmount))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(width: 140, height: 140)

                    // 右侧：图例
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(categoryData.enumerated()), id: \.element.id) { index, categoryItem in
                                CategoryLegendRow(
                                    category: categoryItem.category,
                                    categoryAmount: categoryItem.totalAmount,
                                    accounts: categoryItem.accounts,
                                    color: rainbowColors[index % rainbowColors.count],
                                    overallTotal: totalAmount
                                )

                                if index < categoryData.count - 1 {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(uiColor: .white))
        .cornerRadius(12)
        .shadow(color: Color(uiColor: .black).opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func startAngle(for index: Int) -> Double {
        var accumulated: Decimal = 0
        for i in 0..<index {
            accumulated += categoryData[i].totalAmount
        }
        return totalAmount > 0 ? Double(truncating: accumulated / totalAmount as NSNumber) : 0
    }

    private func endAngle(for index: Int) -> Double {
        var accumulated: Decimal = 0
        for i in 0...index {
            accumulated += categoryData[i].totalAmount
        }
        return totalAmount > 0 ? Double(truncating: accumulated / totalAmount as NSNumber) : 0
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 分类分布数据
struct CategoryDistribution: Identifiable {
    let id = UUID()
    let category: AssetCategory
    let totalAmount: Decimal
    let accounts: [Account]
}

/// 分类图例行
struct CategoryLegendRow: View {
    let category: AssetCategory
    let categoryAmount: Decimal
    let accounts: [Account]
    let color: Color
    let overallTotal: Decimal // 总金额用于计算百分比

    var body: some View {
        HStack(spacing: 8) {
            // 色块
            Rectangle()
                .fill(color)
                .frame(width: 4, height: 40)
                .cornerRadius(2)

            // 分类信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    // 金额
                    Text(formatAmount(categoryAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    // 百分比
                    let percentage = overallTotal > 0 ? (categoryAmount / overallTotal * 100) : 0
                    Text(String(format: "%.1f%%", Double(truncating: percentage as NSNumber)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 账户数量
                Text("\(accounts.count) 个账户")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }

    private func formatAccountAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}

/// 分组排序视图
struct CategorySortView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let accountType: AccountType

    @Query private var categories: [AssetCategory]
    @Query private var accounts: [Account]

    @State private var showingAddCategory = false
    @State private var editingCategory: AssetCategory?
    @State private var categoryToDelete: AssetCategory?
    @State private var showingDeleteAlert = false

    var filteredCategories: [AssetCategory] {
        categories.filter { $0.accountType == accountType }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("拖动调整分组显示顺序，点击编辑，左滑删除")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    ForEach(filteredCategories) { category in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            Text(category.name)
                                .font(.subheadline)

                            Spacer()

                            Text("\(getAccountCount(for: category))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingCategory = category
                        }
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            categoryToDelete = filteredCategories[index]
                            showingDeleteAlert = true
                        }
                    }
                    .onMove { source, destination in
                        withAnimation {
                            var reordered = filteredCategories
                            reordered.move(fromOffsets: source, toOffset: destination)
                            updateOrderIndices(reordered)
                        }
                    }
                }
            }
            .navigationTitle("分组排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddCategory = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView(accountType: accountType)
            }
            .sheet(item: $editingCategory) { category in
                EditCategoryView(category: category)
            }
            .alert("删除分组", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {
                    categoryToDelete = nil
                }
                Button("删除", role: .destructive) {
                    deleteCategory()
                }
            } message: {
                if let category = categoryToDelete {
                    let accountCount = getAccountCount(for: category)
                    Text("确定要删除分组「\(category.name)」吗？该分组下有 \(accountCount) 个账户，删除分组后这些账户将变为未分类状态。")
                }
            }
            .onDisappear {
                // 保存排序顺序
                AppSettings.shared.saveCategoryOrder(filteredCategories)
            }
        }
    }

    private func getAccountCount(for category: AssetCategory) -> Int {
        accounts.filter { $0.category?.id == category.id }.count
    }

    private func updateOrderIndices(_ reordered: [AssetCategory]) {
        for (index, category) in reordered.enumerated() {
            category.orderIndex = index
        }

        try? modelContext.save()
    }

    private func deleteCategory() {
        guard let category = categoryToDelete else { return }

        // 将该分类下的所有账户的分类设置为nil
        let accountsInCategory = accounts.filter { $0.category?.id == category.id }
        for account in accountsInCategory {
            account.category = nil
        }

        // 删除分类
        modelContext.delete(category)
        try? modelContext.save()

        categoryToDelete = nil
    }
}

/// 添加分组视图
struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let accountType: AccountType

    @State private var categoryName = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("分组信息") {
                    TextField("分组名称", text: $categoryName)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("添加分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中..." : "保存") {
                        saveCategory()
                    }
                    .disabled(categoryName.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveCategory() {
        isSaving = true

        do {
            // 获取当前类型的最大 orderIndex
            let descriptor = FetchDescriptor<AssetCategory>()
            let existingCategories = try modelContext.fetch(descriptor)
            let typeCategories = existingCategories.filter { $0.accountType == accountType }
            let maxOrderIndex = typeCategories.map { $0.orderIndex }.max() ?? -1

            let category = AssetCategory(
                name: categoryName,
                accountType: accountType,
                orderIndex: maxOrderIndex + 1
            )

            modelContext.insert(category)
            try modelContext.save()

            dismiss()
        } catch {
            isSaving = false
            print("Error: \(error.localizedDescription)")
        }
    }
}

/// 编辑分组视图
struct EditCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let category: AssetCategory

    @State private var categoryName: String
    @State private var isSaving = false

    init(category: AssetCategory) {
        self.category = category
        self._categoryName = State(initialValue: category.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("分组信息") {
                    TextField("分组名称", text: $categoryName)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("编辑分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中..." : "保存") {
                        saveCategory()
                    }
                    .disabled(categoryName.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveCategory() {
        isSaving = true

        do {
            category.name = categoryName
            try modelContext.save()

            dismiss()
        } catch {
            isSaving = false
            print("Error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    AssetsView()
}
