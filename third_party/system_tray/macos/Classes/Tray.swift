import FlutterMacOS

let kInitSystemTray = "InitSystemTray"
let kSetSystemTrayInfo = "SetSystemTrayInfo"
let kSetContextMenu = "SetContextMenu"
let kPopupContextMenu = "PopupContextMenu"
let kSetPressedImage = "SetPressedImage"
let kGetTitle = "GetTitle"
let kDestroySystemTray = "DestroySystemTray"

private let kDefaultSizeWidth = 18
private let kDefaultSizeHeight = 18

private let kTitleKey = "title"
private let kIconPathKey = "iconpath"
private let kToolTipKey = "tooltip"
private let kIsTemplateKey = "is_template"

private let kSystemTrayEventClick = "click"
private let kSystemTrayEventRightClick = "right-click"
private let kSystemTrayEventDoubleClick = "double-click"

private let kSystemTrayEventCallbackMethod = "SystemTrayEventCallback"

class Tray: NSObject, NSMenuDelegate {
  var registrar: FlutterPluginRegistrar
  var channel: FlutterMethodChannel

  weak var menuManager: MenuManager?

  private var speedLabels: [NSTextField] = []
  private var speedIcon: NSImageView?
  var statusItem: NSStatusItem?

  var contextMenuId: Int?

