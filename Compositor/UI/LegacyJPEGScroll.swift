import AppKit
import SwiftUI

/// NSScrollView preserves scroll, drag-to-pan, and zoom centering on Ventura.
struct LegacyJPEGScroll: NSViewRepresentable {
    let image: CGImage
    let imageSize: CGSize
    let viewport: CGSize
    let zoom: Double
    let onFit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = ImageView()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let document = scroll.documentView as? ImageView else { return }
        let oldSize = document.frame.size
        let oldOffset = scroll.contentView.bounds.origin
        let center = oldSize.width > 0 && oldSize.height > 0
            ? CGPoint(x: (oldOffset.x + viewport.width / 2) / oldSize.width,
                      y: (oldOffset.y + viewport.height / 2) / oldSize.height)
            : CGPoint(x: 0.5, y: 0.5)
        let size = CGSize(width: max(viewport.width, imageSize.width), height: max(viewport.height, imageSize.height))
        let changed = document.frame.size != size
        document.image = image
        document.imageSize = imageSize
        document.zoom = zoom
        document.onFit = onFit
        document.frame.size = size
        document.needsDisplay = true
        if changed {
            scroll.contentView.scroll(to: CGPoint(
                x: min(max(0, center.x * size.width - viewport.width / 2), max(0, size.width - viewport.width)),
                y: min(max(0, center.y * size.height - viewport.height / 2), max(0, size.height - viewport.height))))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    final class ImageView: NSView {
        var image: CGImage?
        var imageSize = CGSize.zero
        var zoom: Double = 1
        var onFit: (() -> Void)?
        override var isFlipped: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            guard let image else { return }
            NSGraphicsContext.current?.imageInterpolation = zoom >= 1 ? .none : .high
            let rect = CGRect(x: (bounds.width - imageSize.width) / 2,
                              y: (bounds.height - imageSize.height) / 2,
                              width: imageSize.width, height: imageSize.height)
            NSImage(cgImage: image, size: imageSize).draw(in: rect, from: .zero, operation: .sourceOver,
                                                        fraction: 1, respectFlipped: true, hints: nil)
        }

        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { onFit?(); return }
            guard let scroll = enclosingScrollView, let window else { return }
            let start = event.locationInWindow
            let offset = scroll.contentView.bounds.origin
            NSCursor.closedHand.push()
            defer { NSCursor.pop() }
            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
                if next.type == .leftMouseUp { break }
                let point = CGPoint(x: offset.x - (next.locationInWindow.x - start.x),
                                    y: offset.y + (next.locationInWindow.y - start.y))
                let viewport = scroll.contentView.bounds.size
                scroll.contentView.scroll(to: CGPoint(x: min(max(0, point.x), max(0, bounds.width - viewport.width)),
                                                      y: min(max(0, point.y), max(0, bounds.height - viewport.height))))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
        }
    }
}
