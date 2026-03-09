import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

private let tapThreshold: CFTimeInterval = 0.30

private enum InputRole: Int {
    case english
    case chinese

    var title: String {
        switch self {
        case .english:
            return "英文"
        case .chinese:
            return "中文"
        }
    }

    var defaultsKey: String {
        switch self {
        case .english:
            return "selectedEnglishInputSourceID"
        case .chinese:
            return "selectedChineseInputSourceID"
        }
    }
}

private enum ShiftSide {
    case left
    case right

    var role: InputRole {
        switch self {
        case .left:
            return .english
        case .right:
            return .chinese
        }
    }
}

private struct InputSourceDescriptor: Hashable {
    let id: String
    let localizedName: String
    let languages: [String]
    let type: String
    let isASCIICapable: Bool
    let isEnabled: Bool
    let isEnableCapable: Bool
    let isSelectCapable: Bool
}

private final class InputSourceController {
    private let defaults = UserDefaults.standard

    init() {
        bootstrapSelectionsIfNeeded()
    }

    func bootstrapSelectionsIfNeeded() {
        if defaults.string(forKey: InputRole.english.defaultsKey) == nil,
           let english = autoDetectEnglishSource() {
            defaults.set(english.id, forKey: InputRole.english.defaultsKey)
        }

        if defaults.string(forKey: InputRole.chinese.defaultsKey) == nil,
           let chinese = autoDetectChineseSource() {
            defaults.set(chinese.id, forKey: InputRole.chinese.defaultsKey)
        }
    }

    func selectedSourceID(for role: InputRole) -> String? {
        defaults.string(forKey: role.defaultsKey)
    }

    func selectedSource(for role: InputRole) -> InputSourceDescriptor? {
        guard let id = selectedSourceID(for: role) else {
            return nil
        }

        if let enabled = descriptor(forID: id, includeAllInstalled: false) {
            return enabled
        }

        return descriptor(forID: id, includeAllInstalled: true)
    }

    func setSelectedSource(id: String, for role: InputRole) {
        defaults.set(id, forKey: role.defaultsKey)
    }

    @discardableResult
    func switchToRole(_ role: InputRole) -> Bool {
        if let configuredID = selectedSourceID(for: role),
           switchToInputSource(id: configuredID) {
            return true
        }

        let fallback: InputSourceDescriptor?
        switch role {
        case .english:
            fallback = autoDetectEnglishSource()
        case .chinese:
            fallback = autoDetectChineseSource()
        }

        guard let fallback else {
            return false
        }

        setSelectedSource(id: fallback.id, for: role)
        return switchToInputSource(id: fallback.id)
    }

    @discardableResult
    func switchToInputSource(id: String) -> Bool {
        if let source = inputSource(forID: id, includeAllInstalled: false) {
            return TISSelectInputSource(source) == noErr
        }

        guard let source = inputSource(forID: id, includeAllInstalled: true) else {
            return false
        }

        if boolProperty(source, key: kTISPropertyInputSourceIsEnableCapable),
           !boolProperty(source, key: kTISPropertyInputSourceIsEnabled),
           TISEnableInputSource(source) != noErr {
            return false
        }

        return TISSelectInputSource(source) == noErr
    }

