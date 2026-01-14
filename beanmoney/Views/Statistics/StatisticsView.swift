//
//  StatisticsView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
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
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (monthAgo, now)
        }
    }

    func getTotalIncome(for period: TimePeriod) -> Decimal {
        let transactions = DataManager.shared.getTransactions(from: dateRange.start, to: dateRange.end)
        return transactions.filter { $0.isAssetIncrease(context: modelContext) }
            .reduce(0) { $0 + $1.amount }
    }

    func getTotalExpense(for period: TimePeriod) -> Decimal {
        let transactions = DataManager.shared.getTransactions(from: dateRange.start, to: dateRange.end)
        return transactions.filter { $0.isAssetDecrease(context: modelContext) }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // 时间选择器（独立置顶）
                        TimePeriodSelector(
                            selectedPeriod: $selectedPeriod,
                            showingCustomDateRange: $showingCustomDateRange
                        )

                        // 统计概览卡片（只包含统计切换器）
                        StatisticsOverviewCard(
                            selectedPeriod: $selectedPeriod,
                            selectedTab: $selectedTab,
                            totalIncome: getTotalIncome(for: selectedPeriod),
                            totalExpense: getTotalExpense(for: selectedPeriod)
                        )

                        // 趋势和分类统计合并卡片
                        CombinedStatisticsCard(
                            selectedPeriod: selectedPeriod,
                            selectedTab: selectedTab
                        )
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

/// 图表数据点
struct ChartDataPoint {
    let date: Date
    let amount: Decimal
}

/// 统计切换器按钮 - 胶囊样式
struct StatisticsSwitcherButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color(hex: AppSettings.shared.titleColorHex) : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color(hex: AppSettings.shared.titleColorHex) : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 统计概览卡片
struct StatisticsOverviewCard: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedPeriod: StatisticsView.TimePeriod
    @Binding var selectedTab: StatisticsView.StatisticsTab
    let totalIncome: Decimal
    let totalExpense: Decimal

    @State private var currentDate = Date()
    @State private var displayDate = Date()

    var body: some View {
        VStack(spacing: 16) {
            // 时间范围选择器
            TimeRangeNavigator(
                selectedPeriod: selectedPeriod,
                currentDate: $displayDate,
                onPrevious: { navigatePeriod(-1) },
                onNext: { navigatePeriod(1) }
            )

            // 统计切换器
            HStack(spacing: 8) {
                StatisticsSwitcherButton(
                    title: "收入",
                    isSelected: selectedTab == .income
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .income
                    }
                }

                StatisticsSwitcherButton(
                    title: "支出",
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
        .onChange(of: selectedPeriod) { _, _ in
            displayDate = Date()
        }
    }

    private func navigatePeriod(_ direction: Int) {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .week:
            if let newDate = calendar.date(byAdding: .day, value: direction * 7, to: displayDate) {
                displayDate = newDate
            }
        case .month:
            if let newDate = calendar.date(byAdding: .month, value: direction, to: displayDate) {
                displayDate = newDate
            }
        case .year:
            if let newDate = calendar.date(byAdding: .year, value: direction, to: displayDate) {
                displayDate = newDate
            }
        case .custom:
            break
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

/// 时间范围导航器
struct TimeRangeNavigator: View {
    let selectedPeriod: StatisticsView.TimePeriod
    @Binding var currentDate: Date
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 上一个时间周期
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }

            // 时间范围显示
            Text(formattedTimeRange)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)

            // 下一个时间周期
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.vertical, 8)
    }

    private var formattedTimeRange: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: currentDate)

        switch selectedPeriod {
        case .week:
            // 计算本周的起止日期
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate)) ?? currentDate
            if let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
            }
            return "本周"

        case .month:
            // 显示"YYYY年M月"
            return "\(components.year!)年\(components.month!)月"

        case .year:
            // 显示"YYYY年"
            return "\(components.year!)年"

        case .custom:
            return "自定义范围"
        }
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

/// 时间选择器（独立置顶）- 现代卡片样式
struct TimePeriodSelector: View {
    @Binding var selectedPeriod: StatisticsView.TimePeriod
    @Binding var showingCustomDateRange: Bool

    var body: some View {
        // 时间选项容器
        HStack(spacing: 0) {
            // 周
            TimeOptionButton(
                title: "周",
                isSelected: selectedPeriod == .week
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedPeriod = .week
                }
            }

            // 月
            TimeOptionButton(
                title: "月",
                isSelected: selectedPeriod == .month
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedPeriod = .month
                }
            }

