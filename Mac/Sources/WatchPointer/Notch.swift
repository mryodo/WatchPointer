import AppKit
import SwiftUI


// MARK: Geometry

struct NotchMetrics {
    let width: CGFloat  // the hardware notch (0 on Macs without one)
    let height: CGFloat

    static func of(_ screen: NSScreen) -> NotchMetrics {
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return NotchMetrics(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        }
        return NotchMetrics(width: 0, height: 24) // no notch: a small island under the menu bar's middle
    }
}

enum NotchMode { case collapsed, toast, expanded }

enum NotchLayout {
    static let ear: CGFloat = 34

    static func size(_ mode: NotchMode, _ m: NotchMetrics) -> CGSize {
        switch mode {
        case .collapsed: CGSize(width: m.width + ear * 2, height: m.height)
        case .toast: CGSize(width: m.width + 170, height: m.height + 42)
        case .expanded: CGSize(width: max(m.width + 260, 430), height: m.height + 164)
        }
    }
}

/// Flat top that flares into the screen edge, rounded bottom: the shape of the hardware notch.
struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var flare: CGFloat = 6

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + flare, y: r.minY + flare), control: CGPoint(x: r.minX + flare, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + flare, y: r.maxY - bottomRadius))
        p.addQuadCurve(to: CGPoint(x: r.minX + flare + bottomRadius, y: r.maxY), control: CGPoint(x: r.minX + flare, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - flare - bottomRadius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - flare, y: r.maxY - bottomRadius), control: CGPoint(x: r.maxX - flare, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - flare, y: r.minY + flare))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - flare, y: r.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: Views

struct NotchView: View {
    @ObservedObject var live: Live
    let metrics: NotchMetrics

    @State private var blink = false

    private var mode: NotchMode { live.hovered || live.pinned ? .expanded : live.toast != nil ? .toast : .collapsed }

    private var status: Color {
        switch live.phase {
        case .waiting: Color(white: 0.4)
        case .live: .green
        case .paused, .idle: .orange
        case .presenting: .red
        }
    }

    var body: some View {
        let size = NotchLayout.size(mode, metrics)
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: mode == .collapsed ? 10 : 22)
                .fill(.black)

            VStack(spacing: 0) {
                ears.frame(height: metrics.height)
                switch mode {
                case .collapsed: EmptyView()
                case .toast: toast.transition(.opacity)
                case .expanded: details.transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(width: size.width, height: size.height)
        .animation(.smooth(duration: 0.38), value: mode)
        .animation(.smooth(duration: 0.3), value: live.phase)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: live.clicks) {
            blink = true
            withAnimation(.smooth(duration: 0.25)) { blink = false }
        }
    }

