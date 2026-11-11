import SwiftUI

/// What the notch shows. Written by the Receiver, read by the notch views.
final class Live: ObservableObject {
    enum Phase { case waiting, live, paused, idle, presenting }
    enum Toast { case connected, lost, centered, paused, resumed }

    @Published var phase = Phase.waiting
    @Published var toast: Toast?
    @Published var hovered = false
    @Published var pointer = CGPoint(x: 0.5, y: 0.5) // 0...1 across the main display
    @Published var aimLeft = 0.0                     // degrees
    @Published var aimUp = 0.0
    @Published var rate = 0                          // samples per second from the watch
    @Published var clicks = 0
    @Published var watch: WatchInfo?
    /// Keep the panel open without hovering. Remembered between runs.
    @Published var pinned = UserDefaults.standard.bool(forKey: "pinned") {
        didSet { UserDefaults.standard.set(pinned, forKey: "pinned") }
    }

    private var clearToast: DispatchWorkItem?

    func show(_ toast: Toast) {
        self.toast = toast
        clearToast?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        clearToast = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
}
