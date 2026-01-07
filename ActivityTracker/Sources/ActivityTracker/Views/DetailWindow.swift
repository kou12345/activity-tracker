import SwiftUI

struct DetailWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            Sidebar()
        } detail: {
            switch appState.selectedTab {
            case .dashboard:
                DashboardView()
            case .apps:
                AppsView()
            case .focus:
                FocusView()
            case .reports:
                ReportsView()
            case .history:
                HistoryView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct Sidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: $appState.selectedTab) {
            Section("Activity Tracker") {
                ForEach(DetailTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }
}
