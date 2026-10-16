import AppKit
import SwiftUI

@MainActor
enum PreviewRenderer {
    static func write(to path: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let model = PanelModel()
        let host = NSHostingView(rootView: MenuBarPanel(model: model))
        let fitting = host.fittingSize
        let size = NSSize(width: 300, height: max(fitting.height, 120))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let fittedAgain = host.fittingSize
        host.frame = NSRect(x: 0, y: 0, width: 300, height: max(fittedAgain.height, size.height))
        window.setContentSize(host.frame.size)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            FileHandle.standardError.write(Data("Could not render the panel.\n".utf8))
            Darwin.exit(EXIT_FAILURE)
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("Could not encode the panel image.\n".utf8))
            Darwin.exit(EXIT_FAILURE)
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            FileHandle.standardError.write(Data("Could not write the panel image.\n".utf8))
            Darwin.exit(EXIT_FAILURE)
        }
        window.close()
    }
}
