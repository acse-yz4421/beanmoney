//
//  ContentView.swift
//  beanmoney
//
//  Created by Claude Code
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var titleColorHex: String = AppSettings.shared.titleColorHex

    var body: some View {
        TabView(selection: $selectedTab) {
            LedgerView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("账本")
                }
                .tag(0)

            AssetsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("资产")
                }
                .tag(1)

            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("统计")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("设置")
                }
                .tag(3)
        }
        .tint(Color(hex: titleColorHex))
        .onAppear {
            titleColorHex = AppSettings.shared.titleColorHex
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TitleColorDidChange"))) { _ in
            titleColorHex = AppSettings.shared.titleColorHex
        }
    }
}

#Preview {
    ContentView()
}
