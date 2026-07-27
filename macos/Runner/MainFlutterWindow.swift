import Cocoa
import FlutterMacOS
import ServiceManagement
import Accessibility
import Vision

class MainFlutterWindow: NSWindow {
  private var standardCollectionBehavior: NSWindow.CollectionBehavior = []
  private var standardBackgroundColor: NSColor = .windowBackgroundColor
  private var standardIsOpaque = true
  private var standardHasShadow = true
  private var standardIsMovable = true
  private var previousApplication: NSRunningApplication?
  private var lastActiveApplication: NSRunningApplication?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = .windowBackgroundColor
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    standardCollectionBehavior = self.collectionBehavior
    standardBackgroundColor = self.backgroundColor
    standardIsOpaque = self.isOpaque
    standardHasShadow = self.hasShadow
    standardIsMovable = self.isMovable
    Self.migrateLegacySandboxPreferences()

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handleAppActivation(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )

    RegisterGeneratedPlugins(registry: flutterViewController)

    let clipboardChannel = FlutterMethodChannel(
      name: "clipflow/clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    clipboardChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "readClipboard":
        let pasteboard = NSPasteboard.general
        var response: [String: Any] = [:]
        if let text = pasteboard.string(forType: .string) {
          response["text"] = text
        }
        if let pngData = pasteboard.data(forType: .png) ?? Self.pngDataFromTiff(pasteboard) {
          response["imageBase64"] = pngData.base64EncodedString()
        }
        if let app = NSWorkspace.shared.frontmostApplication {
          response["sourceAppName"] = app.localizedName
          response["sourceAppIdentifier"] = app.bundleIdentifier
        }
        result(response)
      case "writeText":
        guard
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: "Missing text", details: nil))
          return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        result(nil)
      case "writeImage":
        guard
          let arguments = call.arguments as? [String: Any],
          let imageBase64 = arguments["imageBase64"] as? String,
          let imageData = Data(base64Encoded: imageBase64)
        else {
          result(FlutterError(code: "invalid_arguments", message: "Missing image", details: nil))
          return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: .png)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let ocrChannel = FlutterMethodChannel(
      name: "clipflow/ocr",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    ocrChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "performOcr":
        guard
          let arguments = call.arguments as? [String: Any],
          let imagePath = arguments["imagePath"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: "Missing imagePath", details: nil))
          return
        }

        guard let nsImage = NSImage(contentsOfFile: imagePath),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
          result(FlutterError(code: "invalid_image", message: "Could not load image file", details: nil))
          return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
          if let error = error {
            DispatchQueue.main.async {
              result(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
            }
            return
          }
          guard let observations = request.results as? [VNRecognizedTextObservation] else {
            DispatchQueue.main.async {
              result("")
            }
            return
          }
          let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
          }
          let fullText = recognizedStrings.joined(separator: "\n")
          DispatchQueue.main.async {
            result(fullText)
          }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
          do {
            try requestHandler.perform([request])
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "ocr_error", message: error.localizedDescription, details: nil))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let startupChannel = FlutterMethodChannel(
      name: "launch_at_startup",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    startupChannel.setMethodCallHandler { call, result in
      guard #available(macOS 13.0, *) else {
        result(
          FlutterError(
            code: "unsupported_macos_version",
            message: "Launch at login requires macOS 13 or later.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "launchAtStartupIsEnabled":
        result(SMAppService.mainApp.status == .enabled)
      case "launchAtStartupStatus":
        result(Self.launchAtStartupStatus())
      case "launchAtStartupSetEnabled":
        guard
          let arguments = call.arguments as? [String: Any],
          let shouldEnable = arguments["setEnabledValue"] as? Bool
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Missing setEnabledValue.",
              details: nil
            )
          )
          return
        }

        do {
          let service = SMAppService.mainApp
          if shouldEnable {
            if service.status != .enabled && service.status != .requiresApproval {
              try service.register()
            }
          } else if service.status != .notRegistered {
            try service.unregister()
          }
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "launch_at_login_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let windowChannel = FlutterMethodChannel(
      name: "clipflow/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }

      switch call.method {
      case "setQuickPanelMode":
        guard let enabled = call.arguments as? Bool else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Expected a boolean quick-panel state.",
              details: nil
            )
          )
          return
        }

        if enabled {
          if
            let frontmostApplication = NSWorkspace.shared.frontmostApplication,
            frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier
          {
            self.previousApplication = frontmostApplication
            self.lastActiveApplication = frontmostApplication
          }
          flutterViewController.backgroundColor = .clear
          self.isOpaque = false
          self.backgroundColor = .clear
          self.hasShadow = false
          self.isMovable = false
          self.level = .popUpMenu
          self.hidesOnDeactivate = true
          self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .stationary,
            .ignoresCycle,
          ]
        } else {
          flutterViewController.backgroundColor = .windowBackgroundColor
          self.isOpaque = self.standardIsOpaque
          self.backgroundColor = self.standardBackgroundColor
          self.hasShadow = self.standardHasShadow
          self.isMovable = self.standardIsMovable
          self.level = .normal
          self.hidesOnDeactivate = false
          self.collectionBehavior = self.standardCollectionBehavior
        }
        result(nil)
      case "setShowInDock":
        guard let show = call.arguments as? Bool else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Expected a boolean showInDock state.",
              details: nil
            )
          )
          return
        }
        NSApp.setActivationPolicy(show ? .regular : .accessory)
        if show {
          NSApp.activate(ignoringOtherApps: true)
        }
        result(nil)
      case "checkAccessibilityPermission":
        result(AXIsProcessTrusted())
      case "requestAccessibilityPermission":
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        result(AXIsProcessTrustedWithOptions(options))
      case "getRunningApplications":
        self.getRunningApplications(result: result)
      case "pickApplicationFile":
        self.pickApplicationFile(result: result)
      case "pasteToPreviousApplication":
        self.pasteToPreviousApplication(result: result)
      case "openUrl":
        guard
          let arguments = call.arguments as? [String: Any],
          let urlString = arguments["url"] as? String,
          let url = URL(string: urlString)
        else {
          result(FlutterError(code: "invalid_arguments", message: "Missing url", details: nil))
          return
        }
        NSWorkspace.shared.open(url)
        result(nil)
      case "getAppBundlePath":
        result(Bundle.main.bundlePath)
      case "restartApp":
        let bundleUrl = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleUrl, configuration: configuration) { _, _ in
          DispatchQueue.main.async {
            NSApp.terminate(nil)
          }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  @objc private func handleAppActivation(_ notification: Notification) {
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
      return
    }
    if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
      self.lastActiveApplication = app
      self.previousApplication = app
    }
  }

  private static func pngDataFromTiff(_ pasteboard: NSPasteboard) -> Data? {
    guard
      let tiffData = pasteboard.data(forType: .tiff),
      let representation = NSBitmapImageRep(data: tiffData)
    else {
      return nil
    }
    return representation.representation(using: .png, properties: [:])
  }

  private static func migrateLegacySandboxPreferences() {
    let settingsKey = "flutter.clipflow.settings.v1"
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: settingsKey) == nil else { return }

    let legacyPreferencesURL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library")
      .appendingPathComponent("Containers")
      .appendingPathComponent("com.clipflow.clipflow")
      .appendingPathComponent("Data")
      .appendingPathComponent("Library")
      .appendingPathComponent("Preferences")
      .appendingPathComponent("com.clipflow.clipflow.plist")
    guard
      let preferences = NSDictionary(contentsOf: legacyPreferencesURL),
      let settings = preferences[settingsKey]
    else {
      return
    }
    defaults.set(settings, forKey: settingsKey)
  }

  private func pasteToPreviousApplication(result: @escaping FlutterResult) {
    guard AXIsProcessTrusted() else {
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
      AXIsProcessTrustedWithOptions(options)
      result(false)
      return
    }

    let myPid = ProcessInfo.processInfo.processIdentifier
    var targetApplication: NSRunningApplication? = lastActiveApplication ?? previousApplication

    if targetApplication == nil || targetApplication?.isTerminated == true || targetApplication?.processIdentifier == myPid {
      targetApplication = NSWorkspace.shared.runningApplications.first { app in
        app.activationPolicy == .regular &&
        app.processIdentifier != myPid &&
        !app.isTerminated
      }
    }

    guard let appToActivate = targetApplication, !appToActivate.isTerminated else {
      result(false)
      return
    }

    appToActivate.activate(options: [.activateIgnoringOtherApps])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      let source = CGEventSource(stateID: .hidSystemState)
      guard
        let keyDown = CGEvent(
          keyboardEventSource: source,
          virtualKey: 9,
          keyDown: true
        ),
        let keyUp = CGEvent(
          keyboardEventSource: source,
          virtualKey: 9,
          keyDown: false
        )
      else {
        result(false)
        return
      }
      keyDown.flags = .maskCommand
      keyUp.flags = .maskCommand
      keyDown.post(tap: .cghidEventTap)
      keyUp.post(tap: .cghidEventTap)
      result(true)
    }
  }

  private func getRunningApplications(result: @escaping FlutterResult) {
    let runningApps = NSWorkspace.shared.runningApplications.filter { app in
      app.activationPolicy == .regular &&
      app.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }
    var seenNames = Set<String>()
    let appsData: [[String: String]] = runningApps.compactMap { app in
      guard let name = app.localizedName, !name.isEmpty else { return nil }
      if seenNames.contains(name) { return nil }
      seenNames.insert(name)
      return [
        "name": name,
        "bundleId": app.bundleIdentifier ?? ""
      ]
    }
    result(appsData)
  }

  private func pickApplicationFile(result: @escaping FlutterResult) {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.allowedFileTypes = ["app"]
    openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
    openPanel.begin { response in
      if response == .OK, let url = openPanel.url {
        let bundle = Bundle(url: url)
        let appName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
          ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
          ?? url.deletingPathExtension().lastPathComponent
        let bundleId = bundle?.bundleIdentifier ?? ""
        result([
          "name": appName,
          "bundleId": bundleId,
          "path": url.path
        ])
      } else {
        result(nil)
      }
    }
  }

  @available(macOS 13.0, *)
  private static func launchAtStartupStatus() -> String {
    switch SMAppService.mainApp.status {
    case .notRegistered:
      return "notRegistered"
    case .enabled:
      return "enabled"
    case .requiresApproval:
      return "requiresApproval"
    case .notFound:
      return "notFound"
    @unknown default:
      return "unknown"
    }
  }
}
