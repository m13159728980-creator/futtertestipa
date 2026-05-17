import Flutter
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
}
