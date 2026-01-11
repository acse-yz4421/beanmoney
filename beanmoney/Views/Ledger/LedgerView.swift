//
//  LedgerView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.createdAt, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddTransaction = false
    @State private var selectedTransaction: Transaction?
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex

    /// 按日期分组的交易
    var groupedTransactions: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            // 将时间戳转换为当天的0点
            let components = calendar.dateComponents([.year, .month, .day], from: transaction.createdAt)
            return calendar.date(from: components) ?? transaction.createdAt
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 固定的顶部卡片
                    VStack(spacing: 0) {
                        if !transactions.isEmpty {
                            // 标题和月份统计在同一个卡片上
                            MonthHeaderCard(transactions: transactions)
                        } else {
                            // 空状态时也显示带背景色的标题
                            VStack(spacing: 0) {
                                // 大标题（带背景色）
                                Text("账本")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: titleColorHex))

                                // 空白区域
                                Text("暂无数据")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                            }
                        }
                    }

                    // 滚动内容区域
                    ScrollView {
                        if transactions.isEmpty {
                            // 空状态
                            VStack(spacing: 20) {
                                Spacer()
                                Image(systemName: "book.closed")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("还没有记账记录")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                                Text("点击右下角按钮开始记账")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        } else {
                            // 交易列表（按日期分组）
                            LazyVStack(spacing: 16) {
                                ForEach(groupedTransactions, id: \.0) { (date, dayTransactions) in
                                    DayTransactionCard(
                                        date: date,
                                        transactions: dayTransactions,
                                        onTapTransaction: { transaction in
                                            selectedTransaction = transaction
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 100)
                        }
                    }
                }

                // 浮动记账按钮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddTransaction = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color(hex: titleColorHex))
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                titleColorHex = AppSettings.shared.titleColorHex
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
                titleColorHex = AppSettings.shared.titleColorHex
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(false)
            }
        }
    }
}

