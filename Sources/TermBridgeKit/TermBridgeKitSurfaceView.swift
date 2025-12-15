import AppKit
import SwiftUI
import GhosttyKit

/// SwiftUI wrapper that embeds the live Ghostty surface.
public struct TermBridgeKitSurfaceView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> SurfaceContainerView {
        SurfaceContainerView(runtime: .shared)
    }

    public func updateNSView(_ nsView: SurfaceContainerView, context: Context) {}
}

/// NSView subclass that holds the Ghostty surface and forwards basic input.
public final class SurfaceContainerView: NSView {
    private let runtime: TermBridgeKitRuntime
    private var surface: ghostty_surface_t?
    private var renderTimer: Timer?
    private var trackingArea: NSTrackingArea?
    private var keyMonitor: Any?
    private let debugInputLogging = ProcessInfo.processInfo.environment["TERMBRIDGEKIT_DEBUG_INPUT"] == "1"
    private var lastMouseLog: TimeInterval = 0
    private let mouseLogInterval: TimeInterval = 0.05

    init(runtime: TermBridgeKitRuntime) {
        self.runtime = runtime
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        createSurfaceIfNeeded()
        bringToFrontAndFocus()
        installKeyMonitor()
        startRenderLoop()
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        createSurfaceIfNeeded()
    }

    deinit {
        if let surface {
            ghostty_surface_free(surface)
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    // MARK: Focus

    public override var acceptsFirstResponder: Bool { true }
    public override var canBecomeKeyView: Bool { true }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        setSurfaceFocus(true)
        logInput("became first responder: \(ok)")
        return ok
    }

    public override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        setSurfaceFocus(false)
        logInput("resigned first responder: \(ok)")
        return ok
    }

    // MARK: Layout

    public override func layout() {
        super.layout()
        updateSurfaceSize()
    }

    public override func updateLayer() {
        super.updateLayer()
        updateSurfaceSize()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    private func updateSurfaceSize() {
        guard let surface else { return }
        let scale = Double(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0)
        ghostty_surface_set_content_scale(surface, scale, scale)
        let width = UInt32(bounds.width * scale)
        let height = UInt32(bounds.height * scale)
        ghostty_surface_set_size(surface, width, height)
        ghostty_surface_refresh(surface)
        ghostty_surface_draw(surface)
    }

    // MARK: Rendering

    private func startRenderLoop() {
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, let surface = self.surface else { return }
            ghostty_surface_draw(surface)
        }
    }

    // MARK: Surface init

    private func createSurfaceIfNeeded() {
        guard surface == nil, let app = runtime.app else { return }

        var cfg = ghostty_surface_config_new()
        cfg.userdata = Unmanaged.passUnretained(self).toOpaque()
        cfg.platform_tag = GHOSTTY_PLATFORM_MACOS
        cfg.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(
            nsview: Unmanaged.passUnretained(self).toOpaque()
        ))
        cfg.scale_factor = Double(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0)
        cfg.font_size = 0
        cfg.wait_after_command = false

