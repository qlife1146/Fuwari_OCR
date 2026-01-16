//
//  MenuManager.swift
//  Fuwari
//
//  Created by Kengo Yokoyama on 2016/12/25.
//  Copyright © 2016年 AppKnop. All rights reserved.
//

import Carbon
import Cocoa
import Magnet
import Sauce

class MenuManager: NSObject {

  static let shared = MenuManager()
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

  private var captureItem = NSMenuItem()
  private var ocrItem = NSMenuItem()
  private var resetItem = NSMenuItem()

  private func menuModifierFlags(for keyCombo: KeyCombo) -> NSEvent.ModifierFlags {
    var flags: NSEvent.ModifierFlags = []
    let mods = keyCombo.modifiers
    if (mods & Int(cmdKey)) != 0 { flags.insert(.command) }
    if (mods & Int(shiftKey)) != 0 { flags.insert(.shift) }
    if (mods & Int(optionKey)) != 0 { flags.insert(.option) }
    if (mods & Int(controlKey)) != 0 { flags.insert(.control) }
    return flags
  }

  private func baseKeyEquivalent(for keyCombo: KeyCombo) -> String {
    // Prefer using Magnet's Key to avoid layout-dependent symbols
    switch keyCombo.key {
    case .zero: return "0"
    case .one: return "1"
    case .two: return "2"
    case .three: return "3"
    case .four: return "4"
    case .five: return "5"
    case .six: return "6"
    case .seven: return "7"
    case .eight: return "8"
    case .nine: return "9"
    default:
      break
    }
    // Fallback: use characters and map common shifted symbols back to digits
    let ch = keyCombo.characters.lowercased()
    switch ch {
    case "@": return "2"
    case "#": return "3"
    case "$": return "4"
    case "%": return "5"
    case "^": return "6"
    case "&": return "7"
    case "*": return "8"
    case "(": return "9"
    case ")": return "0"
    default: return ch
    }
  }

  func configure() {
    if let button = statusItem.button {
      button.image = NSImage(named: "MenuIcon")
    }

    captureItem = NSMenuItem(
      title: LocalizedString.FloatingCapture.value,
      action: #selector(AppDelegate.capture),
      keyEquivalent: baseKeyEquivalent(for: HotKeyManager.shared.captureKeyCombo)
    )
    captureItem.keyEquivalentModifierMask = menuModifierFlags(
      for: HotKeyManager.shared.captureKeyCombo)

    ocrItem = NSMenuItem(
      title: LocalizedString.OcrCapture.value,
      action: #selector(AppDelegate.ocr),
      keyEquivalent: baseKeyEquivalent(for: HotKeyManager.shared.ocrKeyCombo)
    )
    ocrItem.keyEquivalentModifierMask = menuModifierFlags(for: HotKeyManager.shared.ocrKeyCombo)

    let menu = NSMenu()
    menu.addItem(
      NSMenuItem(
        title: LocalizedString.About.value, action: #selector(AppDelegate.openAbout),
        keyEquivalent: "")
    )
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      NSMenuItem(
        title: LocalizedString.Preference.value,
        action: #selector(AppDelegate.openPreferences),
        keyEquivalent: ","
      )
    )
    menu.addItem(NSMenuItem.separator())
    menu.addItem(captureItem)
    menu.addItem(ocrItem)
    menu.addItem(resetItem)
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      NSMenuItem(
        title: LocalizedString.QuitFuwari.value, action: #selector(AppDelegate.quit),
        keyEquivalent: "q")
    )

    statusItem.menu = menu
  }

  func updateCaptureMenuItem() {
    captureItem.keyEquivalent = baseKeyEquivalent(for: HotKeyManager.shared.captureKeyCombo)
    captureItem.keyEquivalentModifierMask = menuModifierFlags(
      for: HotKeyManager.shared.captureKeyCombo)

    ocrItem.keyEquivalent = baseKeyEquivalent(for: HotKeyManager.shared.ocrKeyCombo)
    ocrItem.keyEquivalentModifierMask = menuModifierFlags(for: HotKeyManager.shared.ocrKeyCombo)
  }
}
