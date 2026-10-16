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

    /// Menu-bar windows give a ScrollView no height unless one is set explicitly.
    private var appList: some View {
        let rowHeight: CGFloat = 28
        let spacing: CGFloat = 6
        let count = CGFloat(model.rows.count)
        let contentHeight = count * rowHeight + max(count - 1, 0) * spacing
        let visibleHeight = min(contentHeight, 240)

        return ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(model.rows) { row in
                    Toggle(isOn: willQuitBinding(for: row.processIdentifier)) {
                        HStack(spacing: 6) {
                            appIcon(for: row.processIdentifier)
                            Text(row.title)
                                .lineLimit(1)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: visibleHeight)
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
