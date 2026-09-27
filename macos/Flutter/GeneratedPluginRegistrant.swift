//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import desktop_lifecycle
import file_picker_darwin
import local_notifier
import package_info_plus
import proxy_manager
import screen_retriever_macos
import system_tray
import url_launcher_macos
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  DesktopLifecyclePlugin.register(with: registry.registrar(forPlugin: "DesktopLifecyclePlugin"))
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  LocalNotifierPlugin.register(with: registry.registrar(forPlugin: "LocalNotifierPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  ProxyManagerPlugin.register(with: registry.registrar(forPlugin: "ProxyManagerPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  SystemTrayPlugin.register(with: registry.registrar(forPlugin: "SystemTrayPlugin"))
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
