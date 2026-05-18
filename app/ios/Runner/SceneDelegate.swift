import Flutter
import ObjectiveC
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      registerVoicePlaybackChannel(controller: controller)
      registerMediaOpenChannel(controller: controller)
      registerIosUiChannel(controller: controller)
    }
  }

  private func registerIosUiChannel(controller: FlutterViewController) {
    FlutterMethodChannel(
      name: "app/ios_ui",
      binaryMessenger: controller.binaryMessenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "majorVersion":
        if let major = Int(UIDevice.current.systemVersion.split(separator: ".").first ?? "0") {
          result(major)
        } else {
          result(0)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerVoicePlaybackChannel(controller: FlutterViewController) {
    FlutterMethodChannel(
      name: "app/voice_playback",
      binaryMessenger: controller.binaryMessenger
    ).setMethodCallHandler { call, result in
      switch call.method {
      case "play":
        guard
          let arguments = call.arguments as? [String: Any],
          let source = arguments["source"] as? String,
          !source.isEmpty
        else {
          result(false)
          return
        }
        do {
          try VoicePlaybackController.shared.play(source: source)
          result(true)
        } catch {
          result(
            FlutterError(
              code: "VOICE_PLAYBACK_FAILED",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      case "stop":
        VoicePlaybackController.shared.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerMediaOpenChannel(controller: FlutterViewController) {
    FlutterMethodChannel(
      name: "app/media_open",
      binaryMessenger: controller.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "open":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String,
          !path.isEmpty
        else {
          result(false)
          return
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
          result(false)
          return
        }
        self?.window?.rootViewController?.presentDocument(at: url)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class DocumentPreviewDelegate: NSObject, UIDocumentInteractionControllerDelegate {
  weak var viewController: UIViewController?

  init(viewController: UIViewController) {
    self.viewController = viewController
  }

  func documentInteractionControllerViewControllerForPreview(
    _ controller: UIDocumentInteractionController
  ) -> UIViewController {
    viewController ?? UIViewController()
  }
}

private var documentPreviewDelegateKey: UInt8 = 0
private var documentControllerKey: UInt8 = 0

private extension UIViewController {
  func presentDocument(at url: URL) {
    let delegate = DocumentPreviewDelegate(viewController: self)
    let controller = UIDocumentInteractionController(url: url)
    controller.delegate = delegate
    objc_setAssociatedObject(
      self,
      &documentPreviewDelegateKey,
      delegate,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    objc_setAssociatedObject(
      self,
      &documentControllerKey,
      controller,
      .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
    if !controller.presentPreview(animated: true) {
      controller.presentOptionsMenu(from: view.bounds, in: view, animated: true)
    }
  }
}
