//
//  FloatWindow.swift
//  Fuwari
//
//  Created by Kengo Yokoyama on 2016/12/07.
//  Copyright © 2016年 AppKnop. All rights reserved.
//

import Cocoa
import Magnet
import Sauce
import Carbon

protocol FloatDelegate: AnyObject {
    func save(floatWindow: FloatWindow, image: CGImage)
    func close(floatWindow: FloatWindow)
}

class FloatWindow: NSWindow, NSWindowDelegate {

    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    weak var floatDelegate: FloatDelegate? = nil

    private struct ResizeEdges: OptionSet {
        let rawValue: Int

        static let left = ResizeEdges(rawValue: 1 << 0)
        static let right = ResizeEdges(rawValue: 1 << 1)
        static let bottom = ResizeEdges(rawValue: 1 << 2)
        static let top = ResizeEdges(rawValue: 1 << 3)
    }

    private var flagsMonitor: Any?
    private var isFreeResize = false
    private var isLiveResizing = false
    private var resizeEdges: ResizeEdges = []
    private var resizeAnchorFrame = NSRect.zero
    private let resizeEdgeInset = CGFloat(6.0)
    
    private var closeButton: NSButton!
    private var spaceButton: NSButton!
    private var allSpaceMenuItem: NSMenuItem!
    private var currentSpaceMenuItem: NSMenuItem!
    private var originalRect = NSRect()
    private var popUpLabel = NSTextField()
    private var windowScale = CGFloat(1.0)
    private var windowOpacity = CGFloat(1.0)
    private var spaceMode = SpaceMode.all {
        didSet {
            collectionBehavior = spaceMode.getCollectionBehavior()
            if spaceMode == .all {
                allSpaceMenuItem.state = .on
                currentSpaceMenuItem.state = .off
                
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = self.buttonOpacityDuration
                    self.spaceButton.animator().alphaValue = 0.0
                }, completionHandler: {
                    self.spaceButton.image = NSImage(named: "SpaceAll")
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = self.buttonOpacityDuration
                        self.spaceButton.animator().alphaValue = self.buttonOpacity
                    })
                })
            } else {
                allSpaceMenuItem.state = .off
                currentSpaceMenuItem.state = .on
                
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = self.buttonOpacityDuration
                    self.spaceButton.animator().alphaValue = 0.0
                }, completionHandler: {
                    self.spaceButton.image = NSImage(named: "SpaceCurrent")
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = self.buttonOpacityDuration
                        self.spaceButton.animator().alphaValue = self.buttonOpacity
                    })
                })
            }
        }
    }
    private let defaults = UserDefaults.standard
    private let windowScaleInterval = CGFloat(0.25)
    private let minWindowScale = CGFloat(0.25)
    private let maxWindowScale = CGFloat(2.5)
    private let buttonOpacity = CGFloat(0.5)
    private let buttonOpacityDuration = TimeInterval(0.3)
    
    init(contentRect: NSRect, styleMask style: NSWindow.StyleMask = [.borderless, .resizable], backing bufferingType: NSWindow.BackingStoreType = .buffered, defer flag: Bool = false, image: CGImage, spaceMode: SpaceMode) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        contentView = FloatView(frame: contentRect)
        originalRect = contentRect
        self.spaceMode = spaceMode
        collectionBehavior = spaceMode.getCollectionBehavior()
        level = .floating
        isMovableByWindowBackground = true
        hasShadow = true
        contentView?.wantsLayer = true
        contentView?.layer?.contents = image
        minSize = NSMakeSize(30, 30)
        animationBehavior = NSWindow.AnimationBehavior.alertPanel
        
        popUpLabel = NSTextField(frame: NSRect(x: 10, y: 10, width: 120, height: 26))
        popUpLabel.textColor = .white
        popUpLabel.font = NSFont.boldSystemFont(ofSize: 20)
        popUpLabel.alignment = .center
        popUpLabel.drawsBackground = true
        popUpLabel.backgroundColor = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.4)
        popUpLabel.wantsLayer = true
        popUpLabel.layer?.cornerRadius = 10.0
        popUpLabel.isBordered = false
        popUpLabel.isEditable = false
        popUpLabel.isSelectable = false
        popUpLabel.alphaValue = 0.0
        contentView?.addSubview(popUpLabel)

        if let image = NSImage(named: "Close") {
            closeButton = NSButton(frame: NSRect(x: 4, y: frame.height - 20, width: 16, height: 16))
            closeButton.image = image
            closeButton.imageScaling = .scaleProportionallyDown
            closeButton.isBordered = false
            closeButton.alphaValue = 0.0
            closeButton.target = self
            closeButton.action = #selector(closeWindow)
            contentView?.addSubview(closeButton)
        }
        
        if let image = NSImage(named: spaceMode == .all ? "SpaceAll" : "SpaceCurrent") {
            spaceButton = NSButton(frame: NSRect(x: frame.width - 20, y: frame.height - 20, width: 16, height: 16))
            spaceButton.image = image
            spaceButton.imageScaling = .scaleProportionallyDown
            spaceButton.isBordered = false
            spaceButton.alphaValue = 0.0
            spaceButton.target = self
            spaceButton.action = #selector(changeSpaceMode)
            contentView?.addSubview(spaceButton)
        }
        
        allSpaceMenuItem = NSMenuItem(title: LocalizedString.ShowAllSpaces.value, action: #selector(changeSpaceModeAll), keyEquivalent: "k")
        currentSpaceMenuItem = NSMenuItem(title: LocalizedString.ShowCurrentSpace.value, action: #selector(changeSpaceModeCurrent), keyEquivalent: "l")

        allSpaceMenuItem.state = spaceMode == .all ? .on : .off
        currentSpaceMenuItem.state = spaceMode == .all ? .off : .on
        
        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: LocalizedString.Copy.value, action: #selector(copyImage), keyEquivalent: "c"))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: LocalizedString.Save.value, action: #selector(saveImage), keyEquivalent: "s"))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: LocalizedString.Upload.value, action: #selector(uploadImage), keyEquivalent: ""))
        menu?.addItem(NSMenuItem(title: LocalizedString.Share.value, action: #selector(shareImage), keyEquivalent: ""))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: LocalizedString.ZoomReset.value, action: #selector(resetWindowScale), keyEquivalent: "r"))
        menu?.addItem(NSMenuItem(title: LocalizedString.ZoomIn.value, action: #selector(zoomInWindow), keyEquivalent: "+"))
        menu?.addItem(NSMenuItem(title: LocalizedString.ZoomOut.value, action: #selector(zoomOutWindow), keyEquivalent: "-"))
        menu?.addItem(allSpaceMenuItem)
        menu?.addItem(currentSpaceMenuItem)
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: LocalizedString.Close.value, action: #selector(closeWindow), keyEquivalent: "w"))

        delegate = self
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return event }
            if self.isKeyWindow && self.isLiveResizing {
                self.isFreeResize = event.modifierFlags.contains(.shift)
            }
            return event
        }
        fadeWindow(isIn: true)
    }

    deinit {
        if let flagsMonitor = flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        isLiveResizing = true
        isFreeResize = NSEvent.modifierFlags.contains(.shift)
        resizeAnchorFrame = frame
        resizeEdges = resizeEdges(for: NSEvent.mouseLocation, in: resizeAnchorFrame)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        isLiveResizing = false
        isFreeResize = false
        resizeEdges = []
        resizeAnchorFrame = .zero
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let shiftDown = isFreeResize
            || NSEvent.modifierFlags.contains(.shift)
            || (NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false)
        if shiftDown {
            if isLiveResizing && !resizeEdges.isEmpty {
                return freeResizeSize(for: NSEvent.mouseLocation)
            }
            return frameSize
        }
        guard originalRect.width > 0, originalRect.height > 0 else { return frameSize }
        let aspectRatio = originalRect.width / originalRect.height
        let widthFromHeight = frameSize.height * aspectRatio
        let heightFromWidth = frameSize.width / aspectRatio
        if abs(widthFromHeight - frameSize.width) < abs(heightFromWidth - frameSize.height) {
            return NSSize(width: widthFromHeight, height: frameSize.height)
        }
        return NSSize(width: frameSize.width, height: heightFromWidth)
    }

    func windowDidResize(_ notification: Notification) {
        windowScale = frame.width > frame.height ? frame.height / originalRect.height : frame.width / originalRect.width
        closeButton.frame = NSRect(x: 4, y: frame.height - 20, width: 16, height: 16)
        spaceButton.frame = NSRect(x: frame.width - 20, y: frame.height - 20, width: 16, height: 16)
        showPopUp(text: "\(Int(windowScale * 100))%")
    }

    private func resizeEdges(for mouseLocation: NSPoint, in frame: NSRect) -> ResizeEdges {
        var edges: ResizeEdges = []
        let leftDistance = abs(mouseLocation.x - frame.minX)
        let rightDistance = abs(mouseLocation.x - frame.maxX)
        if min(leftDistance, rightDistance) <= resizeEdgeInset {
            edges.insert(leftDistance <= rightDistance ? .left : .right)
        }

        let bottomDistance = abs(mouseLocation.y - frame.minY)
        let topDistance = abs(mouseLocation.y - frame.maxY)
        if min(bottomDistance, topDistance) <= resizeEdgeInset {
            edges.insert(bottomDistance <= topDistance ? .bottom : .top)
        }
        if !edges.contains(.left) && !edges.contains(.right) {
            edges.insert(mouseLocation.x < frame.midX ? .left : .right)
        }
        if !edges.contains(.bottom) && !edges.contains(.top) {
            edges.insert(mouseLocation.y < frame.midY ? .bottom : .top)
        }
        return edges
    }

    private func freeResizeSize(for mouseLocation: NSPoint) -> NSSize {
        let frame = resizeAnchorFrame
        var width = frame.width
        var height = frame.height

        if resizeEdges.contains(.left) {
            width = frame.maxX - mouseLocation.x
        } else if resizeEdges.contains(.right) {
            width = mouseLocation.x - frame.minX
        }
        if resizeEdges.contains(.bottom) {
            height = frame.maxY - mouseLocation.y
        } else if resizeEdges.contains(.top) {
            height = mouseLocation.y - frame.minY
        }

        if width < minSize.width { width = minSize.width }
        if height < minSize.height { height = minSize.height }

        return NSSize(width: width, height: height)
    }
    
    override func keyDown(with event: NSEvent) {
        guard let key = Sauce.shared.key(for: Int(event.keyCode)) else { return }

        var moveOffset = (dx: 0.0, dy: 0.0)
        switch key {
        case .leftArrow:
            moveOffset = (dx: -1, dy: 0)
        case .rightArrow:
            moveOffset = (dx: 1, dy: 0)
        case .upArrow:
            moveOffset = (dx: 0, dy: 1)
        case .downArrow:
            moveOffset = (dx: 0, dy: -1)
        case .escape:
            closeWindow()
        default:
            break
        }
        
        if event.modifierFlags.rawValue & NSEvent.ModifierFlags.shift.rawValue != 0 {
            moveOffset = (moveOffset.dx * 10, moveOffset.dy * 10)
        }

        if moveOffset.dx != 0.0 || moveOffset.dy != 0.0 {
            guard let screen = screen else { return }

            // clamp offset
            if frame.origin.x + moveOffset.dx < screen.frame.origin.x - (frame.width / 2) || (screen.frame.origin.x + screen.frame.width) - (frame.width / 2) < frame.origin.x + moveOffset.dx {
                moveOffset.dx = 0
            }
            if frame.origin.y + moveOffset.dy < screen.frame.origin.y - (frame.height / 2) || (screen.frame.origin.y + screen.frame.height) - (frame.height / 2) < frame.origin.y + moveOffset.dy {
                moveOffset.dy = 0
            }
            
            moveWindow(dx: moveOffset.dx, dy: moveOffset.dy)
        }
            
        if event.modifierFlags.rawValue & NSEvent.ModifierFlags.command.rawValue != 0 {
            switch key {
            case .s:
                saveImage()
            case .c:
                copyImage()
            case .k:
                changeSpaceModeAll()
            case .l:
                changeSpaceModeCurrent()
            case .zero, .keypadZero:
                resetWindow()
            case .one, .keypadOne:
                resetWindowScale()
            case .equal, .six, .semicolon, .keypadPlus:
                zoomInWindow()
            case .minus, .keypadMinus:
                zoomOutWindow()
            case .w:
                closeWindow()
            default:
                break
            }
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        if let menu = menu, let contentView = contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = self.buttonOpacityDuration
            self.closeButton.animator().alphaValue = self.buttonOpacity
            self.spaceButton.animator().alphaValue = self.buttonOpacity
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = self.buttonOpacityDuration
            self.closeButton.animator().alphaValue = 0.0
            self.spaceButton.animator().alphaValue = 0.0
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        let min = CGFloat(0.1), max = CGFloat(1.0)
        if windowOpacity > min || windowOpacity < max {
            windowOpacity += event.deltaY * 0.005
            if windowOpacity < min { windowOpacity = min }
            else if windowOpacity > max { windowOpacity = max }
            alphaValue = windowOpacity
        }
    }
    
    override func performClose(_ sender: Any?) {
        closeWindow()
    }
  
    override func mouseDown(with event: NSEvent) {
        let movingOpacity = defaults.float(forKey: Constants.UserDefaults.movingOpacity)
        if movingOpacity < 1 {
            alphaValue = CGFloat(movingOpacity)
        }
        closeButton.alphaValue = 0.0
        spaceButton.alphaValue = 0.0
    }
    
    override func mouseUp(with event: NSEvent) {
        alphaValue = windowOpacity
        closeButton.alphaValue = buttonOpacity
        spaceButton.alphaValue = buttonOpacity
        // Double click to close
        if event.clickCount >= 2 {
            closeWindow()
        }
    }
    
    @objc private func saveImage() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            if let image = self.contentView?.layer?.contents {
                self.showPopUp(text: "Save")
                self.floatDelegate?.save(floatWindow: self, image: image as! CGImage)
            }
        }
    }
    
    @objc private func copyImage() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            if let image = self.contentView?.layer?.contents {
                let cgImage = image as! CGImage
                let size = CGSize(width: cgImage.width, height: cgImage.height)
                let nsImage = NSImage(cgImage: cgImage, size: size)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([nsImage])
                self.showPopUp(text: "Copy")
            }
        }
    }
    
    @objc private func uploadImage() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            if let image = self.contentView?.layer?.contents {
                let cgImage = image as! CGImage
                let size = CGSize(width: cgImage.width, height: cgImage.height)
                let nsImage = NSImage(cgImage: cgImage, size: size)
                GyazoManager.shared.uploadImage(image: nsImage)
            }
        }
    }

    @objc private func shareImage() {
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            guard let contentView = self.contentView else { return }
            guard let cgImage = contentView.layer?.contents as! CGImage? else { return }
            let size = CGSize(width: cgImage.width, height: cgImage.height)
            let nsImage = NSImage(cgImage: cgImage, size: size)
            let picker = NSSharingServicePicker(items: [nsImage])
            let targetRect = NSRect(
                x: contentView.bounds.midX,
                y: contentView.bounds.midY,
                width: 1,
                height: 1
            )
            picker.show(relativeTo: targetRect, of: contentView, preferredEdge: .minY)
        }
    }
    
    @objc private func zoomInWindow() {
        let scale = floor((windowScale + windowScaleInterval) * 100) / 100
        if scale <= maxWindowScale {
            windowScale = scale
            setFrame(NSRect(x: frame.origin.x - (originalRect.width / 2 * windowScaleInterval), y: frame.origin.y - (originalRect.height / 2 * windowScaleInterval), width: originalRect.width * windowScale, height: originalRect.height * windowScale), display: true, animate: true)
        }
        
        showPopUp(text: "\(Int(windowScale * 100))%")
    }
    
    @objc private func zoomOutWindow() {
        let scale = floor((windowScale - windowScaleInterval) * 100) / 100
        if scale >= minWindowScale {
            windowScale = scale
            setFrame(NSRect(x: frame.origin.x + (originalRect.width / 2 * windowScaleInterval), y: frame.origin.y + (originalRect.height / 2 * windowScaleInterval), width: originalRect.width * windowScale, height: originalRect.height * windowScale), display: true, animate: true)
        }
        
        showPopUp(text: "\(Int(windowScale * 100))%")
    }
    
    @objc private func moveWindow(dx: CGFloat, dy: CGFloat) {
        setFrame(NSRect(x: frame.origin.x + dx, y: frame.origin.y + dy, width: frame.width, height: frame.height), display: true, animate: true)
        showPopUp(text: "(\(Int(frame.origin.x)),\(Int(frame.origin.y)))")
    }
    
    @objc private func resetWindowScale() {
        let diffScale = 1.0 - windowScale
        windowScale = CGFloat(1.0)
        setFrame(NSRect(x: frame.origin.x - (originalRect.width * diffScale / 2), y: frame.origin.y - (originalRect.height * diffScale / 2), width: originalRect.width * windowScale, height: originalRect.height * windowScale), display: true, animate: true)
        showPopUp(text: "\(Int(windowScale * 100))%")
    }
    
    @objc private func resetWindow() {
        windowScale = CGFloat(1.0)
        setFrame(originalRect, display: true, animate: true)
    }

    @objc private func changeSpaceModeAll() {
        spaceMode = .all
    }
    
    @objc private func changeSpaceModeCurrent() {
        spaceMode = .current
    }
    
    @objc private func changeSpaceMode() {
        spaceMode = spaceMode == .all ? .current : .all
    }
    
    @objc private func closeWindow() {
        floatDelegate?.close(floatWindow: self)
    }
    
    private func showPopUp(text: String, duration: Double = 0.5, interval: Double = 0.5) {
        popUpLabel.stringValue = text
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            popUpLabel.animator().alphaValue = 1.0
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = duration
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    self.popUpLabel.animator().alphaValue = 0.0
                })
            }
        }
    }
    
    internal override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(resetWindowScale) {
            return windowScale != CGFloat(1.0)
        }
        return true
    }
    
    func fadeWindow(isIn: Bool, completion: (() -> Void)? = nil) {
        makeKeyAndOrderFront(self)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = isIn ? 1.0 : 0.0
        }, completionHandler: { [weak self] in
            if !isIn {
                self?.orderOut(self)
            }
            completion?()
        })
    }
}
