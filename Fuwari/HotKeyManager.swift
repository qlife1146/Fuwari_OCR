//
//  HotKeyManager.swift
//  Fuwari
//
//  Created by Kengo Yokoyama on 2016/12/18.
//  Copyright © 2016年 AppKnop. All rights reserved.
//

import Carbon
import Foundation
import Magnet

final class HotKeyManager: NSObject {

  static let shared = HotKeyManager()
  private let defaults = UserDefaults.standard

  private(set) lazy var captureKeyCombo: KeyCombo = {
    if let keyCombo = self.defaults.archiveDataForKey(KeyCombo.self, key: Constants.UserDefaults.captureKeyCombo) {
      return keyCombo
    } else {
      let defaultKeyCombo = KeyCombo(key: .seven, cocoaModifiers: [.command, .shift])!
      self.defaults.setArchiveData(defaultKeyCombo, forKey: Constants.UserDefaults.captureKeyCombo)
      return defaultKeyCombo
    }
  }()

  private(set) lazy var ocrKeyCombo: KeyCombo = {
    if let keyCombo = self.defaults.archiveDataForKey(KeyCombo.self, key: Constants.UserDefaults.ocrKeyCombo) {
      return keyCombo
    } else {
      let defaultKeyCombo = KeyCombo(key: .eight, cocoaModifiers: [.command, .shift])!
      self.defaults.setArchiveData(defaultKeyCombo, forKey: Constants.UserDefaults.ocrKeyCombo)
      return defaultKeyCombo
    }
  }()

  let captureResetKeyCombo = KeyCombo(key: .zero, cocoaModifiers: [.command, .shift])!

  private(set) var captureHotKey: HotKey?
  private(set) var ocrHotKey: HotKey?
  private(set) var captureResetHotKey: HotKey?

  func configure() {
    registerCaptureHotKey(keyCombo: captureKeyCombo)
    registerOcrHotKey(keyCombo: ocrKeyCombo)
    registerCaptureResetHotKey()
  }
}

extension HotKeyManager {
  func registerCaptureHotKey(keyCombo: KeyCombo?) {
    saveCaptureKeyCombo(keyCombo: keyCombo)

    HotKeyCenter.shared.unregisterHotKey(with: Constants.HotKey.capture)
    guard let keyCombo = keyCombo else { return }
    captureKeyCombo = keyCombo

    let hotKey = HotKey(
      identifier: Constants.HotKey.capture,
      keyCombo: keyCombo,
      target: AppDelegate(),
      action: #selector(AppDelegate.capture)
    )
    hotKey.register()
    captureHotKey = hotKey

    MenuManager.shared.updateCaptureMenuItem()
  }

  func registerOcrHotKey(keyCombo: KeyCombo?) {
    saveOcrKeyCombo(keyCombo: keyCombo)

    HotKeyCenter.shared.unregisterHotKey(with: Constants.HotKey.ocr)
    guard let keyCombo = keyCombo else { return }
    ocrKeyCombo = keyCombo

    let hotKey = HotKey(
      identifier: Constants.HotKey.ocr,
      keyCombo: keyCombo,
      target: AppDelegate(),
      action: #selector(AppDelegate.ocr)
    )
    hotKey.register()
    ocrHotKey = hotKey

    MenuManager.shared.updateCaptureMenuItem()
  }

  func registerCaptureResetHotKey() {
    HotKeyCenter.shared.unregisterHotKey(with: Constants.HotKey.captureReset)
    let hotKey = HotKey(
      identifier: Constants.HotKey.captureReset,
      keyCombo: captureResetKeyCombo,
      target: AppDelegate(),
      action: #selector(AppDelegate.captureReset)
    )
    hotKey.register()
    captureResetHotKey = hotKey

    MenuManager.shared.updateCaptureMenuItem()
  }

  private func saveCaptureKeyCombo(keyCombo: KeyCombo?) {
    if let keyCombo = keyCombo {
      defaults.setArchiveData(keyCombo, forKey: Constants.UserDefaults.captureKeyCombo)
    } else {
      defaults.removeObject(forKey: Constants.UserDefaults.captureKeyCombo)
    }
  }

  private func saveOcrKeyCombo(keyCombo: KeyCombo?) {
    if let keyCombo = keyCombo {
      defaults.setArchiveData(keyCombo, forKey: Constants.UserDefaults.ocrKeyCombo)
    } else {
      defaults.removeObject(forKey: Constants.UserDefaults.ocrKeyCombo)
    }
  }

}