        guard let created = ghostty_surface_new(app, &cfg) else { return }
        surface = created
        setSurfaceFocus(true)
        updateSurfaceSize()
        ghostty_surface_refresh(created)
        ghostty_surface_draw(created)
        if renderTimer == nil {
            startRenderLoop()
        }
    }

    private func setSurfaceFocus(_ focused: Bool) {
        guard let surface else { return }
        ghostty_surface_set_focus(surface, focused)
    }

    // MARK: Input

    public override func keyDown(with event: NSEvent) {
        sendKeyEvent(event, action: event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS)
    }

    public override func keyUp(with event: NSEvent) {
        sendKeyEvent(event, action: GHOSTTY_ACTION_RELEASE)
    }

    private func modsFromFlags(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var raw = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { raw |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { raw |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { raw |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { raw |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { raw |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(rawValue: raw)
    }

    private func consumedMods(from event: NSEvent, surface: ghostty_surface_t) -> ghostty_input_mods_e {
        // Ask Ghostty to translate modifiers (for option-as-alt, etc) and drop command/control
        // so the engine knows which modifiers contributed to text generation.
        let translated = ghostty_surface_key_translation_mods(surface, modsFromFlags(event.modifierFlags))
        var raw = translated.rawValue
        raw &= ~GHOSTTY_MODS_CTRL.rawValue
        raw &= ~GHOSTTY_MODS_SUPER.rawValue
        return ghostty_input_mods_e(rawValue: raw)
    }

    private func unshiftedCodepoint(from event: NSEvent) -> UInt32 {
        guard event.type == .keyDown || event.type == .keyUp,
              let chars = event.characters(byApplyingModifiers: []),
              let scalar = chars.unicodeScalars.first
        else {
            return 0
        }
        return scalar.value
    }

    private func translatedText(from event: NSEvent) -> String? {
        guard let chars = event.characters else { return nil }
        if chars.count == 1, let scalar = chars.unicodeScalars.first {
            // Let Ghostty handle control characters itself.
            if scalar.value < 0x20 {
                return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control))
            }
            // Ignore private-use range for function keys.
            if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
                return nil
            }
        }
        return chars
    }

    private func sendKeyEvent(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }

        var keyEvent = ghostty_input_key_s(
            action: action,
            mods: modsFromFlags(event.modifierFlags),
            consumed_mods: consumedMods(from: event, surface: surface),
            keycode: UInt32(event.keyCode),
            text: nil,
            unshifted_codepoint: unshiftedCodepoint(from: event),
            composing: false
        )

        if let text = translatedText(from: event) {
            let utf8 = text.utf8CString
            utf8.withUnsafeBufferPointer { buffer in
                keyEvent.text = buffer.baseAddress
                ghostty_surface_key(surface, keyEvent)
            }
        } else {
            ghostty_surface_key(surface, keyEvent)
        }
        logInput("key \(action == GHOSTTY_ACTION_RELEASE ? "up" : "down") keyCode=\(event.keyCode) mods=0x\(String(modsFromFlags(event.modifierFlags).rawValue, radix: 16)) text=\(translatedText(from: event) ?? "<nil>")")
    }

    // MARK: Mouse

    public override func mouseDown(with event: NSEvent) {
        bringToFrontAndFocus()
        setSurfaceFocus(true)
        logInput("mouseDown button=\(event.buttonNumber) loc=\(event.locationInWindow)")
        sendMouse(event, state: GHOSTTY_MOUSE_PRESS)
    }

    public override func mouseUp(with event: NSEvent) {
        logInput("mouseUp button=\(event.buttonNumber) loc=\(event.locationInWindow)")
        sendMouse(event, state: GHOSTTY_MOUSE_RELEASE)
    }

    public override func rightMouseDown(with event: NSEvent) {
        mouseDown(with: event)
    }

    public override func rightMouseUp(with event: NSEvent) {
        mouseUp(with: event)
    }

    public override func otherMouseDown(with event: NSEvent) {
        logInput("otherMouseDown button=\(event.buttonNumber) loc=\(event.locationInWindow)")
        mouseDown(with: event)
    }

    public override func otherMouseUp(with event: NSEvent) {
        logInput("otherMouseUp button=\(event.buttonNumber) loc=\(event.locationInWindow)")
        mouseUp(with: event)
    }

    public override func mouseDragged(with event: NSEvent) {
        sendMouseMove(event)
    }

    public override func rightMouseDragged(with event: NSEvent) {
        sendMouseMove(event)
    }

    public override func otherMouseDragged(with event: NSEvent) {
        sendMouseMove(event)
    }

    public override func mouseMoved(with event: NSEvent) {
        sendMouseMove(event)
    }

    public override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        let mods = modsFromFlags(event.modifierFlags)
        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, ghostty_input_scroll_mods_t(mods.rawValue))
        logInput("scroll dx=\(event.scrollingDeltaX) dy=\(event.scrollingDeltaY) mods=0x\(String(mods.rawValue, radix: 16))")
    }

    private func sendMouse(_ event: NSEvent, state: ghostty_input_mouse_state_e) {
        guard let surface else { return }
        let mods = modsFromFlags(event.modifierFlags)
        let button = mouseButton(from: event)
        ghostty_surface_mouse_button(surface, state, button, mods)
        sendMouseMove(event)
    }

    private func sendMouseMove(_ event: NSEvent) {
        guard let surface else { return }
        let location = convert(event.locationInWindow, from: nil)
        let mods = modsFromFlags(event.modifierFlags)
        let flippedY = bounds.height - location.y
        ghostty_surface_mouse_pos(surface, location.x, flippedY, mods)
        logMouseInput("mouseMove x=\(location.x) y=\(location.y) mods=0x\(String(mods.rawValue, radix: 16))")
    }

    private func mouseButton(from event: NSEvent) -> ghostty_input_mouse_button_e {
        switch event.buttonNumber {
        case 0:
            return GHOSTTY_MOUSE_LEFT
        case 1:
            return GHOSTTY_MOUSE_RIGHT
        case 2:
            return GHOSTTY_MOUSE_MIDDLE
        default:
            return GHOSTTY_MOUSE_UNKNOWN
        }
    }

    private func bringToFrontAndFocus() {
        // Make sure the app and window are active before requesting first responder.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.acceptsMouseMovedEvents = true
        // Defer to next runloop to ensure the window is ready.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
            self.logInput("requested first responder (keyWindow=\(self.window?.isKeyWindow == true), appActive=\(NSApp.isActive))")
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            self.logInput("monitor saw \(event.type == .keyDown ? "down" : "up") keyCode=\(event.keyCode) mods=0x\(String(self.modsFromFlags(event.modifierFlags).rawValue, radix: 16)) isKeyWindow=\(self.window?.isKeyWindow == true) firstResponder=\(String(describing: self.window?.firstResponder))")
            switch event.type {
            case .keyDown:
                self.sendKeyEvent(event, action: event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS)
                return nil
            case .keyUp:
                self.sendKeyEvent(event, action: GHOSTTY_ACTION_RELEASE)
                return nil
            default:
                return event
            }
        }
    }

    // MARK: Debug

    private func logInput(_ message: String) {
        guard debugInputLogging else { return }
        NSLog("[TermBridgeKitSurface] \(message)")
    }

    private func logMouseInput(_ message: String) {
        guard debugInputLogging else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastMouseLog >= mouseLogInterval {
            lastMouseLog = now
            NSLog("[TermBridgeKitSurface] \(message)")
        }
    }
}
