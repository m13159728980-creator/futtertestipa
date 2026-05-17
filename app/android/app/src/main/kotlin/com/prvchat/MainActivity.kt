package com.prvchat

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private var voicePlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/secure_window"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/voice_playback"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val source = call.argument<String>("source")
                    if (source.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        playVoice(source)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("VOICE_PLAYBACK_FAILED", error.message, null)
                    }
                }
                "stop" -> {
                    stopVoice()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playVoice(source: String) {
        stopVoice()
        voicePlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            if (source.startsWith("http://") || source.startsWith("https://")) {
                setDataSource(this@MainActivity, Uri.parse(source))
            } else {
                setDataSource(source)
            }
            setOnCompletionListener { stopVoice() }
            prepare()
            start()
        }
    }

    private fun stopVoice() {
        voicePlayer?.setOnCompletionListener(null)
        voicePlayer?.stop()
        voicePlayer?.release()
        voicePlayer = null
    }

    override fun onDestroy() {
        stopVoice()
        super.onDestroy()
    }
}
