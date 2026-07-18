package com.topluyo

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.view.KeyEvent
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var audioManager: AudioManager
    private val CHANNEL = "com.topluyo/cookie_manager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "flushCookies") {
                CookieManager.getInstance().flush()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Set the default volume stream
        volumeControlStream = AudioManager.STREAM_MUSIC
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Manually intercept volume keys to ensure they always control STREAM_MUSIC
        // This is necessary because older Android versions (like 8.1) might override 
        // volumeControlStream when WebRTC sets MODE_IN_COMMUNICATION.
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
                return true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
