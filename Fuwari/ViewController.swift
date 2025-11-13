  //
  //  ViewController.swift
  //  Fuwari
  //
  //  Created by Kengo Yokoyama on 2016/11/29.
  //  Copyright © 2016年 AppKnop. All rights reserved.
  //

import Cocoa
import Quartz
import Vision
import VisionKit

class ViewController: NSViewController, NSWindowDelegate {

  private var windowControllers = [FloatWindow]()
  private var isCancelled = false
  private var oldApp: NSRunningApplication?

  override func viewDidLoad() {
    super.viewDidLoad()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(startCapture),
      name: Notification.Name(rawValue: Constants.Notification.capture),
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(startOcrCapture),
      name: Notification.Name(rawValue: Constants.Notification.ocr),
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(NSWindowDelegate.windowDidResize(_:)),
      name: NSWindow.didResizeNotification,
      object: nil
    )

    oldApp = NSWorkspace.shared.frontmostApplication
    oldApp?.activate(options: .activateIgnoringOtherApps)

    setDefaultScreenshotHandler()
  }

  private func setDefaultScreenshotHandler() {
    ScreenshotManager.shared.eventHandler { imageUrl, rectMaybeConst, spaceMode in
      let mainScreen = NSScreen.screens.first
      let currentScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
      guard let currentScaleFactor = currentScreen?.backingScaleFactor else { return }
      let mouseLocation = NSEvent.mouseLocation
      guard let ciImage = CIImage(contentsOf: imageUrl)?.copy() as? CIImage else { return }

      let context = CIContext(options: nil)

      guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
      var rectMaybe = rectMaybeConst
      if let height = mainScreen?.frame.size.height, let rect = rectMaybe {
        rectMaybe = NSRect(
          x: rect.minX,
          y: height - rect.maxY,
          width: rect.width,
          height: rect.height
        )
      }
      let rect =
      rectMaybe
      ?? NSRect(
        x: Int(mouseLocation.x) - cgImage.width / Int(2 * currentScaleFactor),
        y: Int(mouseLocation.y) - cgImage.height / Int(2 * currentScaleFactor),
        width: Int(CGFloat(cgImage.width) / currentScaleFactor),
        height: Int(CGFloat(cgImage.height) / currentScaleFactor)
      )
      self.createFloatWindow(rect: rect, image: cgImage, spaceMode: spaceMode)
      try? FileManager.default.removeItem(at: imageUrl)
    }
  }

  @objc private func startOcrCapture() {
    ScreenshotManager.shared.eventHandler { [weak self] imageUrl, _, _ in
      guard let self = self else { return }
      defer {
        try? FileManager.default.removeItem(at: imageUrl)
        self.setDefaultScreenshotHandler()
      }
      guard let ciImage = CIImage(contentsOf: imageUrl)?.copy() as? CIImage else { return }
      let context = CIContext(options: nil)
      guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
      self.recognizeTextAndCopy(from: cgImage)
    }
    ScreenshotManager.shared.startCapture(spaceMode: .all)
  }

  private func recognizeTextAndCopy(from image: CGImage) {
    let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])

    let probeRequest = VNRecognizeTextRequest(completionHandler: nil)
    let selectedRevision = probeRequest.revision

    func makeRequest(langs: [String]?, autoDetect: Bool) -> VNRecognizeTextRequest {
      let request = VNRecognizeTextRequest { request, error in
        if let error = error {
          NSLog("OCR error: \(error.localizedDescription)")
          return
        }
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let strings: [String] = observations.compactMap { $0.topCandidates(1).first?.string }
        let text = strings.joined(separator: "\n")
        if !text.isEmpty {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(text, forType: .string)
        }
      }
      request.revision = selectedRevision
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.minimumTextHeight = 0.02
      if #available(macOS 13.0, *) {
        request.automaticallyDetectsLanguage = autoDetect
      }
      request.recognitionLanguages = langs ?? []
      return request
    }

    do {
      let supported = try VNRecognizeTextRequest.supportedRecognitionLanguages(
        for: .accurate,
        revision: selectedRevision
      )
      NSLog("Supported OCR languages: \(supported)")
      let preferred = Locale.preferredLanguages
      let common: [String] = [
        "ko-KR", "ja-JP", "en-US",
        "zh-Hans", "zh-Hant", "fr-FR", "de-DE", "es-ES", "it-IT", "ru-RU", "pt-PT", "pt-BR",
      ]
      var merged: [String] = []
      for l in preferred + common {
        if !merged.contains(l) { merged.append(l) }
      }
      var candidates = merged.filter { supported.contains($0) }
      if candidates.count > 12 { candidates = Array(candidates.prefix(12)) }

      var attempts: [VNRecognizeTextRequest] = []
      if #available(macOS 13.0, *) {
        attempts.append(makeRequest(langs: nil, autoDetect: true))
      }
      attempts.append(makeRequest(langs: candidates, autoDetect: true))
      let jaList = ["ja-JP", "ja"].filter { supported.isEmpty || supported.contains($0) }
      if !jaList.isEmpty { attempts.append(makeRequest(langs: jaList, autoDetect: false)) }
      let koList = ["ko-KR", "ko"].filter { supported.isEmpty || supported.contains($0) }
      if !koList.isEmpty { attempts.append(makeRequest(langs: koList, autoDetect: false)) }

      for attempt in attempts {
        do {
          try requestHandler.perform([attempt])
          break
        } catch {
          NSLog("Failed to perform OCR attempt: \(error.localizedDescription)")
        }
      }

    } catch {
      if #available(macOS 13.0, *) {
        let fallbackRequest = makeRequest(langs: nil, autoDetect: true)
        do {
          try requestHandler.perform([fallbackRequest])
        } catch {
          NSLog("Failed to perform OCR fallback: \(error.localizedDescription)")
        }
      } else {
        let fallbackLangs = [
          "en-US", "ja-JP", "ja", "ko-KR", "ko",
          "zh-Hans", "zh-Hant", "fr-FR", "de-DE", "es-ES", "it-IT", "ru-RU", "pt-PT", "pt-BR"
        ]
        let fallbackRequest = makeRequest(langs: fallbackLangs, autoDetect: false)
        do {
          try requestHandler.perform([fallbackRequest])
        } catch {
          NSLog("Failed to perform OCR fallback: \(error.localizedDescription)")
        }
      }
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(rawValue: Constants.Notification.capture),
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name(rawValue: Constants.Notification.ocr),
      object: nil
    )
  }

  private func createFloatWindow(rect: NSRect, image: CGImage, spaceMode: SpaceMode) {
    let floatWindow = FloatWindow(contentRect: rect, image: image, spaceMode: spaceMode)
    floatWindow.floatDelegate = self
    windowControllers.append(floatWindow)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func startCapture() {
    ScreenshotManager.shared.startCapture(spaceMode: .all)
  }

  func windowDidResize(_ notification: Notification) {
    windowControllers.filter { $0.isKeyWindow }.first?.windowDidResize(notification)
  }
}

