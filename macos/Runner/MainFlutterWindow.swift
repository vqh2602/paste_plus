import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  private var standardCollectionBehavior: NSWindow.CollectionBehavior = []
  private var standardBackgroundColor: NSColor = .windowBackgroundColor
  private var standardIsOpaque = true
  private var standardHasShadow = true
  private var standardIsMovable = true

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
      guard call.method == "setQuickPanelMode", let self else {
        result(FlutterMethodNotImplemented)
        return
      }
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
    }

    super.awakeFromNib()
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
