import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var dropPlayer: AVAudioPlayer?
  private var successPlayer: AVAudioPlayer?
  private var failPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureAudioChannel(pluginRegistry: engineBridge.pluginRegistry)
  }

  private func configureAudioChannel(pluginRegistry: FlutterPluginRegistry) {
    guard let registrar = pluginRegistry.registrar(forPlugin: "SwipeStackAudio") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "swipe_stack/audio",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "playDrop":
        self.playSound(asset: "assets/audio/drop.wav", player: &self.dropPlayer, volume: 0.56)
        result(nil)
      case "playStackSuccess":
        self.playSound(
          asset: "assets/audio/stack_success.wav",
          player: &self.successPlayer,
          volume: 0.72
        )
        result(nil)
      case "playFail":
        self.playSound(asset: "assets/audio/fail.wav", player: &self.failPlayer, volume: 0.68)
        result(nil)
      case "disposeAudio":
        self.disposeAudio()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
    }
  }

  private func playSound(
    asset: String,
    player: inout AVAudioPlayer?,
    volume: Float
  ) {
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      player = try AVAudioPlayer(contentsOf: url)
      player?.volume = volume
      player?.prepareToPlay()
      player?.play()
    } catch {
    }
  }

  private func disposeAudio() {
    dropPlayer?.stop()
    successPlayer?.stop()
    failPlayer?.stop()
    dropPlayer = nil
    successPlayer = nil
    failPlayer = nil
  }

  private func assetURL(for asset: String) -> URL? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    let appFrameworkURL = Bundle.main.bundleURL
      .appendingPathComponent("Frameworks/App.framework/flutter_assets", isDirectory: true)
      .appendingPathComponent(assetKey)

    if FileManager.default.fileExists(atPath: appFrameworkURL.path) {
      return appFrameworkURL
    }

    return Bundle.main.resourceURL?.appendingPathComponent(assetKey)
  }
}