extension ViewController: FloatDelegate {
  func close(floatWindow: FloatWindow) {
    if !isCancelled {
      if windowControllers.filter({ $0 === floatWindow }).first != nil {
        floatWindow.fadeWindow(isIn: false) {
          guard let index = self.windowControllers.firstIndex(where: { $0 === floatWindow }) else { return }
          self.windowControllers.remove(at: index)
          self.windowControllers.last?.makeKey()
          }
        }
      }
    isCancelled = false

    if windowControllers.count == 0 {
      oldApp?.activate(options: .activateIgnoringOtherApps)
    }
  }

  func save(floatWindow: FloatWindow, image: CGImage) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"

    let savePanel = NSSavePanel()
    savePanel.canCreateDirectories = true
    savePanel.showsTagField = false
    savePanel.nameFieldStringValue = "screenshot-\(formatter.string(from: Date()))"
    savePanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.modalPanelWindow)))
    let saveOptions = IKSaveOptions(imageProperties: [:], imageUTType: kUTTypePNG as String?)
    saveOptions?.addAccessoryView(to: savePanel)

    let result = savePanel.runModal()
    if result == .OK {
      if let url = savePanel.url as CFURL?, let type = saveOptions?.imageUTType as CFString? {
        guard let destination = CGImageDestinationCreateWithURL(url, type, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, saveOptions!.imageProperties! as CFDictionary)
        CGImageDestinationFinalize(destination)
      }
    }
  }
}
