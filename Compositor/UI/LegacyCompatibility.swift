import AppKit
import Combine
import SwiftUI

/// A shared publisher also propagates changes in nested edit and history objects.
/// Ventura does not provide Observation's automatic nested-property tracking.
@MainActor
final class LegacyRefresh: ObservableObject {
    static let shared = LegacyRefresh()
    let objectWillChange = ObservableObjectPublisher()
    private init() {}
}

private struct LegacyChange<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (Value, Value) -> Void
    @State private var previous: Value

    init(value: Value, action: @escaping (Value, Value) -> Void) {
        self.value = value
        self.action = action
        _previous = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content.onChange(of: value) { new in
            let old = previous
            previous = new
            action(old, new)
        }
    }
}

private struct LegacyGeometryKey<Value: Equatable>: PreferenceKey {
    static var defaultValue: Value? { nil }
    static func reduce(value: inout Value?, nextValue: () -> Value?) {
        if let next = nextValue() { value = next }
    }
}

extension View {
    func legacyOnChange<Value: Equatable>(of value: Value, perform action: @escaping () -> Void) -> some View {
        modifier(LegacyChange(value: value) { _, _ in action() })
    }

    func legacyOnChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        modifier(LegacyChange(value: value) { _, new in action(new) })
    }

    func legacyOnChange<Value: Equatable>(of value: Value, perform action: @escaping (Value, Value) -> Void) -> some View {
        modifier(LegacyChange(value: value, action: action))
    }

    func legacyOnGeometryChange<Value: Equatable>(for type: Value.Type,
                                                  of transform: @escaping (GeometryProxy) -> Value,
                                                  action: @escaping (Value) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: LegacyGeometryKey<Value>.self, value: transform(proxy))
            }
        }
        .onPreferenceChange(LegacyGeometryKey<Value>.self) { if let value = $0 { action(value) } }
    }

    func legacyArrowKeys(_ action: @escaping (Int) -> Void) -> some View {
        background(LegacyArrowKeyMonitor(action: action).frame(width: 0, height: 0))
    }
}

private struct LegacyArrowKeyMonitor: NSViewRepresentable {
    let action: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.action = action
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator = context.coordinator] event in
            guard let coordinator, let window = coordinator.view?.window, window === NSApp.keyWindow,
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
            switch event.keyCode {
            case 126: coordinator.action?(-1); return nil
            case 125: coordinator.action?(1); return nil
            default: return event
            }
        }
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { context.coordinator.action = action }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
        coordinator.monitor = nil
    }
    final class Coordinator {
        weak var view: NSView?
        var action: ((Int) -> Void)?
        var monitor: Any?
    }
}

enum LegacyResizePosition: Equatable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

extension NSCursor {
    /// Older AppKit lacks the system's diagonal frame-resize cursors.
    static func legacyFrameResize(position: LegacyResizePosition) -> NSCursor {
        switch position {
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        case .topLeft, .bottomRight: return diagonalResize(angle: -45)
        case .topRight, .bottomLeft: return diagonalResize(angle: 45)
        }
    }

    private static func diagonalResize(angle: CGFloat) -> NSCursor {
        let image = NSImage(size: NSSize(width: 24, height: 24))
        image.lockFocus()
        NSGraphicsContext.current?.cgContext.translateBy(x: 12, y: 12)
        NSGraphicsContext.current?.cgContext.rotate(by: angle * .pi / 180)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: -8, y: 0)); path.line(to: NSPoint(x: 8, y: 0))
        path.move(to: NSPoint(x: -4, y: 4)); path.line(to: NSPoint(x: -8, y: 0)); path.line(to: NSPoint(x: -4, y: -4))
        path.move(to: NSPoint(x: 4, y: 4)); path.line(to: NSPoint(x: 8, y: 0)); path.line(to: NSPoint(x: 4, y: -4))
        NSColor.black.setStroke(); path.lineWidth = 4; path.stroke()
        NSColor.white.setStroke(); path.lineWidth = 2; path.stroke()
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }
}
