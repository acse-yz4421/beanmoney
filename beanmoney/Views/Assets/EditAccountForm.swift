//
//  EditAccountForm.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

struct EditAccountForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var account: Account

    @State private var selectedIconIndex = 0

    private let currencies = Currency.defaultCurrencies
    private let icons = [
        "folder", "banknote", "creditcard", "house", "car",
        "laptopcomputer", "gamecontroller", "airplane", "gift.fill",
        "heart.fill", "star.fill", "book.fill", "bag.fill",
        "cart.fill", "phone.fill", "tv.fill", "desktopcomputer",
        "bicycle", "tram.fill", "car.fill", "airplane",
        "chart.bar.fill", "chart.line.uptrend.xyaxis", "chart.pie.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("账户信息") {
                    HStack {
                        Text("账户名称")
                            .frame(width: 80, alignment: .leading)
                        TextField("账户名称", text: $account.name)
                    }

                    HStack {
                        Text("币种")
                            .frame(width: 80, alignment: .leading)
                        Picker("", selection: $account.currencyCode) {
                            ForEach(currencies) { currency in
                                Text("\(currency.symbol) \(currency.code)").tag(currency.code)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("图标") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(Array(icons.enumerated()), id: \.offset) { index, iconName in
                            Button(action: {
                                selectedIconIndex = index
                                account.icon = iconName
                            }) {
                                Image(systemName: iconName)
                                    .font(.title2)
                                    .foregroundColor(account.icon == iconName && selectedIconIndex == index ? .white : .blue)
                                    .frame(width: 50, height: 50)
                                    .background(account.icon == iconName && selectedIconIndex == index ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .onAppear {
                        if let index = icons.firstIndex(of: account.icon) {
                            selectedIconIndex = index
                        }
                    }
                }

                Section("备注") {
                    TextField("选填", text: $account.note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        account.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
