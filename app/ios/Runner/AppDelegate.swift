import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var voicePlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      registerVoicePlaybackChannel(controller: controller)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func registerVoicePlaybackChannel(controller: FlutterViewController) {
    FlutterMethodChannel(
      name: "app/voice_playback",
      binaryMessenger: controller.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }
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
          try self.playVoice(source: source)
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
        self.stopVoice()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func playVoice(source: String) throws {
    stopVoice()
    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    try AVAudioSession.sharedInstance().setActive(true)
    let data = try Data(contentsOf: url(for: source))
    let player = try AVAudioPlayer(data: data)
    player.prepareToPlay()
    player.play()
    voicePlayer = player
  }

  private func stopVoice() {
    voicePlayer?.stop()
    voicePlayer = nil
  }

  private func url(for source: String) throws -> URL {
    if source.hasPrefix("http://") || source.hasPrefix("https://") {
      guard let url = URL(string: source) else {
        throw VoicePlaybackError.invalidSource
      }
      return url
    }
    return URL(fileURLWithPath: source)
  }
}

enum VoicePlaybackError: Error {
  case invalidSource
}
