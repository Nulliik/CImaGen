//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import desktop_drop
import screen_retriever
import shared_preferences_foundation
import sqflite
import system_theme
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  DesktopDropPlugin.register(with: registry.registrar(forPlugin: "DesktopDropPlugin"))
  ScreenRetrieverPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
  SystemThemePlugin.register(with: registry.registrar(forPlugin: "SystemThemePlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
