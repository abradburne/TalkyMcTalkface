import SwiftUI

/// View that displays the menu bar icon based on current status
struct MenuBarIconView: View {
    let status: AppStatus

    var body: some View {
        Image(systemName: status.iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
    }

    private var iconColor: Color {
        switch status {
        case .ready:
            return .green
        case .loading:
            return .blue
        case .error:
            return .red
        case .downloadRequired:
            return .orange
        case .downloading:
            return .blue
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        MenuBarIconView(status: .ready)
        MenuBarIconView(status: .loading)
        MenuBarIconView(status: .error)
        MenuBarIconView(status: .downloadRequired)
        MenuBarIconView(status: .downloading)
    }
    .padding()
}
