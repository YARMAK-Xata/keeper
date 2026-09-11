import AppKit
import ApplicationServices

/// A thin, typed view over one AXUIElement. All calls are synchronous and may take up to the
/// messaging timeout if the target app is hung, so use from a background queue when scanning.
struct AXElement {
    let ref: AXUIElement

    init(_ ref: AXUIElement) { self.ref = ref }

    static func application(pid: pid_t) -> AXElement { AXElement(AXUIElementCreateApplication(pid)) }

    func raw(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(ref, attribute as CFString, &value) == .success ? value : nil
    }

    private func elements(_ attribute: String) -> [AXElement] {
        guard let array = raw(attribute) as? [AnyObject] else { return [] }
        return array.compactMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? AXElement($0 as! AXUIElement) : nil }
    }

    private func element(_ attribute: String) -> AXElement? {
        guard let value = raw(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AXElement(value as! AXUIElement)
    }

    var role: String { raw(kAXRoleAttribute) as? String ?? "" }
    var title: String { raw(kAXTitleAttribute) as? String ?? "" }
    var children: [AXElement] { elements(kAXChildrenAttribute) }
    var windows: [AXElement] { elements(kAXWindowsAttribute) }
    var focusedWindow: AXElement? { element(kAXFocusedWindowAttribute) }
    var isMinimized: Bool { (raw(kAXMinimizedAttribute) as? Bool) ?? false }
    var intValue: Int? { (raw(kAXValueAttribute) as? NSNumber)?.intValue }

    /// AXURL (a CFURL) with AXDocument (a string) as fallback.
    var url: URL? {
        if let value = raw(kAXURLAttribute) {
            if let url = value as? URL { return url }
            if let string = value as? String, let url = URL(string: string) { return url }
        }
        if let string = raw(kAXDocumentAttribute) as? String, let url = URL(string: string) { return url }
        return nil
    }

    /// Screen frame with a top-left origin.
    var frame: CGRect? {
        guard let p = raw(kAXPositionAttribute), let s = raw(kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }

    @discardableResult
    func set(_ attribute: String, _ flag: Bool) -> Bool {
        AXUIElementSetAttributeValue(ref, attribute as CFString, (flag ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef) == .success
    }

    @discardableResult
    func perform(_ action: String) -> Bool { AXUIElementPerformAction(ref, action as CFString) == .success }

    func setTimeout(_ seconds: Float) { AXUIElementSetMessagingTimeout(ref, seconds) }

    func isSame(as other: AXElement) -> Bool { CFEqual(ref, other.ref) }

    var id: Int { Int(bitPattern: UInt(CFHash(ref))) }

    /// Breadth-first traversal. `visit` returns false to stop descending below that element.
    func walk(maxDepth: Int, maxNodes: Int, _ visit: (AXElement, Int) -> Bool) {
        var queue: [(AXElement, Int)] = [(self, 0)]
        var index = 0
        while index < queue.count, index < maxNodes {
            let (element, depth) = queue[index]
            index += 1
            guard visit(element, depth), depth < maxDepth else { continue }
            queue.append(contentsOf: element.children.map { ($0, depth + 1) })
        }
    }
}