/// 交易行组件
struct TransactionRow: View {
    @Environment(\.modelContext) private var modelContext
    let transaction: Transaction
    var onTap: (() -> Void)?
    var showDivider: Bool = true
    var customIconColor: Color? = nil

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: transactionIcon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(iconColor)
                )

            // 中间内容
            VStack(alignment: .leading, spacing: 4) {
                // 标题（备注或默认文本）
                Text(displayTitle)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 时间和交易流向
                HStack(spacing: 6) {
                    Text(formatTime(transaction.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("|")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))

                    Text(transaction.getDescription(context: modelContext))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 右侧金额
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmountWithSign)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                // 显示外币换算
                if shouldShowConversion {
                    Text(conversionText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .padding(.vertical, 12)
        .if(showDivider) { view in
            view.overlay(
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(height: 0.5),
                alignment: .bottom
            )
        }
    }

    /// 交易图标
    private var transactionIcon: String {
        guard let fromAccount = transaction.getFromAccount(context: modelContext),
              let toAccount = transaction.getToAccount(context: modelContext) else {
            return "arrow.left.arrow.right"
        }

        // 如果来源是收入或支出，显示来源账户的icon
        if fromAccount.type == .income || fromAccount.type == .expense {
            return fromAccount.icon
        }

        // 如果去向是收入或支出，显示去向账户的icon
        if toAccount.type == .income || toAccount.type == .expense {
            return toAccount.icon
        }

        // 否则显示转账icon
        return "arrow.left.arrow.right"
    }

    /// 图标颜色
    private var iconColor: Color {
        // 如果有自定义颜色，使用自定义颜色
        if let customColor = customIconColor {
            return customColor
        }

        guard let fromAccount = transaction.getFromAccount(context: modelContext) else {
            return .blue
        }

        switch fromAccount.type {
        case .income:
            return .green
        case .expense:
            return .red
        default:
            return .blue
        }
    }

    /// 格式化金额显示（带符号）
    private var formattedAmountWithSign: String {
        guard let fromAccount = transaction.getFromAccount(context: modelContext),
              let toAccount = transaction.getToAccount(context: modelContext) else {
            return transaction.formattedAmount
        }

        // 如果来源是收入，显示"+"
        if fromAccount.type == .income {
            return "+\(transaction.formattedAmount)"
        }

        // 如果去向是支出，显示"-"
        if toAccount.type == .expense {
            return "-\(transaction.formattedAmount)"
        }

        // 其他情况不显示符号
        return transaction.formattedAmount
    }

    /// 是否需要显示换算
    private var shouldShowConversion: Bool {
        guard let fromAccount = transaction.getFromAccount(context: modelContext),
              let toAccount = transaction.getToAccount(context: modelContext) else {
            return false
        }

        // 如果交易币种不是默认币种
        if transaction.currencyCode != AppSettings.shared.defaultCurrencyCode {
            return true
        }

        // 如果来源和去向账户的币种不同，显示换算
        if fromAccount.currencyCode != toAccount.currencyCode {
            return true
        }

        return false
    }

    /// 换算文本
    private var conversionText: String {
        guard let fromAccount = transaction.getFromAccount(context: modelContext),
              let toAccount = transaction.getToAccount(context: modelContext) else {
            return ""
        }

        // 如果交易币种不是默认币种
        if transaction.currencyCode != AppSettings.shared.defaultCurrencyCode {
            let convertedAmount = AppSettings.shared.convertToDefault(
                amount: transaction.amount,
                from: transaction.currencyCode
            )
            return "≈ \(AppSettings.shared.defaultCurrency.format(convertedAmount))"
        }

        // 如果来源和去向账户币种不同
        if fromAccount.currencyCode != toAccount.currencyCode {
            let toCurrency = Currency.defaultCurrencies.first { $0.code == toAccount.currencyCode }

            // 将金额换算到去向账户的币种
            let rate1 = AppSettings.shared.getExchangeRate(for: fromAccount.currencyCode)
            let rate2 = AppSettings.shared.getExchangeRate(for: toAccount.currencyCode)
            let convertedAmount = (transaction.amount as Decimal) * Decimal(rate2 / rate1)

            return "≈ \(toCurrency?.format(convertedAmount) ?? "")"
        }

        return ""
    }

    /// 交易显示标题（备注或默认文本）
    private var displayTitle: String {
        // 如果有备注，显示备注
        if !transaction.note.isEmpty {
            return transaction.note
        }

        // 否则显示默认文本
        return defaultTitle
    }

    /// 默认标题
    private var defaultTitle: String {
        guard let fromAccount = transaction.getFromAccount(context: modelContext),
              let toAccount = transaction.getToAccount(context: modelContext) else {
            return "转账"
        }

        // 如果来源是收入，显示来源账户名称（资金来源）
        if fromAccount.type == .income {
            return fromAccount.name
        }

        // 如果去向是支出，显示去向账户名称（资金去向）
        if toAccount.type == .expense {
            return toAccount.name
        }

        // 如果去向是收入，显示来源账户名称
        if toAccount.type == .income {
            return fromAccount.name
        }

        // 如果来源是支出，显示去向账户名称
        if fromAccount.type == .expense {
            return toAccount.name
        }

        // 否则显示"转账"
        return "转账"
    }

    /// 格式化时间（只显示时分）
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

/// 日期统计Header
struct DayStatisticsHeader: View {
    let date: Date
    let transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    /// 当天的收入总额
    var dayIncome: Decimal {
        transactions.filter { transaction in
            guard let fromAccount = transaction.getFromAccount(context: modelContext) else {
                return false
            }
            return fromAccount.type == .income
        }.reduce(0) { $0 + $1.amount }
    }

    /// 当天的支出总额
    var dayExpense: Decimal {
        transactions.filter { transaction in
            guard let toAccount = transaction.getToAccount(context: modelContext) else {
                return false
            }
            return toAccount.type == .expense
        }.reduce(0) { $0 + $1.amount }
    }

    /// 格式化日期显示
    var displayDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日 EEEE"
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.string(from: date)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 日期
            Text(displayDate)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()

            // 收入和支出统计
            HStack(spacing: 16) {
                // 收入
                if dayIncome > 0 {
                    Text("收 \(formatAmount(dayIncome))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                // 支出
                if dayExpense > 0 {
                    Text("支 \(formatAmount(dayExpense))")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let currency = Currency.defaultCurrencies.first { $0.code == "CNY" }
                ?? Currency(code: "CNY", symbol: "¥", name: "人民币")
        return currency.format(amount)
    }
}

#Preview {
    LedgerView()
}

/// 每日交易卡片
struct DayTransactionCard: View {
    let date: Date
    let transactions: [Transaction]
    var onTapTransaction: (Transaction) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex

    var body: some View {
        VStack(spacing: 0) {
            // 日期统计header
            DayStatisticsHeader(
                date: date,
                transactions: transactions
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 交易列表
            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                TransactionRow(
                    transaction: transaction,
                    onTap: {
                        onTapTransaction(transaction)
                    },
                    showDivider: index < transactions.count - 1,
                    customIconColor: Color(hex: titleColorHex)
                )
                .padding(.horizontal, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                // 批量删除操作（可选）
            } label: {
                Label("删除当天所有交易", systemImage: "trash")
            }
        }
        .onAppear {
            titleColorHex = AppSettings.shared.titleColorHex
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
            titleColorHex = AppSettings.shared.titleColorHex
        }
    }
}

/// View extension for conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

/// 月份统计卡片
struct MonthStatisticsCard: View {
    let transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext

    /// 当前月份的交易
    private var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter { transaction in
            calendar.isDate(transaction.createdAt, equalTo: now, toGranularity: .month)
        }
    }

    /// 本月收入总额
    private var monthIncome: Decimal {
        currentMonthTransactions.filter { transaction in
            guard let fromAccount = transaction.getFromAccount(context: modelContext) else {
                return false
            }
            return fromAccount.type == .income
        }.reduce(0) { $0 + $1.amount }
    }

    /// 本月支出总额
    private var monthExpense: Decimal {
        currentMonthTransactions.filter { transaction in
            guard let toAccount = transaction.getToAccount(context: modelContext) else {
                return false
            }
            return toAccount.type == .expense
        }.reduce(0) { $0 + $1.amount }
    }

    /// 月份显示
    private var monthText: String {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: now)
    }

    var body: some View {
        HStack(spacing: 20) {
            // 收入
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("收入")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Text(formatAmount(monthIncome))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.green)
            }

            Spacer()

            // 支出
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("支出")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                Text(formatAmount(monthExpense))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let currency = Currency.defaultCurrencies.first { $0.code == "CNY" }
                ?? Currency(code: "CNY", symbol: "¥", name: "人民币")
        return currency.format(amount)
    }
}

/// 月份头部卡片（标题+统计）
struct MonthHeaderCard: View {
    let transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex

    /// 当前月份的交易
    private var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter { transaction in
            calendar.isDate(transaction.createdAt, equalTo: now, toGranularity: .month)
        }
    }

    /// 本月收入总额
    private var monthIncome: Decimal {
        currentMonthTransactions.filter { transaction in
            guard let fromAccount = transaction.getFromAccount(context: modelContext) else {
                return false
            }
            return fromAccount.type == .income
        }.reduce(0) { $0 + $1.amount }
    }

    /// 本月支出总额
    private var monthExpense: Decimal {
        currentMonthTransactions.filter { transaction in
            guard let toAccount = transaction.getToAccount(context: modelContext) else {
                return false
            }
            return toAccount.type == .expense
        }.reduce(0) { $0 + $1.amount }
    }

    /// 月份显示
    private var monthText: String {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 大标题（带背景色）
            Text("账本")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(hex: titleColorHex))

            // 月份和收支统计
            Text("\(monthText)总支出：\(formatAmount(monthExpense))元。总收入：\(formatAmount(monthIncome))元")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white)
        }
        .onAppear {
            titleColorHex = AppSettings.shared.titleColorHex
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
            titleColorHex = AppSettings.shared.titleColorHex
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        // 简化显示，只显示数字，不显示符号
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "0"
    }
}