            // 年
            TimeOptionButton(
                title: "年",
                isSelected: selectedPeriod == .year
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedPeriod = .year
                }
            }

            // "自定义"选项（带下拉箭头）
            MoreOptionsButton(
                isSelected: selectedPeriod == .custom
            ) {
                showingCustomDateRange = true
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
    }
}

/// 时间选项按钮
struct TimeOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(isSelected ? Color(hex: AppSettings.shared.titleColorHex) : Color(red: 0.2, green: 0.2, blue: 0.2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// "更多"选项按钮
struct MoreOptionsButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text("自定义")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(isSelected ? Color(hex: AppSettings.shared.titleColorHex) : Color(red: 0.2, green: 0.2, blue: 0.2))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: AppSettings.shared.titleColorHex) : Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.white : Color.clear)
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

/// 每日柱状图卡片
struct DailyBarChartCard: View {
    @Environment(\.modelContext) private var modelContext
    let selectedPeriod: StatisticsView.TimePeriod
    let selectedTab: StatisticsView.StatisticsTab

    private var dailyData: [DailyDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        // 根据选择的时间周期确定日期范围
        let (startDate, daysCount): (Date, Int)
        switch selectedPeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: now) ?? now
            daysCount = 7
        case .month:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let range = calendar.range(of: .day, in: .month, for: now)
            return generateDailyData(from: startDate, days: range?.count ?? 30)
        case .year:
            startDate = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            daysCount = 30
        case .custom:
            startDate = calendar.date(byAdding: .day, value: -6, to: now) ?? now
            daysCount = 7
        }

        return generateDailyData(from: startDate, days: daysCount)
    }

    private func generateDailyData(from startDate: Date, days: Int) -> [DailyDataPoint] {
        let calendar = Calendar.current
        var data: [DailyDataPoint] = []

        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

                let transactions = DataManager.shared.getTransactions(from: dayStart, to: dayEnd)

                let amount: Decimal = if selectedTab == .income {
                    transactions.filter { $0.isAssetIncrease(context: modelContext) }
                        .reduce(0) { $0 + $1.amount }
                } else {
                    transactions.filter { $0.isAssetDecrease(context: modelContext) }
                        .reduce(0) { $0 + $1.amount }
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "M/d"

                data.append(DailyDataPoint(
                    date: date,
                    label: formatter.string(from: date),
                    amount: amount
                ))
            }
        }

        return data
    }

    /// 计算X轴要显示的标签索引
    private var xAxisLabelIndices: [Int] {
        let count = dailyData.count
        let maxLabels = 8

        if count <= maxLabels {
            // 数据点少于等于8个，显示全部
            return Array(0..<count)
        } else {
            // 数据点多于8个，均匀分布选择
            let step = (count - 1) / (maxLabels - 1)
            var indices: [Int] = []
            for i in 0..<maxLabels {
                let index = i * step
                indices.append(min(index, count - 1))
            }
            return indices
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text(selectedTab == .income ? "收入趋势" : "支出趋势")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            // 可交互的折线面积图
            if dailyData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("暂无数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                InteractiveLineChart(
                    data: dailyData,
                    selectedTab: selectedTab
                )
                .frame(height: 220)
            }
        }
        .padding(.bottom, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        if amount >= 10000 {
            return String(format: "%.1fw", Double(truncating: amount as NSNumber) / 10000.0)
        } else if amount >= 1000 {
            return String(format: "%.1fk", Double(truncating: amount as NSNumber) / 1000.0)
        }
        return "\(Int(truncating: amount as NSNumber))"
    }
}

/// 每日数据点
struct DailyDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let amount: Decimal
}

/// 趋势和分类统计合并卡片
struct CombinedStatisticsCard: View {
    @Environment(\.modelContext) private var modelContext
    let selectedPeriod: StatisticsView.TimePeriod
    let selectedTab: StatisticsView.StatisticsTab