  init(
    _ registrar: FlutterPluginRegistrar, _ channel: FlutterMethodChannel,
    _ menuManager: MenuManager?
  ) {
    self.registrar = registrar
    self.channel = channel
    self.menuManager = menuManager
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case kInitSystemTray:
      initSystemTray(call, result)
    case kSetSystemTrayInfo:
      setTrayInfo(call, result)
    case kSetContextMenu:
      setContextMenu(call, result)
    case kPopupContextMenu:
      popUpContextMenu(call, result)
    case kSetPressedImage:
      setPressedImage(call, result)
    case kGetTitle:
      getTitle(call, result)
    case kDestroySystemTray:
      destroySystemTray(call, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func menuDidClose(_ menu: NSMenu) {
    statusItem?.menu = nil
  }

  @objc func onSystemTrayEventCallback(sender: NSStatusBarButton) {
    if let event = NSApp.currentEvent {
      switch event.type {
      case .leftMouseUp:
        channel.invokeMethod(kSystemTrayEventCallbackMethod, arguments: kSystemTrayEventClick)
      case .rightMouseUp:
        channel.invokeMethod(kSystemTrayEventCallbackMethod, arguments: kSystemTrayEventRightClick)
      default:
        break
      }
    }
  }

  func initSystemTray(_ call: FlutterMethodCall, _ result: FlutterResult) {
    let arguments = call.arguments as! [String: Any]
    let title = arguments[kTitleKey] as? String
    let base64Icon = arguments[kIconPathKey] as? String
    let toolTip = arguments[kToolTipKey] as? String
    let isTemplate = arguments[kIsTemplateKey] as? Bool

    if statusItem != nil {
      result(false)
      return
    }

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    statusItem?.button?.action = #selector(onSystemTrayEventCallback(sender:))
    statusItem?.button?.target = self
    statusItem?.button?.sendAction(on: [
      .leftMouseUp, .leftMouseDown, .rightMouseUp, .rightMouseDown,
    ])

    if let toolTip = toolTip {
      statusItem?.button?.toolTip = toolTip
    }

    if let title = title {
      setTitle(title)
    }

    if let base64Icon = base64Icon {
      if let imageData = Data(base64Encoded: base64Icon, options: .ignoreUnknownCharacters),
        let itemImage = NSImage(data: imageData)
      {
        let destSize = NSSize(width: kDefaultSizeWidth, height: kDefaultSizeHeight)
        itemImage.size = destSize
        itemImage.isTemplate = isTemplate ?? false
        setIcon(itemImage)
      }
    }

    result(true)
  }

  private func setTitle(_ title: String) {
    guard let button = statusItem?.button else { return }
    let lines = title.components(separatedBy: "\n")
    guard lines.count == 2 else {
      speedLabels.forEach { $0.removeFromSuperview() }
      speedLabels.removeAll()
      if let icon = speedIcon {
        button.image = icon.image
        icon.removeFromSuperview()
        speedIcon = nil
      }
      statusItem?.length = NSStatusItem.variableLength
      button.title = title
      return
    }
    button.title = ""
    if speedIcon == nil {
      let icon = NSImageView(frame: NSRect(x: 3, y: 3, width: 18, height: 18))
      icon.image = button.image
      button.image = nil
      button.addSubview(icon)
      speedIcon = icon
      for y in [11.0, 1.0] {
        let label = NSTextField(labelWithString: "")
        label.frame = NSRect(x: 23, y: y, width: 0, height: 12)
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        label.alignment = .right
        label.textColor = .labelColor
        label.lineBreakMode = .byClipping
        button.addSubview(label)
        speedLabels.append(label)
      }
    }
    for (label, line) in zip(speedLabels, lines) {
      label.stringValue = line.trimmingCharacters(in: .whitespaces)
    }
    // Share the wider row's measured width; don't reserve empty space for
    // maximum-length rates when both rows only display a few characters.
    // Measure the glyphs independently of the previous field frame, then
    // include the text cell's horizontal insets and fractional pixel rounding.
    let textWidth = ceil(speedLabels.map { label in
      (label.stringValue as NSString).size(withAttributes: [.font: label.font!]).width
    }.max() ?? 0) + 8
    for label in speedLabels {
      label.setFrameSize(NSSize(width: textWidth, height: 12))
    }
    statusItem?.length = 23 + textWidth + 3
  }

  private func setIcon(_ image: NSImage) {
    if let icon = speedIcon {
      icon.image = image
    } else {
      statusItem?.button?.image = image
      statusItem?.button?.imagePosition = .imageLeft
    }
  }

  func setTrayInfo(_ call: FlutterMethodCall, _ result: FlutterResult) {
    let arguments = call.arguments as! [String: Any]
    let title = arguments[kTitleKey] as? String
    let base64Icon = arguments[kIconPathKey] as? String
    let toolTip = arguments[kToolTipKey] as? String
    let isTemplate = arguments[kIsTemplateKey] as? Bool

    if let toolTip = toolTip {
      statusItem?.button?.toolTip = toolTip
    }

    if let title = title {
      setTitle(title)
    }

    if let base64Icon = base64Icon {
      if let imageData = Data(base64Encoded: base64Icon, options: .ignoreUnknownCharacters),
        let itemImage = NSImage(data: imageData)
      {
        let destSize = NSSize(width: kDefaultSizeWidth, height: kDefaultSizeHeight)
        itemImage.size = destSize
        itemImage.isTemplate = isTemplate ?? false
        setIcon(itemImage)
      } else {
        statusItem?.button?.image = nil
      }
    }

    return result(true)
  }

  func setContextMenu(_ call: FlutterMethodCall, _ result: FlutterResult) {
    if let menuId = call.arguments as? Int {
      contextMenuId = menuId
    } else {
      contextMenuId = -1
    }
    result(true)
  }

  func popUpContextMenu(_ call: FlutterMethodCall, _ result: FlutterResult) {
    if let menu = menuManager?.getMenu(menuId: contextMenuId ?? -1) {
      let nsMenu = menu.getNSMenu()
      nsMenu?.delegate = self

      statusItem?.menu = nsMenu
      statusItem?.button?.performClick(nil)
      result(true)
      return
    }
    result(false)
  }

  func setPressedImage(_ call: FlutterMethodCall, _ result: FlutterResult) {
    let base64Icon = call.arguments as? String

    if let base64Icon = base64Icon {
      if let imageData = Data(base64Encoded: base64Icon, options: .ignoreUnknownCharacters),
        let itemImage = NSImage(data: imageData)
      {
        let destSize = NSSize(width: kDefaultSizeWidth, height: kDefaultSizeHeight)
        itemImage.size = destSize
        statusItem?.button?.alternateImage = itemImage
        statusItem?.button?.setButtonType(.toggle)
      } else {
        statusItem?.button?.alternateImage = nil
      }
    } else {
      statusItem?.button?.alternateImage = nil
    }

    result(nil)
  }

  func getTitle(_ call: FlutterMethodCall, _ result: FlutterResult) {
    result(statusItem?.button?.title ?? "")
  }

  func destroySystemTray(_ call: FlutterMethodCall, _ result: FlutterResult) {
    contextMenuId = -1

    if statusItem != nil {
      NSStatusBar.system.removeStatusItem(statusItem!)

      statusItem?.button?.image = nil
      statusItem?.button?.alternateImage = nil
      statusItem = nil
      speedLabels.removeAll()
      speedIcon = nil
    }
    result(true)
  }
}
