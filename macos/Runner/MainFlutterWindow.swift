import Cocoa
import FlutterMacOS
import ServiceManagement
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    AppDelegate.coreLifecycleChannel = FlutterMethodChannel(
      name: "io.qzz.wenyun/core-lifecycle",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let dialogs = FlutterMethodChannel(
      name: "io.qzz.wenyun/desktop-dialogs",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    dialogs.setMethodCallHandler { call, result in
      // Let status-menu tracking finish before presenting an app-modal panel.
      DispatchQueue.main.async {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "loginStatus":
          if #available(macOS 13.0, *) {
            result(SMAppService.mainApp.status == .enabled)
          } else {
            result(nil)
          }
        case "setLoginEnabled":
          if #available(macOS 13.0, *) {
            do {
              if arguments["enabled"] as? Bool == true {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                  SMAppService.openSystemSettingsLoginItems()
                }
              } else {
                try SMAppService.mainApp.unregister()
              }
              result(SMAppService.mainApp.status == .enabled)
            } catch {
              result(FlutterError(code: "LOGIN_ITEM", message: error.localizedDescription, details: nil))
            }
          } else {
            result(FlutterError(code: "UNSUPPORTED", message: "需要 macOS 13 或更新版本", details: nil))
          }
        case "pickProfileFile":
          NSApp.activate(ignoringOtherApps: true)
          let panel = NSOpenPanel()
          panel.title = "导入 YAML 配置文件"
          panel.prompt = "导入"
          panel.canChooseFiles = true
          panel.canChooseDirectories = false
          panel.allowsMultipleSelection = false
          panel.allowedFileTypes = ["yaml", "yml"]
          panel.begin { response in
            result(response == .OK ? panel.url?.path : nil)
          }
        case "prompt", "confirm", "message":
          NSApp.activate(ignoringOtherApps: true)
          let alert = NSAlert()
          alert.messageText = arguments["title"] as? String ?? "ClashWave"
          alert.informativeText = arguments["message"] as? String ?? ""
          alert.addButton(withTitle: call.method == "message" ? "好" : "确认")
          if call.method != "message" { alert.addButton(withTitle: "取消") }
          var input: NSTextField?
          if call.method == "prompt" {
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
            field.stringValue = arguments["value"] as? String ?? ""
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            input = field
          }
          let accepted = alert.runModal() == .alertFirstButtonReturn
          if call.method == "prompt" {
            result(accepted ? input?.stringValue : nil)
          } else if call.method == "confirm" {
            result(accepted)
          } else {
            result(nil)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
