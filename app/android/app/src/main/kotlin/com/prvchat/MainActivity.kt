package com.prvchat

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.webkit.MimeTypeMap
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import java.io.File

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/media_open"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(openMediaFile(path))
                    } catch (error: Exception) {
                        result.error("MEDIA_OPEN_FAILED", error.message, null)
                    }
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

    private fun openMediaFile(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) {
            return false
        }

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )
        val mimeType = mimeTypeFor(file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return try {
            startActivity(Intent.createChooser(intent, "Open with"))
            true
        } catch (error: ActivityNotFoundException) {
            false
        }
    }

    private fun mimeTypeFor(file: File): String {
        val extension = file.extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

    override fun onDestroy() {
        stopVoice()
        super.onDestroy()
    }
}
