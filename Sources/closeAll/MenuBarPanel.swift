import AppKit
import closeAllCore
import SwiftUI

struct MenuBarPanel: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("closeAll")
                    .font(.headline)
                Text(model.statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let failureMessage = model.failureMessage {
                    Text(failureMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if model.rows.isEmpty {
                Text("Nothing open in the Dock can be quit.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                appList
                    .disabled(model.isQuitting)
            }

            Button {
                model.forceQuit()
            } label: {
                Text(model.buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(model.quitCount == 0 || model.isQuitting)

            Text("Checked apps close. Uncheck one, such as Cursor, to keep it.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Quit closeAll") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(12)
        .frame(width: 300)
        .background(Color(nsColor: .windowBackgroundColor))
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.refresh() }
    }

    /// Dock apps, then the background apps in their own scroll area, so that section stays in
    /// view even when many Dock apps are open.
    private var appList: some View {
        let dockRows = model.rows.filter { $0.group == .dock }
        let backgroundRows = model.rows.filter { $0.group == .background }
        return VStack(alignment: .leading, spacing: 8) {
            if !dockRows.isEmpty {
                rowList(dockRows, maxHeight: backgroundRows.isEmpty ? 240 : 200)
            }
            if !backgroundRows.isEmpty {
                Text("Background apps (check to close)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                rowList(backgroundRows, maxHeight: 130)
            }
        }
    }

    /// Menu-bar windows give a ScrollView no height unless one is set explicitly.
    private func rowList(_ rows: [PresentedApp], maxHeight: CGFloat) -> some View {
        let rowHeight: CGFloat = 28
        let spacing: CGFloat = 6
        let count = CGFloat(rows.count)
        let contentHeight = count * rowHeight + max(count - 1, 0) * spacing
        return ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(rows) { row in
                    appRow(row)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: min(contentHeight, maxHeight))
    }

    private func appRow(_ row: PresentedApp) -> some View {
        Toggle(isOn: willQuitBinding(for: row.processIdentifier)) {
            HStack(spacing: 6) {
                appIcon(for: row.processIdentifier)
                Text(row.title)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.checkbox)
    }

    private func appIcon(for processIdentifier: Int32) -> some View {
        Group {
            if let icon = model.icons[processIdentifier] {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app")
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }

    private func willQuitBinding(for processIdentifier: Int32) -> Binding<Bool> {
        Binding(
            get: {
                model.rows.first { $0.processIdentifier == processIdentifier }?.willQuit ?? false
            },
            set: { model.setWillQuit($0, processIdentifier: processIdentifier) }
        )
    }
}
