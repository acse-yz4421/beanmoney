//
//  StatisticsView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataManager = DataManager()
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedTab: StatisticsTab = .income
    @State private var showingCustomDateRange = false

    enum TimePeriod: String, CaseIterable {
        case week = "周"
        case month = "月"
        case year = "年"
        case custom = "自定义"
    }

    enum StatisticsTab: String, CaseIterable {
        case income = "资产总增加"
        case expense = "资产总减少"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // 统计概览卡片（包含时间切换器和统计切换器）
                        StatisticsOverviewCard(
                            selectedPeriod: $selectedPeriod,
                            selectedTab: $selectedTab
                        )

                        // 统计卡片（环形图）
                        StatisticsCards(period: selectedPeriod, selectedTab: $selectedTab)
                    }
                    .padding()
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingCustomDateRange) {
            CustomDateRangeSheet(selectedPeriod: $selectedPeriod)
        }
    }
}

/// 统计卡片
struct StatisticsCards: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataManager = DataManager()
    let period: StatisticsView.TimePeriod
    @Binding var selectedTab: StatisticsView.StatisticsTab

    private var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (weekAgo, now)
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (monthAgo, now)
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (yearAgo, now)
        case .custom:
            // 自定义日期范围（默认使用过去一个月）
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (monthAgo, now)
        }
    }

    private var transactions: [Transaction] {
        dataManager.getTransactions(from: dateRange.start, to: dateRange.end)
    }

    /// 按账户分组的统计数据
    private var groupedStatistics: [AccountGroupStatistic] {
        let filteredTransactions: [Transaction]

        switch selectedTab {
        case .income:
            // 资产总增加：按来源账户分组
            filteredTransactions = transactions.filter { $0.isAssetIncrease(context: modelContext) }
        case .expense:
            // 资产总减少：按去向账户分组
            filteredTransactions = transactions.filter { $0.isAssetDecrease(context: modelContext) }
        }

        // 按账户ID分组
        let grouped = Dictionary(grouping: filteredTransactions) { transaction -> UUID in
            switch selectedTab {
            case .income:
                return transaction.fromAccountId
            case .expense:
                return transaction.toAccountId
            }
        }

        // 转换为统计数组
        return grouped.map { (accountId, transactions) in
            let totalAmount = transactions.reduce(0) { $0 + $1.amount }
            let account = dataManager.getAccount(byId: accountId)
            return AccountGroupStatistic(
                account: account,
                totalAmount: totalAmount,
                transactionCount: transactions.count,
                transactions: transactions.sorted { $0.createdAt > $1.createdAt }
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
    }

    private var totalAmount: Decimal {
        groupedStatistics.reduce(0) { $0 + $1.totalAmount }
    }

    var body: some View {
        // 环比图
        TrendChart(
            transactions: transactions,
            selectedTab: selectedTab,
            period: period
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
}

/// 账户分组统计数据
struct AccountGroupStatistic {
    let account: Account?
    let totalAmount: Decimal
    let transactionCount: Int
    let transactions: [Transaction]
}

/// 账户分组统计行
struct AccountGroupStatisticRow: View {
    @Environment(\.modelContext) private var modelContext
    let statistic: AccountGroupStatistic
    let selectedTab: StatisticsView.StatisticsTab
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主行（可点击展开）
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // 图标
                    if let account = statistic.account {
                        Image(systemName: account.icon)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    } else {
                        Image(systemName: "questionmark.circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }

                    // 信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statistic.account?.name ?? "未知账户")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text("\(statistic.transactionCount) 笔交易")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 金额和箭头
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatAmount(statistic.totalAmount))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedTab == .income ? .green : .red)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            // 展开的交易列表
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.leading, 68)

                    ForEach(Array(statistic.transactions.enumerated()), id: \.element.id) { index, transaction in
                        GroupedTransactionRow(transaction: transaction, selectedTab: selectedTab)
                        if index < statistic.transactions.count - 1 {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
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

/// 分组交易行
struct GroupedTransactionRow: View {
    @Environment(\.modelContext) private var modelContext
    let transaction: Transaction
    let selectedTab: StatisticsView.StatisticsTab
    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 12) {
            // 占位图标（与上层对齐）
            Spacer()
                .frame(width: 40)

            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(getDescription())
                        .font(.caption)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(transaction.formattedAmount)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    // 箭头图标
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                }

                Text(formatDate(transaction.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                showingDetail = true
            }
        }
        .sheet(isPresented: $showingDetail) {
            TransactionDetailView(transaction: transaction)
        }
    }

    private func getDescription() -> String {
        switch selectedTab {
        case .income:
            // 资产总增加：显示去向账户
            if let toAccount = transaction.getToAccount(context: modelContext) {
                return "到 \(toAccount.name)"
            }
        case .expense:
            // 资产总减少：显示来源账户
            if let fromAccount = transaction.getFromAccount(context: modelContext) {
                return "从 \(fromAccount.name)"
            }
        }
        return "交易"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

/// 趋势图（环形图）
struct TrendChart: View {
    let transactions: [Transaction]
    let selectedTab: StatisticsView.StatisticsTab
    let period: StatisticsView.TimePeriod

    @Environment(\.modelContext) private var modelContext

    private var chartData: [AccountGroupStatistic] {
        let filteredTransactions: [Transaction]

        switch selectedTab {
        case .income:
            // 资产总增加：按来源账户分组
            filteredTransactions = transactions.filter { $0.isAssetIncrease(context: modelContext) }
        case .expense:
            // 资产总减少：按去向账户分组
            filteredTransactions = transactions.filter { $0.isAssetDecrease(context: modelContext) }
        }

        // 按账户ID分组
        let grouped = Dictionary(grouping: filteredTransactions) { transaction -> UUID in
            switch selectedTab {
            case .income:
                return transaction.fromAccountId
            case .expense:
                return transaction.toAccountId
            }
        }

        // 转换为统计数组
        let dataManager = DataManager()
        return grouped.map { (accountId, transactions) in
            let totalAmount = transactions.reduce(0) { $0 + $1.amount }
            let account = dataManager.getAccount(byId: accountId)
            return AccountGroupStatistic(
                account: account,
                totalAmount: totalAmount,
                transactionCount: transactions.count,
                transactions: transactions.sorted { $0.createdAt > $1.createdAt }
            )
        }.sorted { $0.totalAmount > $1.totalAmount }
    }

    private var totalAmount: Decimal {
        chartData.reduce(0) { $0 + $1.totalAmount }
    }

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
        VStack(spacing: 0) {
            // 卡片标题
            HStack {
                Text(selectedTab == .income ? "收入分类统计详情" : "支出分类统计详情")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))

            Divider()

            VStack(spacing: 16) {
                if chartData.isEmpty {
                    // 空状态
                    VStack(spacing: 12) {
                        Image(systemName: selectedTab == .income ? "chart.pie.fill" : "chart.pie")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text(selectedTab == .income ? "暂无收入数据" : "暂无支出数据")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)

                        Text("开始记账后，这里将显示分类统计")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // 环形图
                    ZStack {
                        // 背景圆环
                        Circle()
                            .stroke(Color(uiColor: .systemGray6), lineWidth: 25)
                            .frame(width: 200, height: 200)

                        // 数据圆环
                        ForEach(Array(chartData.enumerated()), id: \.element.account?.id) { index, item in
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
                                    style: StrokeStyle(lineWidth: 25, lineCap: .butt)
                                )
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(-90))
                        }

                        // 中心文字
                        VStack(spacing: 4) {
                            Text("总计")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(formatAmount(totalAmount))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.top, 20)

                    // 统计列表
                    VStack(spacing: 0) {
                        ForEach(Array(chartData.enumerated()), id: \.element.account?.id) { index, item in
                            DonutChartRow(
                                item: item,
                                color: rainbowColors[index % rainbowColors.count],
                                totalAmount: totalAmount,
                                transactions: item.transactions
                            )

                            if index < chartData.count - 1 {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func startAngle(for index: Int) -> Double {
        var accumulated: Decimal = 0
        for i in 0..<index {
            accumulated += chartData[i].totalAmount
        }
        return totalAmount > 0 ? Double(truncating: accumulated / totalAmount as NSNumber) : 0
    }

    private func endAngle(for index: Int) -> Double {
        var accumulated: Decimal = 0
        for i in 0...index {
            accumulated += chartData[i].totalAmount
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

/// 环形图统计行
struct DonutChartRow: View {
    let item: AccountGroupStatistic
    let color: Color
    let totalAmount: Decimal
    let transactions: [Transaction]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主行（可点击展开）
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // 色块
                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)

                    // 账户信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.account?.name ?? "未知")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Text("\(item.transactionCount) 笔交易")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 金额和百分比
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatAmount(item.totalAmount))
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        let percentage = totalAmount > 0 ? (item.totalAmount / totalAmount * 100) : 0
                        Text(String(format: "%.1f%%", Double(truncating: percentage as NSNumber)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 展开/折叠箭头
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            // 展开的交易列表
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.leading, 44)

                    ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                        DonutTransactionRow(transaction: transaction)
                        if index < transactions.count - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
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

/// 环形图交易行
struct DonutTransactionRow: View {
    let transaction: Transaction
    @State private var showingDetail = false

    var body: some View {
        HStack(spacing: 12) {
            // 占位
            Spacer()
                .frame(width: 44)

            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(transaction.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 金额
            Text(transaction.formattedAmount)
                .font(.caption)
                .foregroundColor(.primary)

            // 箭头图标
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TransactionDetailView(transaction: transaction)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

/// 图表数据点
struct ChartDataPoint {
    let date: Date
    let amount: Decimal
}

/// 统计切换器按钮
struct StatisticsSwitcherButton: View {
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

/// 统计概览卡片
struct StatisticsOverviewCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var dataManager = DataManager()
    @Binding var selectedPeriod: StatisticsView.TimePeriod
    @Binding var selectedTab: StatisticsView.StatisticsTab
    @State private var showingCustomDateRange = false

    private var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (weekAgo, now)
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (monthAgo, now)
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (yearAgo, now)
        case .custom:
            // 自定义日期范围应该从用户设置中读取
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (monthAgo, now)
        }
    }

    private var transactions: [Transaction] {
        dataManager.getTransactions(from: dateRange.start, to: dateRange.end)
    }

    private var totalIncome: Decimal {
        transactions.filter { $0.isAssetIncrease(context: modelContext) }
            .reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Decimal {
        transactions.filter { $0.isAssetDecrease(context: modelContext) }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(spacing: 16) {
            // 时间范围切换器
            HStack(spacing: 6) {
                ForEach(StatisticsView.TimePeriod.allCases.filter { $0 != .custom }, id: \.self) { period in
                    TimePeriodButton(
                        title: period.rawValue,
                        isSelected: selectedPeriod == period
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = period
                        }
                    }
                }

                // 自定义按钮
                Button(action: {
                    showingCustomDateRange = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text("自定义")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(selectedPeriod == .custom ? .white : Color(hex: AppSettings.shared.titleColorHex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(selectedPeriod == .custom ? Color(hex: AppSettings.shared.titleColorHex) : Color(hex: AppSettings.shared.titleColorHex).opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 4)

            Divider()
                .padding(.horizontal, 8)

            // 统计切换器
            HStack(spacing: 8) {
                StatisticsSwitcherButton(
                    title: "资产总增加",
                    amount: totalIncome,
                    isSelected: selectedTab == .income
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .income
                    }
                }

                StatisticsSwitcherButton(
                    title: "资产总减少",
                    amount: totalExpense,
                    isSelected: selectedTab == .expense
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .expense
                    }
                }
            }

            // 选中项的详细金额（大字显示）
            VStack(spacing: 4) {
                Text(selectedTab == .income ? "资产总增加" : "资产总减少")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(selectedTab == .income ? formatAmount(totalIncome) : formatAmount(totalExpense))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(selectedTab == .income ? .green : .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        .sheet(isPresented: $showingCustomDateRange) {
            CustomDateRangeSheet(selectedPeriod: $selectedPeriod)
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

/// 时间周期按钮
struct TimePeriodButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : Color(hex: AppSettings.shared.titleColorHex))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: AppSettings.shared.titleColorHex) : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 自定义日期范围选择器
struct CustomDateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPeriod: StatisticsView.TimePeriod
    @State private var startDate = Date()
    @State private var endDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("日期范围") {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                }

                Section {
                    Text("选择自定义的时间范围来查看统计数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("自定义时间范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        // 保存自定义日期范围
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    StatisticsView()
}
