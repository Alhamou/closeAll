import AppKit
import closeAllCore
import SwiftUI

enum LaunchMode {
    case menuBar
    case dryRun
    case demoWindow
    case renderPreview

    static var current: LaunchMode {
        let arguments = CommandLine.arguments
        if arguments.contains("--dry-run") {
            return .dryRun
        }
        if arguments.contains("--demo-window") {
            return .demoWindow
        }
        if arguments.contains("--render-preview") {
            return .renderPreview
        }
        return .menuBar
    }

    static var renderPreviewPath: String {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--render-preview"), arguments.indices.contains(index + 1) else {
            return "/tmp/closeall-panel.png"
        }
        return arguments[index + 1]
    }
}

@main
struct EntryPoint {
    static func main() {
        switch LaunchMode.current {
        case .dryRun:
            MainActor.assumeIsolated {
                DryRunCLI.run()
            }
        case .renderPreview:
            MainActor.assumeIsolated {
                PreviewRenderer.write(to: LaunchMode.renderPreviewPath)
            }
        case .menuBar:
            closeAllApp.main()
        case .demoWindow:
            DemoApp.main()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if LaunchMode.current == .demoWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        LaunchMode.current == .demoWindow
    }
}

struct closeAllApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = PanelModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(model: model)
        } label: {
            Image(systemName: "rectangle.stack")
                .accessibilityLabel("closeAll")
        }
        .menuBarExtraStyle(.window)
    }
}

struct DemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = PanelModel()

    var body: some Scene {
        WindowGroup("closeAll") {
            MenuBarPanel(model: model)
                .frame(minWidth: 300, minHeight: 280)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 460)
    }
}
