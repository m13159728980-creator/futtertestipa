import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

final class VoicePlaybackController {
  static let shared = VoicePlaybackController()

  private var voicePlayer: AVAudioPlayer?

  private init() {}

  func play(source: String) throws {
    stop()
    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    try AVAudioSession.sharedInstance().setActive(true)
    let data = try Data(contentsOf: url(for: source))
    let player = try AVAudioPlayer(data: data)
    player.prepareToPlay()
    player.play()
    voicePlayer = player
  }

  func stop() {
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
