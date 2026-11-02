import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var dropPlayer: AVAudioPlayer?
  private var successPlayer: AVAudioPlayer?
  private var failPlayer: AVAudioPlayer?
  private var effectPlayers: [AVAudioPlayer] = []
  private var musicPlayer: AVAudioPlayer?
  // True while the music loop should be audible (startLoop until stopLoop),
  // so it can resume after a call or Siri interrupted the audio session.
  private var musicWanted = false
  private var interruptionObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      self?.handleInterruption(notification)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleInterruption(_ notification: Notification) {
    guard
      let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw)
    else {
      return
    }
    if type == .ended, musicWanted, let player = musicPlayer, !player.isPlaying {
      configureAudioSession()
      player.play()
    }
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
      case "play":
        let args = call.arguments as? [String: Any]
        if let asset = args?["asset"] as? String {
          self.playEffect(asset: asset, volume: Float(args?["volume"] as? Double ?? 1.0))
        }
        result(nil)
      case "startLoop":
        let args = call.arguments as? [String: Any]
        if let asset = args?["asset"] as? String {
          self.startLoop(asset: asset, volume: Float(args?["volume"] as? Double ?? 1.0))
        }
        result(nil)
      case "stopLoop":
        self.stopLoop()
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
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
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

  // Generic one-shot effects may overlap, so finished players are pruned and
  // the rest are kept alive until they stop.
  private func playEffect(asset: String, volume: Float) {
    configureAudioSession()
    effectPlayers.removeAll { !$0.isPlaying }
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = volume
      player.prepareToPlay()
      player.play()
      effectPlayers.append(player)
    } catch {
    }
  }

  private func startLoop(asset: String, volume: Float) {
    stopLoop()
    configureAudioSession()
    guard let url = assetURL(for: asset) else {
      return
    }

    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      player.volume = volume
      player.prepareToPlay()
      player.play()
      musicPlayer = player
      musicWanted = true
    } catch {
    }
  }

  private func stopLoop() {
    musicWanted = false
    musicPlayer?.stop()
    musicPlayer = nil
  }

  private func disposeAudio() {
    stopLoop()
    effectPlayers.forEach { $0.stop() }
    effectPlayers.removeAll()
    dropPlayer?.stop()
    successPlayer?.stop()
    failPlayer?.stop()
    dropPlayer = nil
    successPlayer = nil
    failPlayer = nil
  }

  private func assetURL(for asset: String) -> URL? {
    let assetKey = FlutterDartProject.lookupKey(forAsset: asset)
    // The lookup key is already relative to the app bundle
    // (Frameworks/App.framework/flutter_assets/...).
    let url = Bundle.main.bundleURL.appendingPathComponent(assetKey)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
}