    func currentSource() -> InputSourceDescriptor? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        return descriptor(from: source)
    }

    func englishCandidates() -> [InputSourceDescriptor] {
        let asciiSources = allInstalledKeyboardSources()
            .compactMap { descriptor(from: $0) }
            .filter { $0.isASCIICapable && $0.isSelectCapable }

        let layouts = asciiSources
            .filter { $0.type == (kTISTypeKeyboardLayout as String) }
            .sorted(by: compareCandidates)

        if !layouts.isEmpty {
            return deduplicated(layouts)
        }

        return deduplicated(asciiSources.sorted(by: compareCandidates))
    }

    func chineseCandidates() -> [InputSourceDescriptor] {
        let sources = allInstalledKeyboardSources()
            .compactMap { descriptor(from: $0) }
            .filter { $0.isSelectCapable }
            .filter { descriptorLooksChinese($0) }
            .sorted(by: compareCandidates)

        return deduplicated(sources)
    }

    func autoDetectEnglishSource() -> InputSourceDescriptor? {
        if let preferred = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
           let descriptor = descriptor(from: preferred),
           descriptor.isSelectCapable {
            return descriptor
        }

        let candidates = englishCandidates()
        return candidates.first(where: { $0.id == "com.apple.keylayout.ABC" || $0.id == "com.apple.keylayout.US" })
            ?? candidates.first
    }

    func autoDetectChineseSource() -> InputSourceDescriptor? {
        if let current = currentSource(), descriptorLooksChinese(current) {
            return current
        }

        if let source = TISCopyInputSourceForLanguage("zh-Hans" as CFString)?.takeRetainedValue(),
           let descriptor = descriptor(from: source),
           descriptor.isEnabled,
           descriptor.isSelectCapable {
            return descriptor
        }

        if let source = TISCopyInputSourceForLanguage("zh-Hant" as CFString)?.takeRetainedValue(),
           let descriptor = descriptor(from: source),
           descriptor.isEnabled,
           descriptor.isSelectCapable {
            return descriptor
        }

        return chineseCandidates().first
    }

    func statusBadgeText() -> String {
        guard let current = currentSource() else {
            return "IM"
        }

        if current.id == selectedSourceID(for: .english) {
            return "EN"
        }

        if current.id == selectedSourceID(for: .chinese) {
            return "中"
        }

        let compact = current.localizedName
            .replacingOccurrences(of: " ", with: "")
            .prefix(2)

        return compact.isEmpty ? "IM" : String(compact)
    }

    private func allEnabledKeyboardSources() -> [InputSourceDescriptor] {
        deduplicated(
            allInstalledKeyboardSources()
            .compactMap { descriptor(from: $0) }
            .filter { $0.isEnabled }
        )
    }

    private func allInstalledKeyboardSources() -> [TISInputSource] {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource
        ] as CFDictionary

        return TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
    }

    private func descriptor(forID id: String, includeAllInstalled: Bool) -> InputSourceDescriptor? {
        guard let source = inputSource(forID: id, includeAllInstalled: includeAllInstalled) else {
            return nil
        }

        return descriptor(from: source)
    }

    private func inputSource(forID id: String, includeAllInstalled: Bool) -> TISInputSource? {
        let filter = [
            kTISPropertyInputSourceID as String: id
        ] as CFDictionary

        let sources = (TISCreateInputSourceList(filter, includeAllInstalled)?.takeRetainedValue() as? [TISInputSource] ?? [])
        return sources.first
    }

    private func descriptor(from source: TISInputSource) -> InputSourceDescriptor? {
        guard let id = stringProperty(source, key: kTISPropertyInputSourceID),
              let localizedName = stringProperty(source, key: kTISPropertyLocalizedName) else {
            return nil
        }

        return InputSourceDescriptor(
            id: id,
            localizedName: localizedName,
            languages: stringArrayProperty(source, key: kTISPropertyInputSourceLanguages),
            type: stringProperty(source, key: kTISPropertyInputSourceType) ?? "",
            isASCIICapable: boolProperty(source, key: kTISPropertyInputSourceIsASCIICapable),
            isEnabled: boolProperty(source, key: kTISPropertyInputSourceIsEnabled),
            isEnableCapable: boolProperty(source, key: kTISPropertyInputSourceIsEnableCapable),
            isSelectCapable: boolProperty(source, key: kTISPropertyInputSourceIsSelectCapable)
        )
    }

    private func stringProperty(_ source: TISInputSource, key: CFString) -> String? {
        property(source, key: key) as? String
    }

    private func stringArrayProperty(_ source: TISInputSource, key: CFString) -> [String] {
        property(source, key: key) as? [String] ?? []
    }

    private func boolProperty(_ source: TISInputSource, key: CFString) -> Bool {
        property(source, key: key) as? Bool ?? false
    }

    private func property(_ source: TISInputSource, key: CFString) -> AnyObject? {
        guard let raw = TISGetInputSourceProperty(source, key) else {
            return nil
        }

        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
    }

    private func descriptorLooksChinese(_ descriptor: InputSourceDescriptor) -> Bool {
        if descriptor.languages.contains(where: { $0.lowercased().hasPrefix("zh") }) {
            return true
        }

        let haystack = "\(descriptor.id) \(descriptor.localizedName)".lowercased()
        let markers = ["pinyin", "sogou", "rime", "wubi", "zh", "拼音", "五笔", "双拼", "搜狗", "鼠须管", "仓颉", "注音"]
        return markers.contains(where: haystack.contains)
    }

    private func deduplicated(_ sources: [InputSourceDescriptor]) -> [InputSourceDescriptor] {
        var seen = Set<String>()
        return sources.filter { seen.insert($0.id).inserted }
    }

    private func compareByDisplayName(_ lhs: InputSourceDescriptor, _ rhs: InputSourceDescriptor) -> Bool {
        lhs.localizedName.localizedStandardCompare(rhs.localizedName) == .orderedAscending
    }

    private func compareCandidates(_ lhs: InputSourceDescriptor, _ rhs: InputSourceDescriptor) -> Bool {
        if lhs.isEnabled != rhs.isEnabled {
            return lhs.isEnabled && !rhs.isEnabled
        }

        return compareByDisplayName(lhs, rhs)
    }
}

