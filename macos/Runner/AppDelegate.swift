import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  static var coreLifecycleChannel: FlutterMethodChannel?
  private var waitingForCoreShutdown = false

  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let channel = Self.coreLifecycleChannel else { return .terminateNow }
    if waitingForCoreShutdown { return .terminateLater }
    waitingForCoreShutdown = true
    let finish = { [weak self] in
      guard let self = self, self.waitingForCoreShutdown else { return }
      self.waitingForCoreShutdown = false
      sender.reply(toApplicationShouldTerminate: true)
    }
    channel.invokeMethod("shutdown", arguments: nil) { _ in finish() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: finish)
    return .terminateLater
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    //TODO: 关闭时退出
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in NSApp.windows {
        if !window.isVisible {
          window.setIsVisible(true)
        }
        window.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    return true
  }
}
