import AppKit
import QuartzCore

let warm = NSColor(calibratedRed: 0.99, green: 0.975, blue: 0.95, alpha: 1)
let ink = NSColor(calibratedRed: 0.24, green: 0.20, blue: 0.17, alpha: 1)
let accent = NSColor(calibratedRed: 0.72, green: 0.36, blue: 0.19, alpha: 1)

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class BubblePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PetView: NSView {
    weak var owner: Companion?
    var frames: [[NSImage]] = []
    var row = 0
    var index = 0
    var rowUntil = Date.distantPast
    var lastFrame = Date.distantPast
    var lastPointer = NSPoint.zero
    var pointerMoved = Date.distantPast
    var dragStart: NSPoint?
    var originStart = NSPoint.zero
    var dragged = false
    let durations: [[Double]] = [
        [0.28,0.11,0.11,0.14,0.14,0.32],
        [0.12,0.12,0.12,0.12,0.12,0.12,0.12,0.22],
        [0.12,0.12,0.12,0.12,0.12,0.12,0.12,0.22],
        [0.14,0.14,0.14,0.28], [0.14,0.14,0.14,0.14,0.28],
        [0.14,0.14,0.14,0.14,0.14,0.14,0.14,0.24],
        [0.15,0.15,0.15,0.15,0.15,0.26],
        [0.12,0.12,0.12,0.12,0.12,0.22],
        [0.15,0.15,0.15,0.15,0.15,0.28]
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("希久桌宠，点击查看提醒，拖动调整位置")
        guard let url = Bundle.main.url(forResource: "spritesheet", withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
        let counts = [6,8,8,4,5,8,6,6,6,8,8]
        for r in 0..<min(11, atlas.height / 208) {
            var cells: [NSImage] = []
            for c in 0..<counts[r] {
                if let cg = atlas.cropping(to: CGRect(x: c*192, y: r*208, width: 192, height: 208)) {
                    cells.append(NSImage(cgImage: cg, size: NSSize(width: 192, height: 208)))
                }
            }
            frames.append(cells)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { owner?.showNext(); return true }

    func animate(_ state: String, for seconds: Double = 3) {
        row = ["idle":0,"running-right":1,"running-left":2,"waving":3,"jumping":4,"failed":5,"waiting":6,"running":7,"review":8][state] ?? 0
        index = 0
        rowUntil = Date().addingTimeInterval(seconds)
        lastFrame = Date()
        needsDisplay = true
    }

    func tick() {
        let now = Date()
        let pointer = NSEvent.mouseLocation
        if hypot(pointer.x-lastPointer.x, pointer.y-lastPointer.y) > 2 {
            pointerMoved = now
            lastPointer = pointer
        }
        if now > rowUntil {
            if row != 0 { row = 0; index = 0 }
            if let win = window, now.timeIntervalSince(pointerMoved) < 1.5, dragStart == nil {
                let center = NSPoint(x: win.frame.midX, y: win.frame.minY + 105)
                let dx = pointer.x-center.x, dy = pointer.y-center.y
                let distance = hypot(dx, dy)
                if distance > 50 && distance < 480 && frames.count == 11 {
                    var angle = atan2(dx, dy) * 180 / .pi
                    if angle < 0 { angle += 360 }
                    let direction = Int((angle / 22.5).rounded()) % 16
                    row = 9 + direction / 8
                    index = direction % 8
                    needsDisplay = true
                    return
                }
            }
        }
        guard row < durations.count else { row = 0; index = 0; return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { index = 0; needsDisplay = true; return }
        if now.timeIntervalSince(lastFrame) >= durations[row][index % durations[row].count] {
            index = (index + 1) % durations[row].count
            lastFrame = now
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if row < frames.count && index < frames[row].count {
            frames[row][index].draw(in: NSRect(x: 5, y: 22, width: 180, height: 195))
        }
        let badge = NSBezierPath(roundedRect: NSRect(x: 60, y: 4, width: 70, height: 23), xRadius: 11, yRadius: 11)
        warm.withAlphaComponent(0.96).setFill(); badge.fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        let label = owner?.paused == true ? "希久 · 休息" : "希久"
        (label as NSString).draw(in: NSRect(x: 51, y: 7, width: 88, height: 17), withAttributes: [.font:NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor:ink, .paragraphStyle:paragraph])
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        dragStart = NSEvent.mouseLocation
        originStart = window.frame.origin
        dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let window else { return }
        let point = NSEvent.mouseLocation
        let dx = point.x-start.x, dy = point.y-start.y
        if hypot(dx, dy) > 3 { dragged = true }
        if dragged {
            window.setFrameOrigin(NSPoint(x: originStart.x+dx, y: originStart.y+dy))
            if row != (dx < 0 ? 2 : 1) { animate(dx < 0 ? "running-left" : "running-right", for: 1) }
            rowUntil = Date().addingTimeInterval(0.3)
            owner?.positionBubble()
        }
    }
    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        if dragged { owner?.savePosition() } else { owner?.showNext() }
    }
    override func rightMouseDown(with event: NSEvent) {
        if let menu = owner?.statusItem.menu { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }
}

func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = ink) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    field.isSelectable = false
    field.maximumNumberOfLines = 0
    return field
}

final class Companion: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let previewMode = CommandLine.arguments.contains("--export-preview")
    var pet: PetPanel!
    var petView: PetView!
    var bubble: BubblePanel!
    var statusItem: NSStatusItem!
    var routine: Routine!
    var current: ScheduledReminder?
    var queue: [ScheduledReminder] = []
    var snoozed: [ScheduledReminder] = []
    var delivered = Set<String>()
    var completed = Set<String>()
    var animationTimer: Timer?
    var reminderTimer: Timer?
    var summaryWindow: NSWindow?
    var lastDay = ""
    var paused = UserDefaults.standard.bool(forKey: "paused")
    var sound = UserDefaults.standard.object(forKey: "sound") as? Bool ?? true
    var demo = false
    var automaticallyHiddenBubbleAt: Date?
    let defaults = CommandLine.arguments.contains("--export-preview") ? UserDefaults(suiteName:"local.xijiu.companion.preview")! : UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard previewMode || NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.xijiu.companion").count < 2 else {
            NSApp.terminate(nil); return
        }
        do {
            let url = Bundle.main.url(forResource: "schedule", withExtension: "json")!
            routine = try JSONDecoder().decode(Routine.self, from: Data(contentsOf: url))
            try routine.validate()
        } catch {
            let alert = NSAlert(); alert.messageText = "希久的作息表暂时打不开"; alert.informativeText = "请重新安装应用。"; alert.runModal(); NSApp.terminate(nil); return
        }
        delivered = Set(defaults.stringArray(forKey: "delivered") ?? [])
        completed = Set(defaults.stringArray(forKey: "completed") ?? [])
        if let data = defaults.data(forKey: "snoozed") { snoozed = (try? JSONDecoder().decode([ScheduledReminder].self, from: data)) ?? [] }
        pet = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 190, height: 224), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        configure(pet)
        pet.title = "希久桌宠"
        petView = PetView(frame: NSRect(x: 0, y: 0, width: 190, height: 224))
        petView.owner = self
        pet.contentView = petView
        guard !petView.frames.isEmpty else {
            let alert = NSAlert(); alert.messageText = "希久的动画暂时打不开"; alert.informativeText = "请重新安装应用。"; alert.runModal(); NSApp.terminate(nil); return
        }
        resetPosition(useSaved: true)
        bubble = BubblePanel(contentRect: NSRect(x: 0, y: 0, width: 312, height: 205), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        configure(bubble)
        bubble.appearance = NSAppearance(named: .aqua)
        bubble.hasShadow = true
        bubble.title = "希久提醒"
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "希久桌宠")
        statusItem.button?.toolTip = "希久 · 生活规律提醒"
        rebuildMenu()
        if previewMode {
            exportPreview()
            NSApp.terminate(nil)
            return
        }
        pet.orderFrontRegardless()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.petView.tick() }
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.checkReminders() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        petView.animate("waving")
        showWelcome()
        checkReminders()
    }

    func configure(_ panel: NSPanel) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
    }

    func savePosition() {
        constrainToScreen()
        defaults.set(pet.frame.origin.x, forKey: "petX")
        defaults.set(pet.frame.origin.y, forKey: "petY")
        positionBubble()
    }

    func constrainToScreen() {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(pet.frame) } ?? NSScreen.main!
        let area = screen.visibleFrame
        pet.setFrameOrigin(NSPoint(x: min(max(pet.frame.minX, area.minX), area.maxX-pet.frame.width), y: min(max(pet.frame.minY, area.minY), area.maxY-pet.frame.height)))
    }

    func resetPosition(useSaved: Bool) {
        let area = NSScreen.main!.visibleFrame
        let x = useSaved && defaults.object(forKey: "petX") != nil ? defaults.double(forKey: "petX") : area.maxX-220
        let y = useSaved && defaults.object(forKey: "petY") != nil ? defaults.double(forKey: "petY") : area.minY+35
        pet.setFrameOrigin(NSPoint(x:x,y:y))
        constrainToScreen()
    }

    func positionBubble() {
        guard let bubble, let pet else { return }
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(NSPoint(x: pet.frame.midX,y:pet.frame.midY)) } ?? NSScreen.main!
        let area = screen.visibleFrame
        let x = min(max(pet.frame.midX-bubble.frame.width/2, area.minX+8), area.maxX-bubble.frame.width-8)
        var y = pet.frame.maxY-8
        if y+bubble.frame.height > area.maxY-8 { y = max(area.minY+8, pet.frame.minY-bubble.frame.height+8) }
        bubble.setFrameOrigin(NSPoint(x:x,y:y))
    }

    func showBubble(eyebrow: String, title: String, message: String, actions: [(String, Selector)], autoHide: Bool = false) {
        let view = NSView(frame: NSRect(x:0,y:0,width:312,height:205))
        view.wantsLayer = true
        view.layer?.backgroundColor = warm.cgColor
        view.layer?.cornerRadius = 20
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor(calibratedWhite: 0.5, alpha: 0.13).cgColor
        let eyebrowLabel = label(eyebrow, size: 10, weight: .semibold, color: accent)
        eyebrowLabel.frame = NSRect(x:20,y:173,width:245,height:16)
        view.addSubview(eyebrowLabel)
        let titleLabel = label(title,size:19,weight:.semibold)
        titleLabel.frame = NSRect(x:20,y:128,width:272,height:39)
        view.addSubview(titleLabel)
        let messageLabel = label(message,size:12,color:ink.withAlphaComponent(0.75))
        messageLabel.frame = NSRect(x:20,y:65,width:272,height:59)
        view.addSubview(messageLabel)
        for (i, action) in actions.enumerated() {
            let button = NSButton(title: action.0, target: self, action: action.1)
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize:12,weight: i == 0 ? .semibold : .regular)
            button.frame = NSRect(x:18+CGFloat(i)*137,y:20,width:132,height:30)
            if i == 0 { button.contentTintColor = accent }
            view.addSubview(button)
        }
        let close = NSButton(image: NSImage(systemSymbolName:"xmark",accessibilityDescription:"收起提醒")!,target:self,action:#selector(hideBubble))
        close.isBordered = false
        close.frame = NSRect(x:278,y:170,width:18,height:18)
        close.contentTintColor = ink.withAlphaComponent(0.45)
        view.addSubview(close)
        bubble.contentView = view
        positionBubble()
        if !previewMode { bubble.orderFrontRegardless() }
        automaticallyHiddenBubbleAt = autoHide ? Date().addingTimeInterval(15) : nil
    }

    func showWelcome() {
        showBubble(eyebrow:"希久 · 你的生活小伙伴",title:"我来陪你规律生活啦",message:"拖动我放到喜欢的位置，点击我查看下一项。到点我会轻轻提醒你。",actions:[("看看今天",#selector(showSchedule)),("试试提醒",#selector(testReminder))],autoHide:true)
    }

    @objc func showNext() {
        if current != nil { presentCurrent(); return }
        if paused {
            showBubble(eyebrow:"希久正在休息",title:"提醒已暂停",message:"我还会陪在这里。准备好时，可以继续提醒。",actions:[("继续提醒",#selector(togglePause)),("查看作息",#selector(showSchedule))])
        } else if let next = routine.next(after: Date()) {
            let today = routine.calendar.isDate(next.date,inSameDayAs:Date())
            showBubble(eyebrow:"北京时间 · 下一项",title:"\(today ? "" : "明天 ")\(next.reminder.time)  \(next.reminder.title)",message:next.reminder.message,actions:[("查看作息",#selector(showSchedule)),("知道啦",#selector(hideBubble))],autoHide:true)
        }
        petView.animate("waving",for:2)
    }

    func presentCurrent() {
        guard let event = current else { return }
        showBubble(eyebrow:demo ? "希久 · 提醒体验" : "希久提醒你 · 北京时间 \(event.reminder.time)",title:event.reminder.title,message:event.reminder.message,actions:[("完成啦",#selector(finishCurrent)),("10 分钟后",#selector(snoozeCurrent))])
        petView.animate(event.reminder.state,for:4)
    }

    func persist() {
        defaults.set(Array(delivered),forKey:"delivered")
        defaults.set(Array(completed),forKey:"completed")
        defaults.set(try? JSONEncoder().encode(snoozed),forKey:"snoozed")
    }

    func checkReminders() {
        let now = Date()
        if let until = automaticallyHiddenBubbleAt, now > until { hideBubble() }
        guard !paused else { return }
        let dayComponents = routine.calendar.dateComponents([.year,.month,.day],from:now)
        let dayKey = "\(dayComponents.year!)-\(dayComponents.month!)-\(dayComponents.day!)"
        if dayKey != lastDay {
            // Keep only the last eight days of keys so state stays bounded.
            let prefixSet = Set((0...7).map { offset -> String in
                let date = routine.calendar.date(byAdding:.day,value:-offset,to:now)!
                let d = routine.calendar.dateComponents([.year,.month,.day],from:date)
                return "\(d.year!)-\(d.month!)-\(d.day!):"
            })
            delivered = Set(delivered.filter { key in prefixSet.contains { key.hasPrefix($0) } })
            completed = Set(completed.filter { key in prefixSet.contains { key.hasPrefix($0) } })
            lastDay = dayKey
            persist()
        }
        // Expired reminders are never replayed after sleep or a long absence.
        if !demo, let event = current, now.timeIntervalSince(event.date) >= 1800 {
            current = nil; bubble.orderOut(nil)
        }
        queue.removeAll { now.timeIntervalSince($0.date) >= 1800 }
        let newlyDue = routine.due(at:now,delivered:delivered)
        for event in newlyDue {
            delivered.insert(event.key)
            queue.append(event)
        }
        let previousSnoozeCount = snoozed.count
        let ready = snoozed.filter { $0.date <= now && now.timeIntervalSince($0.date) < 90 }
        snoozed.removeAll { $0.date <= now }
        queue.append(contentsOf:ready)
        if !newlyDue.isEmpty || snoozed.count != previousSnoozeCount { persist() }
        if current == nil, !queue.isEmpty {
            current = queue.removeFirst()
            demo = false
            presentCurrent()
            if sound { NSSound(named:"Pop")?.play() }
        }
        rebuildMenu()
    }

    @objc func finishCurrent() {
        guard let event = current else { hideBubble(); return }
        if !demo { completed.insert(event.key); persist() }
        current = nil; demo = false
        petView.animate("jumping",for:2)
        showBubble(eyebrow:"希久 · 陪你一点点坚持",title:"好啦，又完成一件",message:"按自己的节奏来。下一件到点，我再提醒你。",actions:[("下一项",#selector(showNext)),("收起",#selector(hideBubble))],autoHide:true)
        checkReminders()
    }

    @objc func snoozeCurrent() {
        guard let event = current else { return }
        if demo {
            current = nil; demo = false
            showBubble(eyebrow:"希久 · 提醒体验",title:"正式提醒可以延后",message:"正式提醒点击这个按钮后，会在 10 分钟后再出现。本次体验不添加提醒。",actions:[("知道啦",#selector(hideBubble))],autoHide:true)
            return
        }
        if !demo {
            let nextDate = Date().addingTimeInterval(600)
            let formatter = DateFormatter(); formatter.timeZone = routine.calendar.timeZone; formatter.dateFormat = "HH:mm"
            let reminder = Reminder(id:event.reminder.id,time:formatter.string(from:nextDate),title:event.reminder.title,message:event.reminder.message,state:event.reminder.state)
            snoozed.removeAll { $0.key == event.key }
            snoozed.append(ScheduledReminder(reminder:reminder,date:nextDate,key:event.key))
            persist()
        }
        current = nil; demo = false
        showBubble(eyebrow:"希久记住啦",title:"10 分钟后再提醒",message:"先忙手头的事，我稍后再来。",actions:[("知道啦",#selector(hideBubble))],autoHide:true)
    }

    @objc func hideBubble() { bubble.orderOut(nil); automaticallyHiddenBubbleAt = nil }
    @objc func testReminder() {
        if current != nil { presentCurrent(); return }
        let r = Reminder(id:"demo",time:"现在",title:"带希久出去走走吧",message:"这是一次提醒体验。正式提醒会按你的作息表准时出现。",state:"jumping")
        current = ScheduledReminder(reminder:r,date:Date(),key:"demo")
        demo = true; presentCurrent()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        let heading = NSMenuItem(title: paused ? "希久 · 提醒已暂停" : "希久 · 北京时间",action:nil,keyEquivalent:"")
        menu.addItem(heading)
        if let next = routine.next(after:Date()) {
            let day = routine.calendar.isDate(next.date,inSameDayAs:Date()) ? "" : "明天 "
            menu.addItem(NSMenuItem(title:"下一项：\(day)\(next.reminder.time) \(next.reminder.title)",action:nil,keyEquivalent:""))
        }
        menu.addItem(.separator())
        for (title,selector) in [("查看下一项",#selector(showNext)),("查看作息表",#selector(showSchedule)),("试试提醒",#selector(testReminder)),("把希久叫回来",#selector(reposition))] {
            let item = NSMenuItem(title:title,action:selector,keyEquivalent:""); item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator())
        let pauseItem = NSMenuItem(title:paused ? "继续提醒" : "暂停提醒",action:#selector(togglePause),keyEquivalent:""); pauseItem.target=self; menu.addItem(pauseItem)
        let soundItem = NSMenuItem(title:"轻声提示",action:#selector(toggleSound),keyEquivalent:""); soundItem.target=self; soundItem.state = sound ? .on : .off; menu.addItem(soundItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title:"退出希久",action:#selector(quitApp),keyEquivalent:"q"); quit.target=self; menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc func togglePause() {
        paused.toggle(); defaults.set(paused,forKey:"paused")
        if paused { current=nil; queue=[]; demo=false; hideBubble() }
        rebuildMenu(); petView.needsDisplay=true; showNext()
    }
    @objc func toggleSound() { sound.toggle(); defaults.set(sound,forKey:"sound"); rebuildMenu() }
    @objc func reposition() { resetPosition(useSaved:false); savePosition(); pet.orderFrontRegardless(); petView.animate("waving"); showNext() }
    @objc func woke() { checkReminders() }
    @objc func screensChanged() { constrainToScreen(); positionBubble() }
    @objc func quitApp() { NSApp.terminate(nil) }

    func exportPreview() {
        guard let argumentIndex = CommandLine.arguments.firstIndex(of: "--export-preview"), CommandLine.arguments.count > argumentIndex + 1 else { return }
        let output = URL(fileURLWithPath:CommandLine.arguments[argumentIndex+1])
        testReminder()
        petView.row = 0; petView.index = 0
        func snapshot(_ view: NSView) -> NSBitmapImageRep? {
            view.layoutSubtreeIfNeeded()
            guard let rep = view.bitmapImageRepForCachingDisplay(in:view.bounds) else { return nil }
            view.cacheDisplay(in:view.bounds,to:rep)
            return rep
        }
        guard let bubbleView = bubble.contentView, let bubbleImage = snapshot(bubbleView) else { return }
        let canvas = NSImage(size:NSSize(width:352,height:449))
        canvas.lockFocus()
        NSColor(calibratedRed:0.94,green:0.925,blue:0.90,alpha:1).setFill()
        NSRect(x:0,y:0,width:352,height:449).fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect:NSRect(x:20,y:224,width:312,height:205),xRadius:20,yRadius:20).addClip()
        bubbleImage.draw(in:NSRect(x:20,y:224,width:312,height:205))
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        let translation = NSAffineTransform(); translation.translateX(by:81,yBy:0); translation.concat()
        petView.draw(petView.bounds)
        NSGraphicsContext.restoreGraphicsState()
        canvas.unlockFocus()
        if let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data:tiff), let png = rep.representation(using:.png,properties:[:]) { try? png.write(to:output) }
        let before = current?.key == "demo"
        snoozeCurrent()
        let afterSnooze = current == nil && !demo
        testReminder(); finishCurrent()
        let afterFinish = current == nil && !demo
        showSchedule()
        if let content = summaryWindow?.contentView, let rep = snapshot(content), let png = rep.representation(using:.png,properties:[:]) {
            try? png.write(to:output.deletingLastPathComponent().appendingPathComponent("作息表预览.png"))
        }
        let results: [String:Any] = ["previewWritten":FileManager.default.fileExists(atPath:output.path),"demoPresented":before,"demoSnoozeClears":afterSnooze,"demoCompleteClears":afterFinish,"atlasRows":petView.frames.count,"frameCounts":petView.frames.map(\.count)]
        if let data = try? JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]) { try? data.write(to:output.deletingPathExtension().appendingPathExtension("json")) }
    }

    @objc func showSchedule() {
        if summaryWindow == nil {
            summaryWindow = NSWindow(contentRect:NSRect(x:0,y:0,width:740,height:650),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            summaryWindow?.title = "希久 · 我的规律生活"
            summaryWindow?.isReleasedWhenClosed = false
            summaryWindow?.backgroundColor = warm
            summaryWindow?.appearance = NSAppearance(named: .aqua)
            summaryWindow?.center()
        }
        let content = NSView(frame:NSRect(x:0,y:0,width:740,height:650))
        content.wantsLayer = true
        content.layer?.backgroundColor = warm.cgColor
        let title = label("有希久陪着，慢慢养成好习惯。",size:25,weight:.semibold)
        title.frame = NSRect(x:30,y:586,width:680,height:36); content.addSubview(title)
        let subtitle = label("北京时间  ·  周末不安排工作  ·  到点提醒，完成就打个勾",size:12,color:ink.withAlphaComponent(0.6))
        subtitle.frame = NSRect(x:30,y:556,width:680,height:20); content.addSubview(subtitle)
        let todayEvents = routine.events(on:Date())
        let done = todayEvents.filter { completed.contains($0.key) }.count
        let progress = label("今天已完成 \(done) / \(todayEvents.count)",size:12,weight:.semibold,color:accent)
        progress.frame = NSRect(x:30,y:526,width:650,height:22); content.addSubview(progress)
        for (column, items) in [routine.weekdays,routine.weekends].enumerated() {
            let x = 30 + CGFloat(column)*355
            let heading = label(column == 0 ? "工作日" : "周末",size:17,weight:.semibold)
            heading.frame = NSRect(x:x,y:483,width:315,height:28); content.addSubview(heading)
            for (i,item) in items.enumerated() {
                let y = 450-CGFloat(i)*30
                let time = label(item.time,size:12,weight:.medium,color:accent)
                time.frame = NSRect(x:x,y:y,width:48,height:22); content.addSubview(time)
                let displayNames = ["wake":"起床 · 喝水 · 整理","breakfast":"早餐 · 今天的 3 件事","walk-am":"早餐后遛狗","focus-am":"专注工作 / 学习","lunch":"午饭 · 离开电脑休息","nap":"午休 20–30 分钟","focus-pm":"下午工作 / 学习","dinner":"晚饭","walk-pm":"晚饭后遛狗","exercise":"运动 / 散步 30–60 分钟","review":"回顾今天 · 安排明天","wind-down":column == 0 ? "洗漱 · 睡前放松" : "回顾 · 安排明天 · 洗漱","sleep":"睡觉"]
                let text = label(displayNames[item.id] ?? item.title,size:12)
                text.frame = NSRect(x:x+60,y:y,width:260,height:22); content.addSubview(text)
            }
        }
        let footer = label("点击桌面上的希久查看下一项；右键或菜单栏爪印可暂停、试播和退出。\n电脑开机且希久运行时提醒；休眠期间不提醒，唤醒后不会补发过期提醒。",size:11,color:ink.withAlphaComponent(0.6))
        footer.frame = NSRect(x:30,y:16,width:680,height:45); content.addSubview(footer)
        summaryWindow?.contentView = content
        if !previewMode {
            NSApp.activate(ignoringOtherApps:true)
            summaryWindow?.makeKeyAndOrderFront(nil)
        }
    }
}

let app = NSApplication.shared
let companion = Companion()
app.delegate = companion
app.run()
