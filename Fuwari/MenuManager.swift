//
//  MenuManager.swift
//  Fuwari
//
//  Created by Kengo Yokoyama on 2016/12/25.
//  Copyright © 2016年 AppKnop. All rights reserved.
//

import Cocoa
import Magnet
import Sauce

class MenuManager: NSObject {

  static let shared = MenuManager()
  let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

  private var captureItem = NSMenuItem()
  private var ocrItem = NSMenuItem()

  func configure() {
    if let button = statusItem.button {
      button.image = NSImage(named: "MenuIcon")
    }

    captureItem = NSMenuItem(
      title: LocalizedString.FloatingCapture.value,
      action: #selector(AppDelegate.capture),
      keyEquivalent: HotKeyManager.shared.captureKeyCombo.characters.lowercased()
    )
    captureItem.keyEquivalentModifierMask = NSEvent.ModifierFlags()

    ocrItem = NSMenuItem(
      title: LocalizedString.OcrCapture.value,
      action: #selector(
        AppDelegate.ocr
      ),
      keyEquivalent: HotKeyManager.shared.ocrKeyCombo.characters.lowercased()
    )
    ocrItem.keyEquivalentModifierMask = NSEvent.ModifierFlags()

    let menu = NSMenu()
    menu.addItem(
      NSMenuItem(title: LocalizedString.About.value, action: #selector(AppDelegate.openAbout), keyEquivalent: "")
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
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      NSMenuItem(title: LocalizedString.QuitFuwari.value, action: #selector(AppDelegate.quit), keyEquivalent: "q")
    )

    statusItem.menu = menu
  }

  func updateCaptureMenuItem() {
    captureItem.keyEquivalent = HotKeyManager.shared.captureKeyCombo.characters.lowercased()
    captureItem.keyEquivalentModifierMask = NSEvent.ModifierFlags()
  }
}