    var body: some View {
        VStack(spacing: 0) {
            // 收入/支出趋势
            trendSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.leading, 16)

            // 分类统计
            categorySection
                .padding(16)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    /// 趋势图部分
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedTab == .income ? "收入趋势" : "支出趋势")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            if dailyData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("暂无数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                InteractiveLineChart(
                    data: dailyData,
                    selectedTab: selectedTab
                )
                .frame(height: 200)
            }
        }
    }

    /// 分类统计部分
    private var categorySection: some View {
        VStack(spacing: 16) {
            if categoryData.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: selectedTab == .income ? "chart.pie.fill" : "chart.pie")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))

                    Text(selectedTab == .income ? "暂无收入数据" : "暂无支出数据")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.5))
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
                    ForEach(Array(categoryData.enumerated()), id: \.element.id) { index, item in
                        let startAngle = startAngle(for: index)
                        let endAngle = endAngle(for: index)
                        let color = item.color

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

                        Text(formatTotalAmount())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.top, 8)

                // 统计列表
                VStack(spacing: 0) {
                    ForEach(Array(categoryData.enumerated()), id: \.element.id) { index, item in
                        DonutChartRow(
                            name: item.name,
                            amount: item.amount,
                            color: item.color,
                            percentage: item.percentage
                        )

                        if index < categoryData.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }

    private func startAngle(for index: Int) -> Double {
        let amountsBefore = categoryData.prefix(index).reduce(0) { $0 + $1.amount }
        let total = categoryData.reduce(0) { $0 + $1.amount }
        return total > 0 ? Double(truncating: (amountsBefore / total) as NSNumber) : 0
    }

    private func endAngle(for index: Int) -> Double {
        let amountsIncluding = categoryData.prefix(index + 1).reduce(0) { $0 + $1.amount }
        let total = categoryData.reduce(0) { $0 + $1.amount }
        return total > 0 ? Double(truncating: (amountsIncluding / total) as NSNumber) : 0
    }

    private func formatTotalAmount() -> String {
        let total = categoryData.reduce(0) { $0 + $1.amount }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: total)) ?? "¥0.00"
    }

    /// 每日数据
    private var dailyData: [DailyDataPoint] {
        let calendar = Calendar.current
        let now = Date()

        let startDate: Date
        let daysCount: Int
        switch selectedPeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: now) ?? now
            daysCount = 7
        case .month:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let range = calendar.range(of: .day, in: .month, for: now)
            return generateDailyData(from: startDate, days: range?.count ?? 30)
        case .year:
            startDate = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            daysCount = 30
        case .custom:
            startDate = calendar.date(byAdding: .day, value: -6, to: now) ?? now
            daysCount = 7
        }

        return generateDailyData(from: startDate, days: daysCount)
    }

    private func generateDailyData(from startDate: Date, days: Int) -> [DailyDataPoint] {
        let calendar = Calendar.current
        var data: [DailyDataPoint] = []

        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

                let transactions = DataManager.shared.getTransactions(from: dayStart, to: dayEnd)

                let amount: Decimal = if selectedTab == .income {
                    transactions.filter { $0.isAssetIncrease(context: modelContext) }
                        .reduce(0) { $0 + $1.amount }
                } else {
                    transactions.filter { $0.isAssetDecrease(context: modelContext) }
                        .reduce(0) { $0 + $1.amount }
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "M/d"

                data.append(DailyDataPoint(
                    date: date,
                    label: formatter.string(from: date),
                    amount: amount
                ))
            }
        }

        return data
    }

    /// X轴标签索引
    private var xAxisLabelIndices: [Int] {
        let count = dailyData.count
        let maxLabels = 8

        if count <= maxLabels {
            return Array(0..<count)
        } else {
            let step = (count - 1) / (maxLabels - 1)
            var indices: [Int] = []
            for i in 0..<maxLabels {
                let index = i * step
                indices.append(min(index, count - 1))
            }
            return indices
        }
    }

    /// 分类数据
    private var categoryData: [CategoryDataItem] {
        let transactions = DataManager.shared.getAllTransactions()
        let filtered = selectedTab == .income ?
            transactions.filter { $0.isAssetIncrease(context: modelContext) } :
            transactions.filter { $0.isAssetDecrease(context: modelContext) }

        // 获取所有账户
        let accountsDescriptor = FetchDescriptor<Account>()
        let allAccounts = (try? modelContext.fetch(accountsDescriptor)) ?? []

        // 创建账户ID到账户名称的映射
        let accountNameMap = Dictionary(uniqueKeysWithValues: allAccounts.map { ($0.id, $0.name) })

        // 按账户分组
        let grouped = Dictionary(grouping: filtered) { transaction -> String? in
            return accountNameMap[transaction.fromAccountId]
        }

        let total = grouped.values.reduce(0) { sum, transactions in
            sum + transactions.reduce(0) { $0 + $1.amount }
        }

        // 转换为数组并排序
        let sortedItems = grouped.map { (name, transactions) in
            (name ?? "未分类", transactions)
        }.sorted { $0.1.reduce(0) { $0 + $1.amount } > $1.1.reduce(0) { $0 + $1.amount } }

        return sortedItems.enumerated().map { index, item in
            let amount = item.1.reduce(0) { $0 + $1.amount }
            let percentage = total > 0 ? (Double(truncating: (amount / total * 100) as NSNumber) ) : 0.0
            return CategoryDataItem(
                name: item.0,
                amount: amount,
                percentage: percentage,
                color: rainbowColors[index % rainbowColors.count]
            )
        }
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

    /// 分类数据项
    struct CategoryDataItem: Identifiable {
        let id = UUID()
        let name: String
        let amount: Decimal
        let percentage: Double
        let color: Color
    }
}

