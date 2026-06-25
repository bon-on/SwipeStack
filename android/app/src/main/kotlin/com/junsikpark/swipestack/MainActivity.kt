package com.junsikpark.swipestack

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var dropPlayer: MediaPlayer? = null
    private var successPlayer: MediaPlayer? = null
    private var failPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "swipe_stack/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playDrop" -> {
                    playSound("assets/audio/drop.wav") { dropPlayer = it }
                    result.success(null)
                }
                "playStackSuccess" -> {
                    playSound("assets/audio/stack_success.wav") { successPlayer = it }
                    result.success(null)
                }
                "playFail" -> {
                    playSound("assets/audio/fail.wav") { failPlayer = it }
                    result.success(null)
                }
                "disposeAudio" -> {
                    disposeAudio()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        disposeAudio()
        super.onDestroy()
    }

    private fun playSound(asset: String, assignPlayer: (MediaPlayer?) -> Unit) {
        runCatching {
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
            val descriptor = assets.openFd("flutter_assets/$key")
            val player = MediaPlayer()
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build(),
            )
            player.setDataSource(
                descriptor.fileDescriptor,
                descriptor.startOffset,
                descriptor.length,
            )
            descriptor.close()
            player.prepare()
            player.setOnCompletionListener {
                it.release()
                assignPlayer(null)
            }
            assignPlayer(player)
            player.start()
        }.onFailure {
            assignPlayer(null)
        }
    }

    private fun disposeAudio() {
        dropPlayer?.release()
        successPlayer?.release()
        failPlayer?.release()
        dropPlayer = null
        successPlayer = null
        failPlayer = null
    }
}
