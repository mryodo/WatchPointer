import AppKit

/// The red dot of presentation mode: a click-through window above everything, even full-screen slideshows.
/// The real cursor stays put, so slideshows that hide it keep it hidden.
final class Laser {
    private let size = 22.0
    private let panel: NSPanel

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        dot.layer?.cornerRadius = size / 2
        dot.layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor
        dot.layer?.borderWidth = 2
        panel.contentView = dot
    }

    /// `p` in global display coordinates (top-left origin, like CGEvent); nil hides the dot. Main thread only.
    func show(at p: CGPoint?) {
        guard let p else { panel.orderOut(nil); return }
        let flip = NSScreen.screens.first?.frame.height ?? 0 // AppKit counts up from the primary screen's bottom
        panel.setFrameOrigin(NSPoint(x: p.x - size / 2, y: flip - p.y - size / 2))
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}