/// 环形图行
struct DonutChartRow: View {
    let name: String
    let amount: Decimal
    let color: Color
    let percentage: Double

    var body: some View {
        HStack(spacing: 12) {
            // 色块
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)

            // 名称
            Text(name)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            // 金额
            Text(formatAmount(amount))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            // 百分比
            Text(String(format: "%.1f%%", percentage))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
}

/// 分类图例项
struct CategoryLegendItem: View {
    let color: Color
    let name: String
    let percentage: Double

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.primary)

                Text(String(format: "%.1f%%", percentage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// 可交互的折线面积图
struct InteractiveLineChart: View {
    let data: [DailyDataPoint]
    let selectedTab: StatisticsView.StatisticsTab

    @State private var selectedIndex: Int?

    private var themeColor: Color {
        Color(hex: AppSettings.shared.titleColorHex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 图表区域
            GeometryReader { geometry in
                Chart(data) { item in
                    // 面积填充
                    AreaMark(
                        x: .value("日期", item.label),
                        y: .value("金额", item.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeColor.opacity(0.3),
                                themeColor.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // 折线
                    LineMark(
                        x: .value("日期", item.label),
                        y: .value("金额", item.amount)
                    )
                    .foregroundStyle(themeColor)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    // 所有数据点的小圆圈
                    PointMark(
                        x: .value("日期", item.label),
                        y: .value("金额", item.amount)
                    )
                    .foregroundStyle(themeColor.opacity(0.6))
                    .symbolSize(.init(width: 8, height: 8))

                    // 选中的点 - 实心圆 + 外圈描边圆
                    if let index = selectedIndex, index < data.count, data[index].id == item.id {
                        PointMark(
                            x: .value("日期", item.label),
                            y: .value("金额", item.amount)
                        )
                        .annotation(position: .top, spacing: 12) {
                            // 透明背景的金额信息卡片
                            Text(formatAmount(item.amount))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(themeColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeColor.opacity(0.15))
                                )
                        }

                        // 实心圆
                        PointMark(
                            x: .value("日期", item.label),
                            y: .value("金额", item.amount)
                        )
                        .foregroundStyle(themeColor)
                        .symbolSize(.init(width: 16, height: 16))

                        // 外圈描边圆
                        PointMark(
                            x: .value("日期", item.label),
                            y: .value("金额", item.amount)
                        )
                        .foregroundStyle(Color.clear)
                        .symbolSize(.init(width: 28, height: 28))
                        .annotation(position: .overlay) {
                            Circle()
                                .stroke(themeColor, lineWidth: 2.5)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: xAxisLabelIndices) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self), intValue < data.count {
                                Text(data[intValue].label)
                            } else {
                                Text("")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                            .foregroundStyle(Color.clear)
                    }
                }
                .chartYAxis(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color.clear)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleTouch(at: value.location.x, in: geometry.size.width)
                        }
                )
                .onTapGesture { location in
                    handleTouch(at: location.x, in: geometry.size.width)
                }
            }
            .frame(height: 180)
        }
    }

    private func handleTouch(at xPosition: CGFloat, in width: CGFloat) {
        let count = data.count
        guard count > 0 else { return }

        let step = width / CGFloat(count)
        let index = Int(xPosition / step)
        selectedIndex = max(0, min(index, count - 1))
    }

    private var xAxisLabelIndices: [Int] {
        let count = data.count
        let maxLabels = 8

        if count <= maxLabels {
            return Array(0..<count)
        } else {
            let step = (count - 1) / (maxLabels - 1)
            var indices: [Int] = []
            for i in 0..<maxLabels {
                let index = i * step
                indices.append(min(index, count - 1))
            }
            return indices
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        if amount >= 10000 {
            formatter.maximumFractionDigits = 1
            let value = Double(truncating: amount as NSNumber) / 10000.0
            return String(format: "%.1f万", value)
        } else {
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
        }
    }
}

#Preview {
    StatisticsView()
}