private final class ShiftTapMonitor {
    private struct ShiftState {
        var isPressed = false
        var pressedAt: CFAbsoluteTime = 0
        var cancelled = false
    }

    private let onTap: (ShiftSide) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var leftState = ShiftState()
    private var rightState = ShiftState()

    init(onTap: @escaping (ShiftSide) -> Void) {
        self.onTap = onTap
    }

    deinit {
        stop()
    }

    var isRunning: Bool {
        eventTap != nil
    }

    func start() -> Bool {
        guard eventTap == nil else {
            return true
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<ShiftTapMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            monitor.handle(event: event, type: type)
            return Unmanaged.passUnretained(event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return false
        }

        self.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        return true
    }

    func stop() {
        guard let eventTap else {
            return
        }

        CGEvent.tapEnable(tap: eventTap, enable: false)

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        self.runLoopSource = nil
        self.eventTap = nil
    }

    private func handle(event: CGEvent, type: CGEventType) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        switch type {
        case .keyDown:
            cancelActiveShiftTaps()
        case .flagsChanged:
            handleFlagsChanged(event)
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        switch keyCode {
        case Int(kVK_Shift):
            toggleShift(side: .left, flags: event.flags)
        case Int(kVK_RightShift):
            toggleShift(side: .right, flags: event.flags)
        default:
            cancelActiveShiftTaps()
        }
    }

    private func toggleShift(side: ShiftSide, flags: CGEventFlags) {
        switch side {
        case .left:
            leftState = nextState(for: .left, current: leftState, other: &rightState, flags: flags)
        case .right:
            rightState = nextState(for: .right, current: rightState, other: &leftState, flags: flags)
        }
    }

    private func nextState(
        for side: ShiftSide,
        current: ShiftState,
        other: inout ShiftState,
        flags: CGEventFlags
    ) -> ShiftState {
        var updated = current

        if updated.isPressed {
            let duration = CFAbsoluteTimeGetCurrent() - updated.pressedAt
            let shouldTrigger = !updated.cancelled && duration <= tapThreshold
            updated = ShiftState()

            if shouldTrigger {
                onTap(side)
            }

            return updated
        }

        updated.isPressed = true
        updated.pressedAt = CFAbsoluteTimeGetCurrent()
        updated.cancelled = hasNonShiftModifiers(flags)

        if other.isPressed {
            updated.cancelled = true
            other.cancelled = true
        }

        return updated
    }

    private func cancelActiveShiftTaps() {
        if leftState.isPressed {
            leftState.cancelled = true
        }

        if rightState.isPressed {
            rightState.cancelled = true
        }
    }

    private func hasNonShiftModifiers(_ flags: CGEventFlags) -> Bool {
        let relevant: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn, .maskAlphaShift, .maskHelp]
        return !flags.intersection(relevant).isEmpty
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let inputController = InputSourceController()
    private lazy var tapMonitor = ShiftTapMonitor { [weak self] side in
        Task { @MainActor [weak self] in
            self?.switchForTap(side)
        }
    }

    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        registerInputSourceNotifications()
        refreshStatusItem()
        ensureMonitoringEnabled(requestIfNeeded: true)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        ensureMonitoringEnabled(requestIfNeeded: false)
        rebuildMenu()
    }

    @objc
    private func selectEnglishSource(_ sender: NSMenuItem) {
        selectSource(sender, role: .english)
    }

    @objc
    private func selectChineseSource(_ sender: NSMenuItem) {
        selectSource(sender, role: .chinese)
    }

    @objc
    private func requestMonitoringPermission(_ sender: NSMenuItem) {
        ensureMonitoringEnabled(requestIfNeeded: true)
        refreshStatusItem()
    }

    @objc
    private func reloadInputSources(_ sender: NSMenuItem) {
        inputController.bootstrapSelectionsIfNeeded()
        refreshStatusItem()
    }

    @objc
    private func resetToRecommendations(_ sender: NSMenuItem) {
        if let english = inputController.autoDetectEnglishSource() {
            inputController.setSelectedSource(id: english.id, for: .english)
        }

        if let chinese = inputController.autoDetectChineseSource() {
            inputController.setSelectedSource(id: chinese.id, for: .chinese)
        }

        refreshStatusItem()
    }