    private var ears: some View {
        HStack {
            Image(systemName: "applewatch")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(live.phase == .waiting ? Color(white: 0.45) : .white)
            Spacer(minLength: metrics.width)
            if mode == .expanded {
                Button { live.pinned.toggle() } label: {
                    Image(systemName: live.pinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(live.pinned ? .white : Color(white: 0.5))
                        .rotationEffect(.degrees(45))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
            // Like the camera/mic indicator: one small dot.
            Circle()
                .fill(status)
                .frame(width: 6, height: 6)
                .scaleEffect(blink ? 1.6 : 1)
        }
    }

    @ViewBuilder private var toast: some View {
        let (symbol, text): (String, String) = switch live.toast {
        case .connected: ("applewatch", "Connected")
        case .centered: ("scope", "Centered")
        case .paused: ("pause.fill", "Paused")
        case .resumed: ("play.fill", "Resumed")
        case .lost, nil: ("applewatch.slash", "Disconnected")
        }
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(live.toast == .paused || live.toast == .lost ? .orange : .white)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(maxHeight: .infinity)
        .padding(.bottom, 4)
    }

    private var details: some View {
        HStack(spacing: 18) {
            ScreenMap(pointer: live.pointer, active: live.phase == .live)
                .frame(width: 156, height: 98)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // The watch's own name (e.g. "Sam's Apple Watch"), then what it is.
                        Text(live.watch.map { $0.name.isEmpty ? $0.modelName : $0.name } ?? "Apple Watch")
                            .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Circle().fill(status).frame(width: 6, height: 6)
                    }
                    if let watch = live.watch {
                        Group {
                            if !watch.name.isEmpty { Text(watch.modelName) }
                            Text(watch.subtitle)
                        }
                        .font(.system(size: 11)).foregroundStyle(Color(white: 0.5)).lineLimit(1)
                    }
                }
                .padding(.bottom, 2)
                stat("arrow.left.and.right", live.phase == .live ? String(format: "%+.1f°", -live.aimLeft) : "–")
                stat("arrow.up.and.down", live.phase == .live ? String(format: "%+.1f°", live.aimUp) : "–")
                stat("waveform", live.phase == .live ? "\(live.rate) Hz" : "–")
                stat(batterySymbol, live.watch.map { $0.battery < 0 ? "–" : "\($0.battery)%" } ?? "–")
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var batterySymbol: String {
        guard let watch = live.watch, watch.battery >= 0 else { return "battery.0percent" }
        if watch.charging { return "battery.100percent.bolt" }
        return switch watch.battery {
        case 88...: "battery.100percent"
        case 63..<88: "battery.75percent"
        case 38..<63: "battery.50percent"
        case 13..<38: "battery.25percent"
        default: "battery.0percent"
        }
    }

    private func stat(_ symbol: String, _ value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).frame(width: 16).foregroundStyle(Color(white: 0.5))
            Text(value).monospacedDigit().contentTransition(.numericText())
        }
        .font(.system(size: 12))
    }
}

/// A tiny picture of the screen with the pointer where the watch is aiming.
struct ScreenMap: View {
    let pointer: CGPoint
    let active: Bool

    var body: some View {
        Canvas { context, size in
            let display = MacDisplay().path(in: CGRect(origin: .zero, size: size))
            context.fill(display, with: .color(Color(white: 0.17)))
            guard active else { return }
            let c = CGPoint(x: pointer.x * size.width, y: pointer.y * size.height)
            let arrow = context.resolve(Text(Image(systemName: "cursorarrow")).font(.system(size: 14)).foregroundStyle(.white))
            context.draw(arrow, at: CGPoint(x: c.x - 3, y: c.y - 1), anchor: .topLeading) // tip on the spot
        }
    }
}

// MARK: Window

/// Takes the click that lands on it even though the panel never becomes active.
final class ClickThroughHost<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// A panel above the menu bar, centered on the notch. Clicks pass through it except right under the pointer.
final class NotchController {
    private let live: Live
    private let screen: NSScreen
    private let metrics: NotchMetrics
    private let panel: NSPanel
    private var hoverTimer: Timer?

    init(live: Live) {
        self.live = live
        screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        metrics = .of(screen)

        let size = CGSize(width: 700, height: 260) // room for the biggest state
        panel = NSPanel(contentRect: NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                                            width: size.width, height: size.height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true // turned off only while the pointer is over the notch (see checkHover)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let host = ClickThroughHost(rootView: NotchView(live: live, metrics: metrics))
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()

        // Check where the pointer is (trackpad or watch) 20× a second.
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
            self?.checkHover()
        }
    }

    private func checkHover() {
        let open = live.hovered || live.pinned
        let size = NotchLayout.size(open ? .expanded : .collapsed, metrics)
        let margin: CGFloat = live.hovered ? 10 : 0 // a little slack before it closes again
        let rect = NSRect(x: screen.frame.midX - size.width / 2 - margin, y: screen.frame.maxY - size.height - margin,
                          width: size.width + margin * 2, height: size.height + margin + 1)
        let inside = rect.contains(NSEvent.mouseLocation)
        if inside != live.hovered { live.hovered = inside }
        // Only catch clicks over the notch itself (for the pin), everywhere else they go to the apps below.
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
    }
}
