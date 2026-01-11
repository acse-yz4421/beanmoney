//
//  SettingsView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI

struct SettingsView: View {
    @State private var appSettings = AppSettings.shared
    @State private var showingExchangeRates = false
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex

    var body: some View {
        NavigationStack {
            Form {
                // 标题颜色
                Section {
                    NavigationLink {
                        TitleColorSelectionView()
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(Color(hex: titleColorHex))
                            Text("颜色")
                            Spacer()
                            Circle()
                                .fill(Color(hex: titleColorHex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                                )
                        }
                    }
                } header: {
                    Text("外观")
                } footer: {
                    Text("自定义账本标题的背景颜色")
                        .font(.caption)
                }

                // 默认币种
                Section("默认币种") {
                    Picker("", selection: $appSettings.defaultCurrencyCode) {
                        ForEach(Currency.defaultCurrencies) { currency in
                            Text("\(currency.symbol) \(currency.code) - \(currency.name)")
                                .tag(currency.code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // 汇率管理
                Section {
                    NavigationLink {
                        ExchangeRateManagementView()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundColor(.blue)
                            Text("汇率管理")
                        }
                    }
                } header: {
                    Text("多币种")
                } footer: {
                    Text("设置其他币种相对于默认币种的汇率")
                        .font(.caption)
                }

                // 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                titleColorHex = AppSettings.shared.titleColorHex
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
                titleColorHex = AppSettings.shared.titleColorHex
            }
        }
    }
}

/// 汇率管理视图
struct ExchangeRateManagementView: View {
    @State private var appSettings = AppSettings.shared

    var body: some View {
        List {
            ForEach(Currency.defaultCurrencies.filter { $0.code != appSettings.defaultCurrencyCode }) { currency in
                ExchangeRateRow(currency: currency)
            }
        }
        .navigationTitle("汇率管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 汇率行
struct ExchangeRateRow: View {
    @State private var appSettings = AppSettings.shared
    let currency: Currency
    @State private var showingEdit = false
    @State private var rate: String

    private var currentRate: Double {
        appSettings.getExchangeRate(for: currency.code)
    }

    init(currency: Currency) {
        self.currency = currency
        _rate = State(initialValue: String(format: "%.4f", AppSettings.shared.getExchangeRate(for: currency.code)))
    }

    var body: some View {
        Button(action: {
            showingEdit = true
        }) {
            HStack {
                // 币种图标
                Text(currency.symbol)
                    .font(.title2)
                    .frame(width: 40)

                // 币种信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text(currency.code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 汇率显示
                VStack(alignment: .trailing, spacing: 4) {
                    Text("1 \(currency.code) = \(rate) \(appSettings.defaultCurrencyCode)")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text("点击修改")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingEdit) {
            EditExchangeRateView(currency: currency, rate: $rate)
        }
    }
}

/// 编辑汇率视图
struct EditExchangeRateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appSettings = AppSettings.shared

    let currency: Currency
    @Binding var rate: String
    @State private var tempRate: String
    @State private var showingCalculator = false

    init(currency: Currency, rate: Binding<String>) {
        self.currency = currency
        _rate = rate
        _tempRate = State(initialValue: rate.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("汇率设置") {
                    Text("1 \(currency.code) = ? \(appSettings.defaultCurrencyCode)")
                        .font(.headline)

                    HStack {
                        Text("汇率")
                            .frame(width: 80, alignment: .leading)
                        TextField("输入汇率", text: $tempRate)
                            .keyboardType(.decimalPad)
                    }

                    // 汇率说明
                    VStack(alignment: .leading, spacing: 8) {
                        Text("说明")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("例如：如果1美元 = 7.2人民币，则输入7.2")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("当前默认币种：\(appSettings.defaultCurrency.symbol) \(appSettings.defaultCurrencyCode)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // 汇率说明
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("常用汇率参考（仅供参考）")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ExchangeRateReferenceRow(currencyCode: "USD", name: "美元", approximateRate: 7.2)
                        ExchangeRateReferenceRow(currencyCode: "EUR", name: "欧元", approximateRate: 7.8)
                        ExchangeRateReferenceRow(currencyCode: "HKD", name: "港币", approximateRate: 0.92)
                        ExchangeRateReferenceRow(currencyCode: "JPY", name: "日元", approximateRate: 0.048)
                        ExchangeRateReferenceRow(currencyCode: "GBP", name: "英镑", approximateRate: 9.1)

                        Text("实际汇率请以银行牌价为准")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("编辑汇率")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRate()
                    }
                    .disabled(tempRate.isEmpty)
                }
            }
        }
    }

    private func saveRate() {
        if let rateValue = Double(tempRate) {
            appSettings.setExchangeRate(rateValue, for: currency.code)
            rate = tempRate
        }
        dismiss()
    }
}

/// 汇率参考行
struct ExchangeRateReferenceRow: View {
    let currencyCode: String
    let name: String
    let approximateRate: Double

    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline)
            Spacer()
            Text(String(format: "%.4f", approximateRate))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// 标题颜色选择视图
struct TitleColorSelectionView: View {
    @State private var selectedHex: String
    @Environment(\.dismiss) private var dismiss

    init() {
        _selectedHex = State(initialValue: AppSettings.shared.titleColorHex)
    }

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(TitleColorOption.allOptions) { option in
                        colorButton(option)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("选择主题颜色")
            } footer: {
                Text("选择后立即生效，会影响标题背景、交易图标等界面元素")
                    .font(.caption)
            }
        }
        .navigationTitle("颜色")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedHex = AppSettings.shared.titleColorHex
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
            selectedHex = AppSettings.shared.titleColorHex
        }
    }

    private func colorButton(_ option: TitleColorOption) -> some View {
        Button(action: {
            selectedHex = option.hex
            AppSettings.shared.titleColorHex = option.hex
        }) {
            ZStack {
                Circle()
                    .fill(option.color)
                    .frame(width: 44, height: 44)

                if selectedHex == option.hex {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