    @objc
    private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "IM"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else {
            return
        }

        menu.removeAllItems()

        let permissionGranted = CGPreflightListenEventAccess()
        let permissionText = permissionGranted ? "键盘监听权限：已授权" : "键盘监听权限：未授权"
        let permissionItem = NSMenuItem(title: permissionText, action: nil, keyEquivalent: "")
        permissionItem.isEnabled = false
        menu.addItem(permissionItem)

        if !permissionGranted {
            menu.addItem(makeActionItem(title: "请求键盘监听权限", action: #selector(requestMonitoringPermission(_:))))
            let hint = NSMenuItem(title: "若系统未弹窗，请到 系统设置 > 隐私与安全性 > 输入监控 手动开启", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
            menu.addItem(.separator())
        }

        let englishTitle = "左 Shift -> \(inputController.selectedSource(for: .english)?.localizedName ?? "未配置")"
        let englishItem = NSMenuItem(title: englishTitle, action: nil, keyEquivalent: "")
        englishItem.isEnabled = false
        menu.addItem(englishItem)
        addSelectionItems(for: .english, to: menu)

        menu.addItem(.separator())

        let chineseTitle = "右 Shift -> \(inputController.selectedSource(for: .chinese)?.localizedName ?? "未配置")"
        let chineseItem = NSMenuItem(title: chineseTitle, action: nil, keyEquivalent: "")
        chineseItem.isEnabled = false
        menu.addItem(chineseItem)
        addSelectionItems(for: .chinese, to: menu)

        menu.addItem(.separator())
        menu.addItem(makeActionItem(title: "重置为推荐输入源", action: #selector(resetToRecommendations(_:)), keyEquivalent: "r"))
        menu.addItem(makeActionItem(title: "重新加载输入源", action: #selector(reloadInputSources(_:)), keyEquivalent: "l"))
        menu.addItem(.separator())
        menu.addItem(makeActionItem(title: "退出", action: #selector(quit(_:)), keyEquivalent: "q"))
    }

    private func addSelectionItems(for role: InputRole, to menu: NSMenu) {
        let candidates = role == .english ? inputController.englishCandidates() : inputController.chineseCandidates()
        let selectedID = inputController.selectedSourceID(for: role)

        guard !candidates.isEmpty else {
            let item = NSMenuItem(title: "未找到可用\(role.title)输入源", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }

        for candidate in candidates {
            let item = NSMenuItem(
                title: displayTitle(for: candidate),
                action: role == .english ? #selector(selectEnglishSource(_:)) : #selector(selectChineseSource(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = candidate.id
            item.state = candidate.id == selectedID ? .on : .off
            menu.addItem(item)
        }
    }

    private func selectSource(_ sender: NSMenuItem, role: InputRole) {
        guard let id = sender.representedObject as? String else {
            return
        }

        inputController.setSelectedSource(id: id, for: role)
        refreshStatusItem()
    }

    private func switchForTap(_ side: ShiftSide) {
        guard inputController.switchToRole(side.role) else {
            NSSound.beep()
            return
        }

        refreshStatusItem()
    }

    private func ensureMonitoringEnabled(requestIfNeeded: Bool) {
        if CGPreflightListenEventAccess() {
            _ = tapMonitor.start()
            return
        }

        if requestIfNeeded {
            _ = CGRequestListenEventAccess()
        }

        if CGPreflightListenEventAccess() {
            _ = tapMonitor.start()
        } else {
            tapMonitor.stop()
        }
    }

    private func registerInputSourceNotifications() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(
            self,
            selector: #selector(selectedInputSourceChanged(_:)),
            name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )

        center.addObserver(
            self,
            selector: #selector(enabledInputSourcesChanged(_:)),
            name: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil
        )
    }

    private func refreshStatusItem() {
        statusItem.button?.title = inputController.statusBadgeText()
    }

    private func displayTitle(for source: InputSourceDescriptor) -> String {
        if source.isEnabled {
            return source.localizedName
        }

        if source.isEnableCapable {
            return "\(source.localizedName) (未启用，可自动启用)"
        }

        return "\(source.localizedName) (未启用)"
    }

    private func makeActionItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc
    private func selectedInputSourceChanged(_ notification: Notification) {
        refreshStatusItem()
    }

    @objc
    private func enabledInputSourcesChanged(_ notification: Notification) {
        inputController.bootstrapSelectionsIfNeeded()
        refreshStatusItem()
    }
}

@main
private enum ShiftKeyIMESwitchMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
